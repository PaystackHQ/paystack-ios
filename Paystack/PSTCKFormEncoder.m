//
//  PSTCKFormEncoder.m
//  Paystack
//

#import "PSTCKFormEncoder.h"
#import "PSTCKCardParams.h"
#import "PSTCKTransactionParams.h"
#import "PSTCKFormEncodable.h"

FOUNDATION_EXPORT NSString * PSTCKPercentEscapedStringFromString(NSString *string);
FOUNDATION_EXPORT NSString * PSTCKQueryStringFromParameters(NSDictionary *parameters);

#pragma mark PSTCKQueryStringPair

@interface PSTCKQueryStringPair : NSObject
@property (readwrite, nonatomic, strong) id field;
@property (readwrite, nonatomic, strong) id value;

- (instancetype)initWithField:(id)field value:(id)value;

- (NSString *)URLEncodedStringValue;
@end

@implementation PSTCKQueryStringPair

- (instancetype)initWithField:(id)field value:(id)value {
    self = [super init];
    if (!self) {
        return nil;
    }

    _field = field;
    _value = value;

    return self;
}

- (NSString *)URLEncodedStringValue {
    if (!self.value || [self.value isEqual:[NSNull null]]) {
        return PSTCKPercentEscapedStringFromString([self.field description]);
    } else {
        NSString *encoded= [NSString stringWithFormat:@"%@=%@", PSTCKPercentEscapedStringFromString([self.field description]), PSTCKPercentEscapedStringFromString([self.value description])];
        // never send negative transaction_charge
        if([encoded hasPrefix:@"transaction_charge=-"])
            return @"";
        return encoded;
    }
}

@end

@implementation PSTCKFormEncoder

+ (NSString *)stringByReplacingSnakeCaseWithCamelCase:(NSString *)input {
    NSArray *parts = [input componentsSeparatedByString:@"_"];
    NSMutableString *camelCaseParam = [NSMutableString string];
    [parts enumerateObjectsUsingBlock:^(NSString *part, NSUInteger idx, __unused BOOL *stop) {
        [camelCaseParam appendString:(idx == 0 ? part : [part capitalizedString])];
    }];
    
    return [camelCaseParam copy];
}


+ (nonnull NSData *)formEncryptedDataForCard:(nonnull PSTCKCardParams *)card
                              andTransaction:(nonnull PSTCKTransactionParams *)transaction
                                usePublicKey:(nonnull NSString *)public_key
                                onThisDevice:(nonnull NSString *)device_id {
    NSString *urlencodedcard = [PSTCKFormEncoder urlEncodedStringForObject:card];
    NSString *urlencodedtransaction = [PSTCKFormEncoder urlEncodedStringForObject:transaction];
    NSString *urlencodedpublickey = [[[PSTCKQueryStringPair alloc] initWithField:@"public_key" value:public_key] URLEncodedStringValue];
    NSString *urlencodeddevice = [[[PSTCKQueryStringPair alloc] initWithField:@"device" value:device_id] URLEncodedStringValue];
    return [[NSString stringWithFormat:@"%@&%@&%@&%@", urlencodedcard, urlencodedtransaction, urlencodedpublickey, urlencodeddevice] dataUsingEncoding:NSUTF8StringEncoding];
}

+ (nonnull NSData *)formEncryptedDataForCard:(nonnull PSTCKCardParams *)card
                                withTransaction:(nonnull NSString *)trans
                                onThisDevice:(nonnull NSString *)device_id {
    NSString *urlencodedcard = [PSTCKFormEncoder urlEncodedStringForObject:card];
    NSString *urlencodedtransaction = [[[PSTCKQueryStringPair alloc] initWithField:@"trans" value:trans] URLEncodedStringValue];
    NSString *urlencodeddevice = [[[PSTCKQueryStringPair alloc] initWithField:@"device" value:device_id] URLEncodedStringValue];
    NSString *urlencodedsource = [[[PSTCKQueryStringPair alloc] initWithField:@"source" value: @"ios"] URLEncodedStringValue];
    return [[NSString stringWithFormat:@"%@&%@&%@&%@", urlencodedcard, urlencodedtransaction, urlencodeddevice, urlencodedsource] dataUsingEncoding:NSUTF8StringEncoding];
}

