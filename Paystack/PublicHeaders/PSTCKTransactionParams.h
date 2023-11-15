//
//  PSTCKTransactionParams.h
//  Paystack
//

#import <Foundation/Foundation.h>
#import "PSTCKFormEncodable.h"
/**
 *  Representation of the transaction to perform on a card
 */
@interface PSTCKTransactionParams : NSObject<PSTCKFormEncodable>

@property (nonatomic, copy, nonnull) NSString *access_code;

@property (nonatomic, copy, nonnull) NSString *email;
@property (nonatomic) NSUInteger amount;
@property (nonatomic, copy, nullable) NSString *reference;
@property (nonatomic, copy, nullable) NSString *subaccount;
@property (nonatomic) NSInteger transaction_charge;
@property (nonatomic, copy, nullable) NSString *bearer;
@property (nonatomic, readonly, nullable) NSString *metadata;
@property (nonatomic, nullable) NSString *plan;
@property (nonatomic, nullable) NSString *currency;

- (nullable PSTCKTransactionParams *) setMetadataValue:(nonnull NSString*)value
                   forKey:(nonnull NSString*)key
                    error:(NSError * _Nullable __autoreleasing * _Nonnull) error
__attribute__((deprecated("This SDK has been deprecated, Please refer to our new SDK: https://github.com/PaystackHQ/paystack-sdk-ios")));

- (nullable PSTCKTransactionParams *) setMetadataValueDict:(nonnull NSMutableDictionary*)dict
                   forKey:(nonnull NSString*)key
                    error:(NSError * _Nullable __autoreleasing * _Nonnull) error
__attribute__((deprecated("This SDK has been deprecated, Please refer to our new SDK: https://github.com/PaystackHQ/paystack-sdk-ios")));

- (nullable PSTCKTransactionParams *) setMetadataValueArray:(nonnull NSMutableArray*)arr
                   forKey:(nonnull NSString*)key
                    error:(NSError * _Nullable __autoreleasing * _Nonnull) error
__attribute__((deprecated("This SDK has been deprecated, Please refer to our new SDK: https://github.com/PaystackHQ/paystack-sdk-ios")));

- (nullable PSTCKTransactionParams *) setCustomFieldValue:(nonnull NSString*)value
                 displayedAs:(nonnull NSString*)display_name
                       error:(NSError * _Nullable __autoreleasing * _Nonnull) error
__attribute__((deprecated("This SDK has been deprecated, Please refer to our new SDK: https://github.com/PaystackHQ/paystack-sdk-ios")));
@end
