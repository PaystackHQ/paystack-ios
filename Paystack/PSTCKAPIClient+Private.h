//
//  PSTCKAPIClient+Private.h
//  Paystack


#import <Foundation/Foundation.h>
#import "PSTCKAPIClient.h"

@interface PSTCKAPIClient ()<NSURLSessionDelegate>

@property (nonatomic, readwrite, nonnull) NSURL *apiURL;
@property (nonatomic, readwrite, nonnull) NSURLSession *urlSession;

/**
 *  Rebuilds `urlSession` from `configuration`, adding the SDK's static headers.
 *  Used by init with the default configuration; tests pass one with stub protocol classes.
 */
- (void)useSessionConfiguration:(nonnull NSURLSessionConfiguration *)configuration;

/**
 *  A request carrying the per-request headers every Paystack call needs:
 *  `Authorization: Bearer <publicKey>` and `Paystack-Version: <SDK version>`.
 *  Returns nil when `publicKey` is nil or empty, so callers fail instead of sending `Bearer `.
 */
- (nullable NSMutableURLRequest *)authorizedRequestWithURL:(nonnull NSURL *)url method:(nonnull NSString *)httpMethod;

/// Value sent as the `Paystack-Version` header: the SDK version from the project config.
+ (nonnull NSString *)paystackVersionHeaderValue;

@end