+ (nonnull NSData *)formEncryptedDataForCard:(nonnull PSTCKCardParams *)card
                              andTransaction:(nonnull NSString *)trans
                                   andHandle:(nonnull NSString *)handle
                                onThisDevice:(nonnull NSString *)device_id {
    NSString *urlencodedcard = [PSTCKFormEncoder urlEncodedStringForObject:card];
    NSString *urlencodedtransaction = [[[PSTCKQueryStringPair alloc] initWithField:@"trans" value:trans] URLEncodedStringValue];
    NSString *urlencodedhandle = [[[PSTCKQueryStringPair alloc] initWithField:@"handle" value:handle] URLEncodedStringValue];
    NSString *urlencodeddevice = [[[PSTCKQueryStringPair alloc] initWithField:@"device" value:device_id] URLEncodedStringValue];
    NSString *urlencodedsource = [[[PSTCKQueryStringPair alloc] initWithField:@"source" value: @"ios"] URLEncodedStringValue];
    return [[NSString stringWithFormat:@"%@&%@&%@&%@&%@", urlencodedcard, urlencodedtransaction, urlencodedhandle, urlencodeddevice, urlencodedsource] dataUsingEncoding:NSUTF8StringEncoding];
}

+ (NSData *)formEncryptedDataForDict:(NSDictionary *)dict usePublicKey:(NSString *)public_key onThisDevice:(NSString *)device_id {
    NSString *encodedDict = PSTCKQueryStringFromParameters(dict);
    NSString *urlencodedpublickey = [[[PSTCKQueryStringPair alloc] initWithField:@"public_key" value:public_key] URLEncodedStringValue];
    NSString *urlencodeddevice = [[[PSTCKQueryStringPair alloc] initWithField:@"device" value:device_id] URLEncodedStringValue];
    return [[NSString stringWithFormat:@"%@&%@&%@", encodedDict, urlencodedpublickey, urlencodeddevice] dataUsingEncoding:NSUTF8StringEncoding];
}

+ (nonnull NSData *)formEncodedDataForObject:(nonnull NSObject<PSTCKFormEncodable> *)object
                                usePublicKey:(nonnull NSString *)public_key
                                onThisDevice:(nonnull NSString *)device_id {
    NSString *urlencodedobject = [PSTCKFormEncoder urlEncodedStringForObject:object];
    NSString *urlencodedpublickey = [[[PSTCKQueryStringPair alloc] initWithField:@"public_key" value:public_key] URLEncodedStringValue];
    NSString *urlencodeddevice = [[[PSTCKQueryStringPair alloc] initWithField:@"device" value:device_id] URLEncodedStringValue];
    return [[NSString stringWithFormat:@"%@&%@&%@", urlencodedobject, urlencodedpublickey, urlencodeddevice] dataUsingEncoding:NSUTF8StringEncoding];
}

+ (nonnull NSString *)urlEncodedStringForObject:(nonnull NSObject<PSTCKFormEncodable> *)object {
    NSDictionary *dict = @{
                           [object.class rootObjectName]: [self keyPairDictionaryForObject:object]
                           };
    return PSTCKQueryStringFromParameters(dict) ;
}

+ (NSDictionary *)keyPairDictionaryForObject:(nonnull NSObject<PSTCKFormEncodable> *)object {
    NSMutableDictionary *keyPairs = [NSMutableDictionary dictionary];
    [[object.class propertyNamesToFormFieldNamesMapping] enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull propertyName, NSString *  _Nonnull formFieldName, __unused BOOL * _Nonnull stop) {
        id value = [self formEncodableValueForObject:[object valueForKey:propertyName]];
        if (value) {
            keyPairs[formFieldName] = value;
        }
    }];
    [object.additionalAPIParameters enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull additionalFieldName, id  _Nonnull additionalFieldValue, __unused BOOL * _Nonnull stop) {
        id value = [self formEncodableValueForObject:additionalFieldValue];
        if (value) {
            keyPairs[additionalFieldName] = value;
        }
    }];
    return [keyPairs copy];
}

+ (id)formEncodableValueForObject:(NSObject *)object {
    if ([object conformsToProtocol:@protocol(PSTCKFormEncodable)]) {
        return [self keyPairDictionaryForObject:(NSObject<PSTCKFormEncodable>*)object];
    } else {
        return object;
    }
}

+ (NSString *)stringByURLEncoding:(NSString *)string {
    return PSTCKPercentEscapedStringFromString(string);
}

@end


