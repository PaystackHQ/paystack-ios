//
//  PSTCKChargeRequeryTest.m
//  Paystack
//
//  Requery by access code (with the temporary trans fallback), status-based polling,
//  and the per-request Authorization / Paystack-Version headers.
//

@import XCTest;
@import UIKit;

#import "PSTCKAPIClient.h"
#import "PSTCKAPIClient+Private.h"
#import "PSTCKCardParams.h"
#import "PSTCKTransactionParams.h"
#import "PaystackError.h"

#pragma mark - Stub network layer

typedef NSDictionary * _Nonnull (^PSTCKStubResponder)(NSURLRequest * _Nonnull request);

static PSTCKStubResponder PSTCKStubCurrentResponder;
static NSMutableArray<NSURLRequest *> *PSTCKStubRecordedRequests;

/// Records every request and answers with the JSON the current responder returns.
@interface PSTCKStubURLProtocol : NSURLProtocol
@end

@implementation PSTCKStubURLProtocol

+ (BOOL)canInitWithRequest:(__unused NSURLRequest *)request {
    return YES;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

- (void)startLoading {
    @synchronized ([PSTCKStubURLProtocol class]) {
        [PSTCKStubRecordedRequests addObject:self.request];
    }
    NSDictionary *json = PSTCKStubCurrentResponder ? PSTCKStubCurrentResponder(self.request) : @{@"status": @"0", @"message": @"no stub"};
    NSData *body = [NSJSONSerialization dataWithJSONObject:json options:0 error:NULL];
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL
                                                              statusCode:200
                                                             HTTPVersion:@"HTTP/1.1"
                                                            headerFields:@{@"Content-Type": @"application/json"}];
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    [self.client URLProtocol:self didLoadData:body];
    [self.client URLProtocolDidFinishLoading:self];
}

- (void)stopLoading {
}

@end

#pragma mark - Private API under test

typedef NS_ENUM(NSInteger, PSTCKTestChargeStage) {
    PSTCKTestChargeStageRequery = 3, // matches PSTCKChargeStageRequery in PSTCKAPIClient.m
};

@interface PSTCKAPIClient (RequeryTesting)
@property (nonatomic) NSTimeInterval requeryInterval;
- (void)startWithCard:(nonnull PSTCKCardParams *)card
       forTransaction:(nonnull PSTCKTransactionParams *)transaction
     onViewController:(nonnull UIViewController *)viewController
      didEndWithError:(nonnull PSTCKErrorCompletionBlock)errorCompletion
didTransactionSuccess:(nonnull PSTCKTransactionCompletionBlock)successCompletion;
- (void)makeChargeRequest:(nullable NSData *)data atStage:(NSInteger)stage;
- (nullable NSString *)requeryIdentifier;
- (id)serverTransaction;
@end

#pragma mark - Tests

/// Collects how a charge ended (blocks write here instead of through stack pointers).
@interface PSTCKChargeOutcome : NSObject
@property (nonatomic) BOOL succeeded;
@property (nonatomic, nullable) NSError *error;
@end
@implementation PSTCKChargeOutcome
@end

@interface PSTCKChargeRequeryTest : XCTestCase
@property (nonatomic) PSTCKAPIClient *client;
@end

@implementation PSTCKChargeRequeryTest

- (void)setUp {
    [super setUp];
    PSTCKStubRecordedRequests = [NSMutableArray array];
    PSTCKStubCurrentResponder = nil;
    self.client = [[PSTCKAPIClient alloc] initWithPublicKey:@"pk_test_requery"];
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    config.protocolClasses = @[[PSTCKStubURLProtocol class]];
    [self.client useSessionConfiguration:config];
    self.client.requeryInterval = 0.01;
}

- (void)tearDown {
    PSTCKStubCurrentResponder = nil;
    [super tearDown];
}

