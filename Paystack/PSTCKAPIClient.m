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

#if __has_include("Fabric.h")
#import "Fabric+FABKits.h"
#import "FABKitProtocol.h"
#endif

#ifdef PSTCK_STATIC_LIBRARY_BUILD
#import "PSTCKCategoryLoader.h"
#endif

#define FAUXPAS_IGNORED_IN_METHOD(...)

static NSString *const apiURLBase = @"standard.paystack.co";
static NSString *const chargeEndpoint = @"charge/mobile_charge";
static NSString *const validateEndpoint = @"charge/validate";
static NSString *const requeryEndpoint = @"charge/requery/";
static NSString *const paystackAPIVersion = @"2017-05-25";
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

#if __has_include("Fabric.h")
@interface PSTCKAPIClient ()<NSURLSessionDelegate, FABKit>
#else
@interface PSTCKAPIClient()<NSURLSessionDelegate>
#endif
@property (nonatomic, readwrite) NSURL *apiURL;
@property (nonatomic, readwrite) NSURLSession *urlSession;
@end

@interface PSTCKServerTransaction : NSObject

@property (nonatomic, readwrite, nullable) NSString *id;
@property (nonatomic, readwrite, nullable) NSString *reference;

@end
@implementation PSTCKServerTransaction
- (instancetype)init {
    _id = nil;
    _reference = nil;
    
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
@property(nonatomic) PSTCKChargeRequestAlerts chargeReqestAlertsState;
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
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        NSString *auth = [@"Bearer " stringByAppendingString:self.publicKey];
        config.HTTPAdditionalHeaders = @{
                                         @"X-Paystack-User-Agent": [self.class paystackUserAgentDetails],
                                         @"Paystack-Version": paystackAPIVersion,
                                         @"Authorization": auth,
                                         @"X-Paystack-Build": PSTCKSDKBuild,
                                         };
        _urlSession = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:_operationQueue];
    }
    return self;
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

#pragma mark Fabric
#if __has_include("Fabric.h")

+ (NSString *)bundleIdentifier {
    return @"com.paystack.paystack-ios";
}

+ (NSString *)kitDisplayVersion {
    return PSTCKSDKVersion;
}

+ (void)initializeIfNeeded {
    Class fabric = NSClassFromString(@"Fabric");
    if (fabric) {
        // The app must be using Fabric, as it exists at runtime. We fetch our default public key from Fabric.
        NSDictionary *fabricConfiguration = [fabric configurationDictionaryForKitClass:[PSTCKAPIClient class]];
        NSString *publicKey = fabricConfiguration[@"public"];
        if (!publicKey) {
            NSLog(@"Configuration dictionary returned by Fabric was nil, or doesn't have publicKey. Can't initialize Paystack.");
            return;
        }
        [self validateKey:publicKey];
        [Paystack setDefaultPublicKey:publicKey];
    } else {
        NSCAssert(fabric, @"initializeIfNeeded method called from a project that doesn't have Fabric.");
    }
}

#endif

@end

typedef NS_ENUM(NSInteger, PSTCKChargeStage) {
    PSTCKChargeStageNoHandle,
    PSTCKChargeStagePlusHandle,
    PSTCKChargeStageValidateToken,
    PSTCKChargeStageRequery,
    PSTCKChargeStageAuthorize,
};


#pragma mark - Credit Cards
@implementation PSTCKAPIClient (CreditCards)

- (void)chargeCard:(nonnull PSTCKCardParams *)card
    forTransaction:(nonnull PSTCKTransactionParams *)transaction
  onViewController:(nonnull UIViewController *)viewController
   didEndWithError:(nonnull PSTCKErrorCompletionBlock)errorCompletion
didTransactionSuccess:(nonnull PSTCKTransactionCompletionBlock)successCompletion {
    NSCAssert(card != nil, @"'card' is required for a charge");
    NSCAssert(errorCompletion != nil, @"'errorCompletion' is required to handle any errors encountered while charging");
    NSCAssert(viewController != nil, @"'viewController' is required to show any alerts that may be needed");
    NSCAssert(transaction != nil, @"'transaction' is required so we may know who to charge");
    NSCAssert(successCompletion != nil, @"'successCompletion' is required so you can continue the process after charge succeeds. Remember to verify on server before giving value.");
    [self startWithCard:card forTransaction:transaction onViewController:viewController didEndWithError:errorCompletion didTransactionSuccess:successCompletion];
    
    if(PROCESSING){
        [self didEndWithProcessingError];
        return;
    }
    PROCESSING = YES;
    self.INVALID_DATA_SENT_RETRIES = 0;
    NSData *data = [PSTCKFormEncoder formEncryptedDataForCard:card
                                               andTransaction:transaction
                                                 usePublicKey:[self publicKey]
                                                 onThisDevice:[self.class device_id]];
    
    [self makeChargeRequest:data atStage:PSTCKChargeStageNoHandle];
}

- (void)chargeCard:(nonnull PSTCKCardParams *)card
    forTransaction:(nonnull PSTCKTransactionParams *)transaction
  onViewController:(nonnull UIViewController *)viewController
   didEndWithError:(nonnull PSTCKErrorCompletionBlock)errorCompletion
