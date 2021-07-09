//
//  PSTCKFormEncoder.h
//  Paystack
//

#import <Foundation/Foundation.h>

@class PSTCKCardParams;
@class PSTCKTransactionParams;
@protocol PSTCKFormEncodable;

@interface PSTCKFormEncoder : NSObject

+ (nonnull NSData *)formEncodedDataForObject:(nonnull NSObject<PSTCKFormEncodable> *)object
                                usePublicKey:(nonnull NSString *)public_key
                                onThisDevice:(nonnull NSString *)device_id;

+ (nonnull NSData *)formEncryptedDataForCard:(nonnull PSTCKCardParams *)card
                              andTransaction:(nonnull PSTCKTransactionParams *)transaction
                                usePublicKey:(nonnull NSString *)public_key
                                onThisDevice:(nonnull NSString *)device_id;

+ (nonnull NSData *)formEncryptedDataForCard:(nonnull PSTCKCardParams *)card
                              andTransaction:(nonnull NSString *)trans
                                   andHandle:(nonnull NSString *)handle
                                onThisDevice:(nonnull NSString *)device_id;

+(nonnull NSData *)formEncryptedDataForCard:(nonnull PSTCKCardParams *)card
                                withTransaction:(nonnull NSString *)trans
                               onThisDevice:(nonnull NSString *)device_id;


+ (nonnull NSData *)formEncryptedDataForDict:(nonnull NSDictionary *)dict
  usePublicKey:(nonnull NSString *)public_key
  onThisDevice:(nonnull NSString *)device_id;

+ (nonnull NSString *)stringByURLEncoding:(nonnull NSString *)string;

+ (nonnull NSString *)stringByReplacingSnakeCaseWithCamelCase:(nonnull NSString *)input;

@end