/// Starts a charge's bookkeeping without the encrypted mobile_charge call (no keychain needed).
- (PSTCKChargeOutcome *)startChargeWithAccessCode:(NSString *)accessCode
                                       expectation:(XCTestExpectation *)expectation {
    PSTCKChargeOutcome *outcome = [PSTCKChargeOutcome new];
    PSTCKTransactionParams *params = [PSTCKTransactionParams new];
    if (accessCode) {
        params.access_code = accessCode;
    }
    [self.client startWithCard:[PSTCKCardParams new]
                forTransaction:params
              onViewController:[UIViewController new]
               didEndWithError:^(NSError * _Nonnull error, __unused NSString * _Nullable reference) {
        outcome.error = error;
        [expectation fulfill];
    } didTransactionSuccess:^(__unused NSString * _Nonnull reference) {
        outcome.succeeded = YES;
        [expectation fulfill];
    }];
    return outcome;
}

- (NSArray<NSURLRequest *> *)requeryRequests {
    NSPredicate *isRequery = [NSPredicate predicateWithBlock:^BOOL(NSURLRequest *request, __unused NSDictionary *bindings) {
        return [request.URL.path hasPrefix:@"/charge/requery/"];
    }];
    return [PSTCKStubRecordedRequests filteredArrayUsingPredicate:isRequery];
}

#pragma mark Access code resolution

- (void)testRequeryUsesAccessCode {
    PSTCKStubCurrentResponder = ^NSDictionary *(__unused NSURLRequest *request) {
        return @{@"status": @"success", @"message": @"Approved", @"reference": @"ref_1"};
    };
    XCTestExpectation *done = [self expectationWithDescription:@"charge ends"];
    PSTCKChargeOutcome *outcome = [self startChargeWithAccessCode:@"ac_123" expectation:done];
    [[self.client serverTransaction] setValue:@"trans_999" forKey:@"id"];

    [self.client makeChargeRequest:nil atStage:PSTCKTestChargeStageRequery];
    [self waitForExpectationsWithTimeout:2 handler:nil];

    XCTAssertTrue(outcome.succeeded);
    XCTAssertEqualObjects([self requeryRequests].firstObject.URL.path, @"/charge/requery/ac_123");
    XCTAssertEqualObjects([self requeryRequests].firstObject.HTTPMethod, @"GET");
}

- (void)testRequeryFallsBackToTransWithoutAccessCode {
    PSTCKStubCurrentResponder = ^NSDictionary *(__unused NSURLRequest *request) {
        return @{@"status": @"success", @"message": @"Approved"};
    };
    XCTestExpectation *done = [self expectationWithDescription:@"charge ends"];
    [self startChargeWithAccessCode:nil expectation:done];
    [[self.client serverTransaction] setValue:@"trans_999" forKey:@"id"];

    XCTAssertEqualObjects([self.client requeryIdentifier], @"trans_999");
    [self.client makeChargeRequest:nil atStage:PSTCKTestChargeStageRequery];
    [self waitForExpectationsWithTimeout:2 handler:nil];

    XCTAssertEqualObjects([self requeryRequests].firstObject.URL.path, @"/charge/requery/trans_999");
}

- (void)testRequeryWithoutAnyIdentifierFailsWithoutCrashing {
    XCTestExpectation *done = [self expectationWithDescription:@"charge ends"];
    PSTCKChargeOutcome *outcome = [self startChargeWithAccessCode:nil expectation:done];

    XCTAssertNil([self.client requeryIdentifier]);
    [self.client makeChargeRequest:nil atStage:PSTCKTestChargeStageRequery];
    [self waitForExpectationsWithTimeout:2 handler:nil];

    XCTAssertNotNil(outcome.error);
    XCTAssertEqual([self requeryRequests].count, (NSUInteger)0);
}

- (void)testAccessCodeIsNotCarriedIntoNextCharge {
    XCTestExpectation *unused = [self expectationWithDescription:@"unused"];
    unused.inverted = YES;
    [self startChargeWithAccessCode:@"ac_first" expectation:unused];
    XCTAssertEqualObjects([self.client requeryIdentifier], @"ac_first");

    [self startChargeWithAccessCode:nil expectation:unused];
    XCTAssertNil([self.client requeryIdentifier]);
    [self waitForExpectationsWithTimeout:0.1 handler:nil];
}

#pragma mark Status-based polling