// This code is adapted from https://github.com/AFNetworking/AFNetworking/blob/master/AFNetworking/AFURLRequestSerialization.m . The only modifications are to replace the AF namespace with the PSTCK namespace to avoid collisions with apps that are using both Paystack and AFNetworking.
NSString * PSTCKPercentEscapedStringFromString(NSString *string) {
    static NSString * const kPSTCKCharactersGeneralDelimitersToEncode = @":#[]@"; // does not include "?" or "/" due to RFC 3986 - Section 3.4
    static NSString * const kPSTCKCharactersSubDelimitersToEncode = @"!$&'()*+,;=";
    
    NSMutableCharacterSet * allowedCharacterSet = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
    [allowedCharacterSet removeCharactersInString:[kPSTCKCharactersGeneralDelimitersToEncode stringByAppendingString:kPSTCKCharactersSubDelimitersToEncode]];
    
    // FIXME: https://github.com/AFNetworking/AFNetworking/pull/3028
    // return [string stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacterSet];
    
    static NSUInteger const batchSize = 50;
    
    NSUInteger index = 0;
    NSMutableString *escaped = @"".mutableCopy;
    
    while (index < string.length) {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wgnu"
        NSUInteger length = MIN(string.length - index, batchSize);
#pragma GCC diagnostic pop
        NSRange range = NSMakeRange(index, length);
        
        // To avoid breaking up character sequences such as 👴🏻👮🏽
        range = [string rangeOfComposedCharacterSequencesForRange:range];
        
        NSString *substring = [string substringWithRange:range];
        NSString *encoded = [substring stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacterSet];
        [escaped appendString:encoded];
        
        index += range.length;
    }
    
    return escaped;
}

#pragma mark -

FOUNDATION_EXPORT NSArray * PSTCKQueryStringPairsFromDictionary(NSDictionary *dictionary);
FOUNDATION_EXPORT NSArray * PSTCKQueryStringPairsFromKeyAndValue(NSString *key, id value);

NSString * PSTCKQueryStringFromParameters(NSDictionary *parameters) {
    NSMutableArray *mutablePairs = [NSMutableArray array];
    for (PSTCKQueryStringPair *pair in PSTCKQueryStringPairsFromDictionary(parameters)) {
        [mutablePairs addObject:[pair URLEncodedStringValue]];
    }
    
    return [mutablePairs componentsJoinedByString:@"&"];
}

NSArray * PSTCKQueryStringPairsFromDictionary(NSDictionary *dictionary) {
    return PSTCKQueryStringPairsFromKeyAndValue(nil, dictionary);
}

NSArray * PSTCKQueryStringPairsFromKeyAndValue(NSString *key, id value) {
    NSMutableArray *mutableQueryStringComponents = [NSMutableArray array];
    NSString *descriptionSelector = NSStringFromSelector(@selector(description));
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:descriptionSelector ascending:YES selector:@selector(compare:)];
    
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dictionary = value;
        // Sort dictionary keys to ensure consistent ordering in query string, which is important when deserializing potentially ambiguous sequences, such as an array of dictionaries
        for (id nestedKey in [dictionary.allKeys sortedArrayUsingDescriptors:@[ sortDescriptor ]]) {
            id nestedValue = dictionary[nestedKey];
            if (nestedValue) {
                [mutableQueryStringComponents addObjectsFromArray:PSTCKQueryStringPairsFromKeyAndValue((key ? [NSString stringWithFormat:@"%@%@", key, nestedKey] : nestedKey), nestedValue)];
            }
        }
    } else if ([value isKindOfClass:[NSArray class]]) {
        NSArray *array = value;
        for (id nestedValue in array) {
            [mutableQueryStringComponents addObjectsFromArray:PSTCKQueryStringPairsFromKeyAndValue([NSString stringWithFormat:@"%@[]", key], nestedValue)];
        }
    } else if ([value isKindOfClass:[NSSet class]]) {
        NSSet *set = value;
        for (id obj in [set sortedArrayUsingDescriptors:@[ sortDescriptor ]]) {
            [mutableQueryStringComponents addObjectsFromArray:PSTCKQueryStringPairsFromKeyAndValue(key, obj)];
        }
    } else {
        [mutableQueryStringComponents addObject:[[PSTCKQueryStringPair alloc] initWithField:key value:value]];
    }
    
    return mutableQueryStringComponents;
}