didRequestValidation:(nonnull PSTCKTransactionCompletionBlock)beforeValidateCompletion
 willPresentDialog:(nonnull PSTCKNotifyCompletionBlock)showingDialogCompletion
   dismissedDialog:(nonnull PSTCKNotifyCompletionBlock)dialogDismissedCompletion
didTransactionSuccess:(nonnull PSTCKTransactionCompletionBlock)successCompletion {
    self.beforeValidateCompletion = beforeValidateCompletion;
    self.showingDialogCompletion = showingDialogCompletion;
    self.dialogDismissedCompletion = dialogDismissedCompletion;
    [self chargeCard:card forTransaction:transaction onViewController:viewController didEndWithError:errorCompletion didTransactionSuccess:successCompletion];
    
}

- (void)chargeCard:(nonnull PSTCKCardParams *)card
    forTransaction:(nonnull PSTCKTransactionParams *)transaction
  onViewController:(nonnull UIViewController *)viewController
   didEndWithError:(nonnull PSTCKErrorCompletionBlock)errorCompletion
 willPresentDialog:(nonnull PSTCKNotifyCompletionBlock)showingDialogCompletion
   dismissedDialog:(nonnull PSTCKNotifyCompletionBlock)dialogDismissedCompletion
didTransactionSuccess:(nonnull PSTCKTransactionCompletionBlock)successCompletion {
    self.showingDialogCompletion = showingDialogCompletion;
    self.dialogDismissedCompletion = dialogDismissedCompletion;
    [self chargeCard:card forTransaction:transaction onViewController:viewController didEndWithError:errorCompletion didTransactionSuccess:successCompletion];
    
}

- (void)chargeCard:(nonnull PSTCKCardParams *)card
    forTransaction:(nonnull PSTCKTransactionParams *)transaction
  onViewController:(nonnull UIViewController *)viewController
   didEndWithError:(nonnull PSTCKErrorCompletionBlock)errorCompletion
didRequestValidation:(nonnull PSTCKTransactionCompletionBlock)beforeValidateCompletion
didTransactionSuccess:(nonnull PSTCKTransactionCompletionBlock)successCompletion {
    self.beforeValidateCompletion = beforeValidateCompletion;
    [self chargeCard:card forTransaction:transaction onViewController:viewController didEndWithError:errorCompletion didTransactionSuccess:successCompletion];
    
}

- (void)chargeCard:(PSTCKCardParams *)card
    forTransaction:(PSTCKTransactionParams *)transaction
  onViewController:(UIViewController *)viewController
        alertsType:(PSTCKChargeRequestAlerts)state
   didEndWithError:(PSTCKErrorCompletionBlock)errorCompletion
didRequestValidation:(PSTCKTransactionCompletionBlock)beforeValidateCompletion
didTransactionSuccess:(PSTCKTransactionCompletionBlock)successCompletion {
    self.beforeValidateCompletion = beforeValidateCompletion;
    [self chargeCard:card forTransaction:transaction onViewController:viewController didEndWithError:errorCompletion didTransactionSuccess:successCompletion];
    [self setChargeReqestAlertsState:state];
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
        case PSTCKChargeStageRequery:
        case PSTCKChargeStageAuthorize:
            endpoint =  [requeryEndpoint stringByAppendingString:self.serverTransaction.id] ;
            httpMethod = @"GET";
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
    switch (self.chargeReqestAlertsState) {
        case PSTCKChargeRequestAlertsCustomPin:
            [self requestPinCustom];
            break;
        case PSTCKChargeRequestAlertsCustomAlerts:
            [self requestPinCustom];
            break;
        default:
            [self requestPinAlert];
            break;
    }
}

- (void)requestPinCustom {
    if ([self.delegate respondsToSelector:@selector(PSTCKCustomPinMethodWith:)]) {
        __weak typeof (self) weakSelf = self;
        [self.delegate PSTCKCustomPinMethodWith:^(NSString * _Nonnull reference) {
            [weakSelf performPinActionWithText:reference];
        }];
    }
}

- (void) requestPinAlert {
    [self notifyShowingDialog];
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Enter CARD PIN"
                                                                   message:@"To confirm that you are the owner of this card please enter your card PIN"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    __weak typeof (self) weakSelf = self;
    UIAlertAction* defaultAction = [UIAlertAction
                                    actionWithTitle:@"Continue" style:UIAlertActionStyleDefault
                                    handler:^(UIAlertAction * action) {
                                        [action isEnabled]; // Just to avoid Unused error
                                        [weakSelf performPinActionWithText:[alert.textFields objectAtIndex:0].text];
                                    }];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"****";
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        textField.secureTextEntry = YES;
    }];
    
    [alert addAction:defaultAction];
    [self.viewController presentViewController:alert animated:YES completion:nil];
}

