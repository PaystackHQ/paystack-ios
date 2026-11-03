//
//  PSTCKAPIClient.m
//  PaystackExample
//

#import "TargetConditionals.h"
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#import <UIKit/UIViewController.h>
#import <sys/utsname.h>
#endif

#import "PSTCKAPIClient.h"
#import "PSTCKFormEncoder.h"
#import "PSTCKCard.h"
#import "PSTCKRSA.h"
#import "PSTCKCardValidator.h"
#import "PSTCKToken.h"
#import "PSTCKTransaction.h"
#import "PSTCKValidationParams.h"
#import "PaystackError.h"
#import "PSTCKAPIResponseDecodable.h"
#import "PSTCKAuthViewController.h"
#import "PSTCKAPIPostRequest.h"
#import "PSTCKAPIClient+Private.h"
#import <Paystack/Paystack-Swift.h>

#ifdef PSTCK_STATIC_LIBRARY_BUILD
#import "PSTCKCategoryLoader.h"
#endif

#define FAUXPAS_IGNORED_IN_METHOD(...)

static NSString *const apiURLBase = @"standard.paystack.co";
static NSString *const chargeEndpoint = @"charge/mobile_charge";
static NSString *const avsEndpoint = @"charge/avs";
static NSString *const validateEndpoint = @"charge/validate";
static NSString *const requeryEndpoint = @"charge/requery/";
static const NSInteger PSTCKMaxRequeryAttempts = 12;
static const NSTimeInterval PSTCKRequeryIntervalSeconds = 5;
static NSString *PSTCKDefaultPublicKey;
static Boolean PROCESSING = false;

@implementation Paystack

+ (id)alloc {
    NSCAssert(NO, @"'Paystack' is a static class and cannot be instantiated.");
    return nil;
}

+ (void)setDefaultPublicKey:(NSString *)publicKey {
    PSTCKDefaultPublicKey = publicKey;
}

+ (NSString *)defaultPublicKey {
    return PSTCKDefaultPublicKey;
}

@end

@interface PSTCKServerTransaction : NSObject

@property (nonatomic, readwrite, nullable) NSString *id;
@property (nonatomic, readwrite, nullable) NSString *reference;
/// The access code for this charge, from PSTCKTransactionParams.access_code (merchant backend's
/// transaction/initialize). Stored once per charge and used for every follow-up call.
@property (nonatomic, readwrite, nullable) NSString *accessCode;

@end
@implementation PSTCKServerTransaction
- (instancetype)init {
    self = [super init];
    if (self) {
        _id = nil;
        _reference = nil;
        _accessCode = nil;
    }
    return self;
}
@end

@interface PSTCKAPIClient ()

@property(nonatomic, strong) UIViewController *viewController;
@property(nonatomic, strong) PSTCKServerTransaction *serverTransaction;
@property(nonatomic, retain) PSTCKCardParams *card;
@property(nonatomic, retain) PSTCKTransactionParams *transaction;
@property(nonatomic, copy) PSTCKErrorCompletionBlock errorCompletion;
@property(nonatomic, copy) PSTCKTransactionCompletionBlock beforeValidateCompletion;
@property(nonatomic, copy) PSTCKNotifyCompletionBlock showingDialogCompletion;
@property(nonatomic, copy) PSTCKNotifyCompletionBlock dialogDismissedCompletion;
@property(nonatomic, copy) PSTCKTransactionCompletionBlock successCompletion;

@property int INVALID_DATA_SENT_RETRIES;
@property (nonatomic) NSInteger requeryAttempts;
@property (nonatomic) NSTimeInterval requeryInterval;
@end

@implementation PSTCKAPIClient

#ifdef PSTCK_STATIC_LIBRARY_BUILD
+ (void)initialize {
    [PSTCKCategoryLoader loadCategories];
}
#endif

+ (instancetype)sharedClient {
    static id sharedClient;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ sharedClient = [[self alloc] init]; });
    return sharedClient;
}

- (instancetype)init {
    return [self initWithPublicKey:[Paystack defaultPublicKey]];
}

