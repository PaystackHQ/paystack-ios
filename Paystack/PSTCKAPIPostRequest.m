//
//  PSTCKAPIPostRequest.m
//  Paystack
//

#import "PSTCKAPIPostRequest.h"
#import "PSTCKAPIClient.h"
#import "PSTCKAPIClient+Private.h"
#import "PaystackError.h"

@implementation PSTCKAPIPostRequest

+ (void)startWithAPIClient:(PSTCKAPIClient *)apiClient
                  endpoint:(NSString *)endpoint
                    method:(NSString *)httpMethod
                  postData:(nullable NSData *)postData
                serializer:(id<PSTCKAPIResponseDecodable>)serializer
                completion:(void (^)(id<PSTCKAPIResponseDecodable>, NSError *))completion {
    
    NSURL *url = [apiClient.apiURL URLByAppendingPathComponent:endpoint];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    request.HTTPMethod = httpMethod; // @"POST"
    if (postData != nil) {
        request.HTTPBody = postData;
    }
    
    [[apiClient.urlSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable body, __unused NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSError *someerror;
        NSDictionary *jsonDictionary = body ? [NSJSONSerialization JSONObjectWithData:body options:NSJSONReadingAllowFragments error:&someerror] : nil;
        NSString *bodyString = [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding];
        id<PSTCKAPIResponseDecodable> responseObject = [[serializer class] decodedObjectFromAPIResponse:jsonDictionary];
        NSError *returnedError = error;
        if (!responseObject && !returnedError) {
            NSDictionary *userInfo = @{
                NSLocalizedDescriptionKey: @"The response from Paystack failed to get parsed into valid JSON",
                PSTCKErrorMessageKey: [@"The response from Paystack failed to get parsed into valid JSON. Response was: " stringByAppendingString:bodyString]
            };
            returnedError = [[NSError alloc] initWithDomain:PaystackDomain code:PSTCKAPIError userInfo:userInfo];
        }
        // We're using the api client's operation queue instead of relying on the url session's operation queue
        // because the api client's queue is mutable and may have changed after initialization (not ideal)
        if (returnedError) {
            [apiClient.operationQueue addOperationWithBlock:^{
                completion(nil, returnedError);
            }];
            return;
        }
        [apiClient.operationQueue addOperationWithBlock:^{
            completion(responseObject, nil);
        }];
    }] resume];
    
}

@end