- (void)performPinActionWithText:(NSString *) text {
    
    [self notifyDialogDismissed];
    NSString *handle = [PSTCKCardValidator sanitizedNumericStringForString:text];
    if(handle == nil ||
       [handle length]!=4 ||
       ([text length] != [handle length])){
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
    switch (self.chargeReqestAlertsState) {
        case PSTCKChargeRequestAlertsCustomOtp:
            [self requestOtpCustom];
            break;
        case PSTCKChargeRequestAlertsCustomAlerts:
            [self requestOtpCustom];
            break;
        default:
            [self requestOtpAlert:otpmessage];
            break;
    }
}

- (void)requestOtpCustom {
    if ([self.delegate respondsToSelector:@selector(PSTCKCustomOtpMethodWith:)]) {
        __weak typeof (self) weakSelf = self;
        [self.delegate PSTCKCustomOtpMethodWith:^(NSString * _Nonnull reference) {
            [weakSelf performOtpActionWithText:reference];
        }];
    }
}

- (void) requestOtpAlert:(NSString * _Nonnull) otpmessage {
    [self notifyShowingDialog];
    [self notifyBeforeValidate];
    UIAlertController* tkalert = [UIAlertController alertControllerWithTitle:@"Enter OTP"
                                                                     message:otpmessage
                                                              preferredStyle:UIAlertControllerStyleAlert];
    
    __weak typeof (self) weakSelf = self;
    UIAlertAction* tkdefaultAction = [UIAlertAction
                                      actionWithTitle:@"Continue" style:UIAlertActionStyleDefault
                                      handler:^(UIAlertAction * action) {
                                          [action isEnabled]; // Just to avoid Unused error
                                          [weakSelf performOtpActionWithText:((UITextField *)[tkalert.textFields objectAtIndex:0]).text];
                                      }];
    
    [tkalert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"OTP";
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [tkalert addAction:tkdefaultAction];
    [self.viewController presentViewController:tkalert animated:YES completion:nil];
}

- (void)performOtpActionWithText:(NSString *) text {
    [self notifyDialogDismissed];
    PSTCKValidationParams *validateParams = [PSTCKValidationParams alloc];
    validateParams.trans = self.serverTransaction.id;
    validateParams.token = text;
    NSData *vdata = [PSTCKFormEncoder formEncodedDataForObject:validateParams
                                                  usePublicKey:[self publicKey]
                                                  onThisDevice:[self.class device_id]];
    [self makeChargeRequest:vdata
                    atStage:PSTCKChargeStageValidateToken];
}

- (void) handleResponse:(PSTCKTransaction * _Nonnull)responseObject{
    if([[responseObject status] isEqual:@"1"] || [[responseObject status] isEqual:@"success"]){
        [self didEndSuccessfully];
        return;
    } else if([[responseObject status] isEqual:@"2"] || [[responseObject auth].lowercaseString isEqual:@"pin"]){
        [self requestPin];
        return;
    } else if([self.serverTransaction id] != nil){
        if([[responseObject auth].lowercaseString isEqual:@"3ds"] && [self validUrl:[responseObject otpmessage]]){
            [self requestAuth:[responseObject otpmessage]];
            return;
        } else if([[responseObject status] isEqual:@"3"]
                  || ([[responseObject auth].lowercaseString isEqual:@"otp"] && [responseObject otpmessage] != nil)
                  || ([[responseObject auth].lowercaseString isEqual:@"phone"] && [responseObject otpmessage] != nil)){
            [self requestOtp:([responseObject otpmessage] != nil ? [responseObject otpmessage] : [responseObject message])];
            return;
        } else if([[responseObject status].lowercaseString isEqual:@"requery"]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC),
                           dispatch_get_main_queue(), ^{
                               [self.operationQueue addOperationWithBlock:^{
                                   [self makeChargeRequest:nil
                                                   atStage:PSTCKChargeStageRequery];
                               }];
                           });
            return;
        }
    }
    
    if([[responseObject status] isEqual:@"0"] || [[responseObject status] isEqual:@"error"] || [[responseObject status] isEqual:@"timeout"]){
        [self didEndWithErrorMessage:[responseObject message]];
    } else {
        // this is an invalid status
        [self didEndWithErrorMessage:[@"The response status from Paystack had an unknown status. Status was: " stringByAppendingString:[responseObject status]]];
    }
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
                               NSLocalizedDescriptionKey: PSTCKCardErrorProcessingErrorUserMessage,
                               PSTCKErrorMessageKey: errorString
                               };
    PROCESSING=NO;
    [self didEndWithError:[[NSError alloc] initWithDomain:PaystackDomain code:PSTCKCardErrorProcessingError userInfo:userInfo]];
}

- (void)didEndWithProcessingError{
    NSDictionary *userInfo = @{
                               NSLocalizedDescriptionKey: PSTCKCardErrorProcessingTransactionMessage,
                               PSTCKErrorMessageKey: PSTCKCardErrorProcessingTransactionMessage
                               };
    [self.operationQueue addOperationWithBlock:^{
        self.errorCompletion([[NSError alloc] initWithDomain:PaystackDomain code:PSTCKConflictError userInfo:userInfo], self.serverTransaction.reference);
    }];
}

@end