- (instancetype)initWithPublicKey:(NSString *)publicKey {
    self = [super init];
    if (self) {
        [self.class validateKey:publicKey];
        _apiURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@", apiURLBase]];
        _publicKey = [publicKey copy];
        _operationQueue = [NSOperationQueue mainQueue];
        _requeryInterval = PSTCKRequeryIntervalSeconds;
        [self useSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    }
    return self;
}

- (void)useSessionConfiguration:(NSURLSessionConfiguration *)configuration {
    // Static headers only. Authorization and Paystack-Version are set on each request in
    // -authorizedRequestWithURL:method: (Apple does not guarantee Authorization is sent when
    // set through HTTPAdditionalHeaders, and a per-request header always uses the current key).
    configuration.HTTPAdditionalHeaders = @{
        @"X-Paystack-User-Agent": [self.class paystackUserAgentDetails],
        @"X-Paystack-Build": PSTCKSDKBuild,
    };
    _urlSession = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:_operationQueue];
}

- (NSMutableURLRequest *)authorizedRequestWithURL:(NSURL *)url method:(NSString *)httpMethod {
    if (self.publicKey.length == 0) {
        return nil;
    }
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    request.HTTPMethod = httpMethod;
    [request setValue:[@"Bearer " stringByAppendingString:self.publicKey] forHTTPHeaderField:@"Authorization"];
    [request setValue:[self.class paystackVersionHeaderValue] forHTTPHeaderField:@"Paystack-Version"];
    return request;
}

+ (NSString *)paystackVersionHeaderValue {
    // The SDK version from the project config: the framework's CFBundleShortVersionString, which
    // Info.plist takes from $(MARKETING_VERSION) and CocoaPods from the podspec's s.version.
    // Static-library builds have no bundle of their own, so fall back to PSTCKSDKVersion.
    // Keep in sync with pstckPaystackVersionHeaderValue() in PSTCKAPIClientExtension.swift.
    NSBundle *bundle = [NSBundle bundleForClass:[PSTCKAPIClient class]];
    if (bundle != [NSBundle mainBundle]) {
        NSString *version = bundle.infoDictionary[@"CFBundleShortVersionString"];
        if (version.length > 0) {
            return version;
        }
    }
    return PSTCKSDKVersion;
}



- (void)setOperationQueue:(NSOperationQueue *)operationQueue {
    NSCAssert(operationQueue, @"Operation queue cannot be nil.");
    _operationQueue = operationQueue;
}

#pragma mark - private helpers

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-variable"
+ (void)validateKey:(NSString *)publicKey {
    NSCAssert(publicKey != nil && ![publicKey isEqualToString:@""],
              @"You must use a valid public key to charge a card.");
    BOOL secretKey = [publicKey hasPrefix:@"sk_"];
    NSCAssert(!secretKey,
              @"You are using a secret key to charge the card, instead of the public one.");
#ifndef DEBUG
    if ([publicKey.lowercaseString hasPrefix:@"pk_test"]) {
        FAUXPAS_IGNORED_IN_METHOD(NSLogUsed);
        NSLog(@"⚠️ Warning! You're building your app in a non-debug configuration, but appear to be using your Paystack test key. Make sure not to submit to "
              @"the App Store with your test keys!⚠️");
    }
#endif
}
#pragma clang diagnostic pop

#pragma mark Utility methods -

+ (NSString *)device_id {
    return [@"iossdk_" stringByAppendingString:[[[UIDevice currentDevice] identifierForVendor] UUIDString]];
}

+ (NSString *)paystackUserAgentDetails {
    NSMutableDictionary *details = [@{
        @"lang": @"objective-c",
        @"bindings_version": PSTCKSDKVersion,
    } mutableCopy];
#if TARGET_OS_IPHONE
    NSString *version = [UIDevice currentDevice].systemVersion;
    if (version) {
        details[@"os_version"] = version;
    }
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *deviceType = @(systemInfo.machine);
    if (deviceType) {
        details[@"type"] = deviceType;
    }
    NSString *model = [UIDevice currentDevice].localizedModel;
    if (model) {
        details[@"model"] = model;
    }
    if ([[UIDevice currentDevice] respondsToSelector:@selector(identifierForVendor)]) {
        NSString *vendorIdentifier = [[[UIDevice currentDevice] performSelector:@selector(identifierForVendor)] performSelector:@selector(UUIDString)];
        if (vendorIdentifier) {
            details[@"vendor_identifier"] = vendorIdentifier;
        }
    }
#endif
    return [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:[details copy] options:0 error:NULL] encoding:NSUTF8StringEncoding];
}