- (void)testPendingRequeriesUntilSuccess {
    __block NSInteger calls = 0;
    PSTCKStubCurrentResponder = ^NSDictionary *(__unused NSURLRequest *request) {
        calls += 1;
        return calls < 3 ? @{@"status": @"pending", @"message": @"Pending"} : @{@"status": @"success", @"message": @"Approved"};
    };
    XCTestExpectation *done = [self expectationWithDescription:@"charge ends"];
    PSTCKChargeOutcome *outcome = [self startChargeWithAccessCode:@"ac_123" expectation:done];

    [self.client makeChargeRequest:nil atStage:PSTCKTestChargeStageRequery];
    [self waitForExpectationsWithTimeout:5 handler:nil];

    XCTAssertTrue(outcome.succeeded);
    XCTAssertEqual([self requeryRequests].count, (NSUInteger)3);
}

- (void)testFailedStatusIsTerminal {
    PSTCKStubCurrentResponder = ^NSDictionary *(__unused NSURLRequest *request) {
        return @{@"status": @"failed", @"message": @"Declined"};
    };
    XCTestExpectation *done = [self expectationWithDescription:@"charge ends"];
    PSTCKChargeOutcome *outcome = [self startChargeWithAccessCode:@"ac_123" expectation:done];

    [self.client makeChargeRequest:nil atStage:PSTCKTestChargeStageRequery];
    [self waitForExpectationsWithTimeout:2 handler:nil];

    XCTAssertEqualObjects(outcome.error.localizedDescription, @"Declined");
    XCTAssertEqual([self requeryRequests].count, (NSUInteger)1);
}

- (void)testPendingStopsAtAttemptCap {
    PSTCKStubCurrentResponder = ^NSDictionary *(__unused NSURLRequest *request) {
        return @{@"status": @"pending", @"message": @"Pending"};
    };
    XCTestExpectation *done = [self expectationWithDescription:@"charge ends"];
    PSTCKChargeOutcome *outcome = [self startChargeWithAccessCode:@"ac_123" expectation:done];

    [self.client makeChargeRequest:nil atStage:PSTCKTestChargeStageRequery];
    [self waitForExpectationsWithTimeout:5 handler:nil];

    XCTAssertNotNil(outcome.error);
    // The first requery plus 12 scheduled retries.
    XCTAssertEqual([self requeryRequests].count, (NSUInteger)13);
}

#pragma mark Headers

- (void)testEveryRequestCarriesAuthorizationAndVersionHeaders {
    PSTCKStubCurrentResponder = ^NSDictionary *(__unused NSURLRequest *request) {
        return @{@"status": @"success", @"message": @"Approved"};
    };
    XCTestExpectation *done = [self expectationWithDescription:@"charge ends"];
    [self startChargeWithAccessCode:@"ac_123" expectation:done];

    [self.client makeChargeRequest:nil atStage:PSTCKTestChargeStageRequery];
    [self waitForExpectationsWithTimeout:2 handler:nil];

    NSURLRequest *request = [self requeryRequests].firstObject;
    XCTAssertEqualObjects([request valueForHTTPHeaderField:@"Authorization"], @"Bearer pk_test_requery");
    XCTAssertEqualObjects([request valueForHTTPHeaderField:@"Paystack-Version"], [PSTCKAPIClient paystackVersionHeaderValue]);
}

- (void)testAuthorizationHeaderFollowsCurrentPublicKey {
    self.client.publicKey = @"pk_test_rotated";
    NSURLRequest *request = [self.client authorizedRequestWithURL:[NSURL URLWithString:@"https://standard.paystack.co/charge/requery/x"]
                                                           method:@"GET"];
    XCTAssertEqualObjects([request valueForHTTPHeaderField:@"Authorization"], @"Bearer pk_test_rotated");
}

- (void)testNoRequestIsBuiltWithoutPublicKey {
    self.client.publicKey = @"";
    XCTAssertNil([self.client authorizedRequestWithURL:[NSURL URLWithString:@"https://standard.paystack.co/charge/requery/x"]
                                                method:@"GET"]);
}

- (void)testPaystackVersionIsSemanticVersionNotDate {
    NSString *version = [PSTCKAPIClient paystackVersionHeaderValue];
    XCTAssertFalse([version isEqualToString:@"2017-05-25"]);
    XCTAssertTrue([version componentsSeparatedByString:@"."].count >= 2, @"expected x.y.z, got %@", version);
}

@end