@end

typedef NS_ENUM(NSInteger, PSTCKChargeStage) {
    PSTCKChargeStageNoHandle,
    PSTCKChargeStagePlusHandle,
    PSTCKChargeStageValidateToken,
    PSTCKChargeStageRequery,
    PSTCKChargeStageAVS,
};


#pragma mark - Credit Cards
@implementation PSTCKAPIClient (CreditCards)

- (void)chargeCard:(nonnull PSTCKCardParams *)card
    forTransaction:(nonnull PSTCKTransactionParams *)transaction
  onViewController:(nonnull UIViewController *)viewController
   didEndWithError:(nonnull PSTCKErrorCompletionBlock)errorCompletion
didTransactionSuccess:(nonnull PSTCKTransactionCompletionBlock)successCompletion {
    [self beginChargeWithCard:card
               forTransaction:transaction
             onViewController:viewController
              didEndWithError:errorCompletion
         didRequestValidation:nil
            willPresentDialog:nil
              dismissedDialog:nil
        didTransactionSuccess:successCompletion];
}

- (void)setProcessingStatus:(Boolean)status {
    PROCESSING=status;
}

- (void)chargeCard:(nonnull PSTCKCardParams *)card
    forTransaction:(nonnull PSTCKTransactionParams *)transaction
  onViewController:(nonnull UIViewController *)viewController
   didEndWithError:(nonnull PSTCKErrorCompletionBlock)errorCompletion
didRequestValidation:(nonnull PSTCKTransactionCompletionBlock)beforeValidateCompletion
 willPresentDialog:(nonnull PSTCKNotifyCompletionBlock)showingDialogCompletion
   dismissedDialog:(nonnull PSTCKNotifyCompletionBlock)dialogDismissedCompletion
didTransactionSuccess:(nonnull PSTCKTransactionCompletionBlock)successCompletion {
    [self beginChargeWithCard:card
               forTransaction:transaction
             onViewController:viewController
              didEndWithError:errorCompletion
         didRequestValidation:beforeValidateCompletion
            willPresentDialog:showingDialogCompletion
              dismissedDialog:dialogDismissedCompletion
        didTransactionSuccess:successCompletion];
}

- (void)chargeCard:(nonnull PSTCKCardParams *)card
    forTransaction:(nonnull PSTCKTransactionParams *)transaction
  onViewController:(nonnull UIViewController *)viewController
   didEndWithError:(nonnull PSTCKErrorCompletionBlock)errorCompletion
 willPresentDialog:(nonnull PSTCKNotifyCompletionBlock)showingDialogCompletion
   dismissedDialog:(nonnull PSTCKNotifyCompletionBlock)dialogDismissedCompletion
didTransactionSuccess:(nonnull PSTCKTransactionCompletionBlock)successCompletion {
    [self beginChargeWithCard:card
               forTransaction:transaction
             onViewController:viewController
              didEndWithError:errorCompletion
         didRequestValidation:nil
            willPresentDialog:showingDialogCompletion
              dismissedDialog:dialogDismissedCompletion
        didTransactionSuccess:successCompletion];
}

- (void)chargeCard:(nonnull PSTCKCardParams *)card
    forTransaction:(nonnull PSTCKTransactionParams *)transaction
  onViewController:(nonnull UIViewController *)viewController
   didEndWithError:(nonnull PSTCKErrorCompletionBlock)errorCompletion
didRequestValidation:(nonnull PSTCKTransactionCompletionBlock)beforeValidateCompletion
didTransactionSuccess:(nonnull PSTCKTransactionCompletionBlock)successCompletion {
    [self beginChargeWithCard:card
               forTransaction:transaction
             onViewController:viewController
              didEndWithError:errorCompletion
         didRequestValidation:beforeValidateCompletion
            willPresentDialog:nil
              dismissedDialog:nil
        didTransactionSuccess:successCompletion];
}

/// Single entry point for every chargeCard: overload. Rejects a second charge while one is in
/// flight *before* touching any state, so it can't overwrite the running charge's callbacks or
/// access code. Optional callbacks not passed by the overload are reset to nil, so they never
/// leak in from a previous charge on the shared client.
- (void)beginChargeWithCard:(nonnull PSTCKCardParams *)card
             forTransaction:(nonnull PSTCKTransactionParams *)transaction
           onViewController:(nonnull UIViewController *)viewController
            didEndWithError:(nonnull PSTCKErrorCompletionBlock)errorCompletion
       didRequestValidation:(nullable PSTCKTransactionCompletionBlock)beforeValidateCompletion
          willPresentDialog:(nullable PSTCKNotifyCompletionBlock)showingDialogCompletion
            dismissedDialog:(nullable PSTCKNotifyCompletionBlock)dialogDismissedCompletion
      didTransactionSuccess:(nonnull PSTCKTransactionCompletionBlock)successCompletion {
    NSCAssert(card != nil, @"'card' is required for a charge");
    NSCAssert(errorCompletion != nil, @"'errorCompletion' is required to handle any errors encountered while charging");
    NSCAssert(viewController != nil, @"'viewController' is required to show any alerts that may be needed");
    NSCAssert(transaction != nil, @"'transaction' is required so we may know who to charge");
    NSCAssert(successCompletion != nil, @"'successCompletion' is required so you can continue the process after charge succeeds. Remember to verify on server before giving value.");

    if(PROCESSING){
        [self didEndWithProcessingError:errorCompletion];
        return;
    }
    PROCESSING = YES;

    self.beforeValidateCompletion = beforeValidateCompletion;
    self.showingDialogCompletion = showingDialogCompletion;
    self.dialogDismissedCompletion = dialogDismissedCompletion;
    [self startWithCard:card forTransaction:transaction onViewController:viewController didEndWithError:errorCompletion didTransactionSuccess:successCompletion];

    self.INVALID_DATA_SENT_RETRIES = 0;
    NSData *data = [PSTCKFormEncoder formEncryptedDataForCard:card
                                               andTransaction:transaction
                                                 usePublicKey:[self publicKey]
                                                 onThisDevice:[self.class device_id]];
    
    [self makeChargeRequest:data atStage:PSTCKChargeStageNoHandle];
}

- (void)startWithCard:(nonnull PSTCKCardParams *)card
       forTransaction:(nonnull PSTCKTransactionParams *)transaction
     onViewController:(nonnull UIViewController *)viewController
      didEndWithError:(nonnull PSTCKErrorCompletionBlock)errorCompletion
didTransactionSuccess:(nonnull PSTCKTransactionCompletionBlock)successCompletion {
    self.card = card;
    self.transaction = transaction;
    self.viewController = viewController;
    self.errorCompletion = errorCompletion;
    self.successCompletion = successCompletion;
    self.serverTransaction = [PSTCKServerTransaction new];
    self.requeryAttempts = 0;

    // Store the access code for the whole charge. It comes from the merchant backend's
    // transaction/initialize call via PSTCKTransactionParams.access_code; every follow-up call in
    // this charge (requery now; AVS and OTP validate later) reads it from serverTransaction.
    // A new serverTransaction per charge means a code is never carried into the next charge.
    if (transaction.access_code.length > 0) {
        self.serverTransaction.accessCode = transaction.access_code;
    }
#ifdef DEBUG
    else {
        FAUXPAS_IGNORED_IN_METHOD(NSLogUsed);
        NSLog(@"⚠️ Paystack: charging without an access_code. Initialize the transaction on your server "
              @"(transaction/initialize) and set PSTCKTransactionParams.access_code. Charges without an "
              @"access code will stop working in a future release.");
    }
#endif
}

/// The identifier used in charge/requery/{identifier}: the access code, or (temporary fallback for
/// app-initialized charges) the server transaction id. Nil when neither is known.
- (nullable NSString *)requeryIdentifier {
    if (self.serverTransaction.accessCode.length > 0) {
        return self.serverTransaction.accessCode;
    }
    if (self.serverTransaction.id.length > 0) {
        return self.serverTransaction.id;
    }
    return nil;
}

- (void) makeChargeRequest:(NSData *)data
                   atStage:(PSTCKChargeStage) stage

{
    NSString *endpoint;
    NSString *httpMethod;
    
    switch (stage){
        case PSTCKChargeStageNoHandle:
        case PSTCKChargeStagePlusHandle:
            endpoint = chargeEndpoint;
            httpMethod = @"POST";
            break;
        case PSTCKChargeStageValidateToken:
            endpoint = validateEndpoint;
            httpMethod = @"POST";
            break;
        case PSTCKChargeStageRequery: {
            NSString *identifier = [self requeryIdentifier];
            if (identifier == nil) {
                // Previously a nil transaction id threw in stringByAppendingString:.
                [self didEndWithErrorMessage:@"Could not check the transaction status because no access code or transaction id is available."];
                return;
            }
            endpoint = [requeryEndpoint stringByAppendingString:identifier];
            httpMethod = @"GET";
            break;
        }
        case PSTCKChargeStageAVS:
            endpoint = avsEndpoint;
            httpMethod = @"POST";
            break;
    }
    
    [PSTCKAPIPostRequest<PSTCKTransaction *>
     startWithAPIClient:self
     endpoint:endpoint
     method:httpMethod
     postData:data
     serializer:[PSTCKTransaction new]
     completion:^(PSTCKTransaction * _Nullable responseObject, NSError * _Nullable error){
        if((responseObject != nil) && ([responseObject trans] != nil)){
            self.serverTransaction.id = [responseObject trans];
        }
        if((responseObject != nil) && ([responseObject reference] != nil)){
            self.serverTransaction.reference = [responseObject reference];
        }
        if(error != nil){
            [self didEndWithError:error];
            return;
        }
        if([[responseObject message].lowercaseString isEqual:@"invalid data sent"] && self.INVALID_DATA_SENT_RETRIES<3){
            self.INVALID_DATA_SENT_RETRIES = self.INVALID_DATA_SENT_RETRIES+1;
            [self makeChargeRequest:data
                            atStage:stage];
            return;
        }
        if([[responseObject message].lowercaseString isEqual:@"access code has expired"] && [[responseObject status] isEqual:@"0"]){
            NSDictionary *userInfo = @{
                NSLocalizedDescriptionKey: PSTCKExpiredAccessCodeErrorMessage,
                PSTCKErrorMessageKey: PSTCKExpiredAccessCodeErrorMessage
            };
            [self didEndWithError:[[NSError alloc] initWithDomain:PaystackDomain code:PSTCKExpiredAccessCodeError userInfo:userInfo]];
            return;
        }
        [self handleResponse:responseObject];
    }];
}

- (void) requestPin{
    [self notifyShowingDialog];
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Enter CARD PIN"
                                                                   message:@"To confirm that you are the owner of this card please enter your card PIN"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* defaultAction = [UIAlertAction
                                    actionWithTitle:@"Continue" style:UIAlertActionStyleDefault
                                    handler:^(UIAlertAction * action) {
        [action isEnabled]; // Just to avoid Unused error
        [self notifyDialogDismissed];
        NSString *provided = ((UITextField *)[alert.textFields objectAtIndex:0]).text;
        NSString *handle = [PSTCKCardValidator sanitizedNumericStringForString:provided];
        if(handle == nil ||
           [handle length]!=4 ||
           ([provided length] != [handle length])){
            [self didEndWithErrorMessage:@"Invalid PIN provided. Expected exactly 4 digits."];
            return;
        }
        NSData *hdata = [PSTCKFormEncoder formEncryptedDataForCard:self.card
                                                    andTransaction:self.transaction
                                                         andHandle:[PSTCKRSA encryptRSA:handle]
                                                      usePublicKey:[self publicKey]
                                                      onThisDevice:[self.class device_id]];
        [self makeChargeRequest:hdata
                        atStage:PSTCKChargeStagePlusHandle];
        
    }];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"****";
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        textField.secureTextEntry = YES;
    }];
    
    [alert addAction:defaultAction];
    [self.viewController presentViewController:alert animated:YES completion:nil];
}

- (void) requestAVS:(NSArray<PSTCKState *>*) states {
    [self notifyShowingDialog];
    [self notifyBeforeValidate];
    PSTCKAddressViewController* avsVC = [[PSTCKAddressViewController alloc] initWithNibName: @"AddressViewController" bundle:[NSBundle bundleForClass:[self class]]];
    avsVC.transaction = self.serverTransaction.id;
    avsVC.didCollectAddress = ^ (NSDictionary<NSString *,id> * _Nonnull address) {
        [self notifyDialogDismissed];
        NSData *data = [PSTCKFormEncoder formEncryptedDataForDict:address
                                                     usePublicKey:[self publicKey]
                                                     onThisDevice:[self.class device_id]];
        [self makeChargeRequest:data
                        atStage:PSTCKChargeStageAVS];
    };
    avsVC.didTapCancelButton = ^{
        [self notifyDialogDismissed];
        [self didEndWithErrorMessage:@"Could not complete charge because billing information is missing"];
    };
    avsVC.states = states;
    [self.viewController presentViewController:avsVC animated:YES completion:nil];
}

- (void) requestAuth:(NSString * _Nonnull) url{
    [self notifyShowingDialog];
    [self notifyBeforeValidate];
    PSTCKAuthViewController* authorizer = [[[PSTCKAuthViewController alloc] init]
                                           initWithURL:[NSURL URLWithString:url]
                                           handler:^{
        [self.viewController dismissViewControllerAnimated:YES completion:nil];
        [self notifyDialogDismissed];
        [self makeChargeRequest:nil
                        atStage:PSTCKChargeStageRequery];
    }];
    UINavigationController *nc = [[UINavigationController alloc] initWithRootViewController:authorizer];
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        nc.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    
    [self.viewController presentViewController:nc animated:YES completion:nil];
}

- (void) requestOtp:(NSString * _Nonnull) otpmessage{
    [self notifyShowingDialog];
    [self notifyBeforeValidate];
    UIAlertController* tkalert = [UIAlertController alertControllerWithTitle:@"Authentication required"
                                                                     message:otpmessage
                                                              preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* tkdefaultAction = [UIAlertAction
                                      actionWithTitle:@"Continue" style:UIAlertActionStyleDefault
                                      handler:^(UIAlertAction * action) {
        [action isEnabled]; // Just to avoid Unused error
        [self notifyDialogDismissed];
        NSString *provided = ((UITextField *)[tkalert.textFields objectAtIndex:0]).text;
        PSTCKValidationParams *validateParams = [PSTCKValidationParams alloc];
        validateParams.trans = self.serverTransaction.id;
        validateParams.token = provided;
        NSData *vdata = [PSTCKFormEncoder formEncodedDataForObject:validateParams
                                                      usePublicKey:[self publicKey]
                                                      onThisDevice:[self.class device_id]];
        [self makeChargeRequest:vdata
                        atStage:PSTCKChargeStageValidateToken];
        
    }];
    
    [tkalert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"_____";
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [tkalert addAction:tkdefaultAction];
    [self.viewController presentViewController:tkalert animated:YES completion:nil];
}

- (void) handleResponse:(PSTCKTransaction * _Nonnull)responseObject{
    if ([responseObject errors] != nil) {
        [self didEndWithErrorMessage: [responseObject message]];
        return;
    }
    if([[responseObject status] isEqual:@"1"] || [[responseObject status] isEqual:@"success"]){
        [self didEndSuccessfully];
        return;
    }
    else if([[responseObject status] isEqual:@"2"] && [[responseObject auth].lowercaseString isEqual:@"avs"]){
        [self fetchStatesWithCountry:responseObject.countrycode completion: ^( NSArray<PSTCKState *> * _Nonnull states, NSError * _Nullable error) {
            if(error != NULL) {
                [self didEndWithError:error];
            }
            else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self requestAVS:states];
                });
            }
        }];
        return;
    }    else if([[responseObject status] isEqual:@"2"] || [[responseObject auth].lowercaseString isEqual:@"pin"]){
        [self requestPin];
        return;
    } else {
        if([self.serverTransaction id] != nil){
            if([[responseObject auth].lowercaseString isEqual:@"3ds"] && [self validUrl:[responseObject otpmessage]]){
                [self requestAuth:[responseObject otpmessage]];
                return;
            } else if([[responseObject status] isEqual:@"3"]
                      || ([[responseObject auth].lowercaseString isEqual:@"otp"] && [responseObject otpmessage] != nil)
                      || ([[responseObject auth].lowercaseString isEqual:@"phone"] && [responseObject otpmessage] != nil)){
                [self requestOtp:([responseObject otpmessage] != nil ? [responseObject otpmessage] : [responseObject message])];
                return;
            }
        }
        // Not final yet: poll charge/requery/{access code} until a terminal status or the cap.
        if([self.class isPendingStatus:[responseObject status]]) {
            [self scheduleRequery];
            return;
        }
    }
    
    if([[responseObject status] isEqual:@"0"] || [[responseObject status] isEqual:@"error"]
       || [[responseObject status] isEqual:@"timeout"] || [[responseObject status].lowercaseString isEqual:@"failed"]){
        [self didEndWithErrorMessage:[responseObject message] ?: @"The transaction failed."];
    } else {
        // this is an invalid status
        [self didEndWithErrorMessage:[@"The response status from Paystack had an unknown status. Status was: " stringByAppendingString:[responseObject status] ?: @"(none)"]];
    }
}

/// "pending" (requery by access code) and the legacy "requery" both mean: ask again later.
+ (BOOL)isPendingStatus:(nullable NSString *)status {
    NSString *lowercased = status.lowercaseString;
    return [lowercased isEqualToString:@"pending"] || [lowercased isEqualToString:@"requery"];
}

/// Polls requery again after requeryInterval, up to PSTCKMaxRequeryAttempts. Terminal statuses
/// (success, failed, error) and request errors end the charge in handleResponse/makeChargeRequest.
- (void)scheduleRequery {
    if (self.requeryAttempts >= PSTCKMaxRequeryAttempts) {
        [self didEndWithErrorMessage:@"The transaction is still pending. Verify its final status on your server using the transaction reference."];
        return;
    }
    self.requeryAttempts += 1;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.requeryInterval * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self.operationQueue addOperationWithBlock:^{
            [self makeChargeRequest:nil
                            atStage:PSTCKChargeStageRequery];
        }];
    });
}

- (Boolean) validUrl:(NSString *) candidate{
    NSURL *candidateURL = [NSURL URLWithString:candidate];
    // WARNING > "test" is an URL according to RFCs, being just a path
    // so you still should check scheme and all other NSURL attributes you need
    if (candidateURL && candidateURL.scheme && candidateURL.host) {
        // candidate is a well-formed url with:
        //  - a scheme (like http://)
        //  - a host (like stackoverflow.com)
        return YES;
    }
    return NO;
}

- (void)didEndWithError:(NSError *)error{
    PROCESSING=NO;
    [self.operationQueue addOperationWithBlock:^{
        self.errorCompletion(error, self.serverTransaction.reference);
    }];
}

- (void)didEndSuccessfully{
    PROCESSING=NO;
    [self.operationQueue addOperationWithBlock:^{
        self.successCompletion(self.serverTransaction.reference);
    }];
}

- (void)notifyShowingDialog{
    if(self.showingDialogCompletion == NULL){
        return;
    }
    [self.operationQueue addOperationWithBlock:^{
        self.showingDialogCompletion();
    }];
}
- (void)notifyDialogDismissed{
    if(self.dialogDismissedCompletion == NULL){
        return;
    }
    [self.operationQueue addOperationWithBlock:^{
        self.dialogDismissedCompletion();
    }];
}
- (void)notifyBeforeValidate{
    if(self.beforeValidateCompletion == NULL){
        return;
    }
    [self.operationQueue addOperationWithBlock:^{
        self.beforeValidateCompletion(self.serverTransaction.reference);
    }];
}


- (void)didEndWithErrorMessage:(NSString *)errorString{
    NSDictionary *userInfo = @{
        NSLocalizedDescriptionKey: errorString,
        PSTCKErrorMessageKey: errorString
    };
    PROCESSING=NO;
    [self didEndWithError:[[NSError alloc] initWithDomain:PaystackDomain code:PSTCKCardErrorProcessingError userInfo:userInfo]];
}

/// Reports a rejected concurrent charge to *that* caller's error block, leaving the in-flight
/// charge's callbacks and state untouched.
- (void)didEndWithProcessingError:(nonnull PSTCKErrorCompletionBlock)errorCompletion{
    NSDictionary *userInfo = @{
        NSLocalizedDescriptionKey: PSTCKCardErrorProcessingTransactionMessage,
        PSTCKErrorMessageKey: PSTCKCardErrorProcessingTransactionMessage
    };
    [self.operationQueue addOperationWithBlock:^{
        errorCompletion([[NSError alloc] initWithDomain:PaystackDomain code:PSTCKConflictError userInfo:userInfo], nil);
    }];
}

@end
