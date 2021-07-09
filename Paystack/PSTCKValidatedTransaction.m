//
//  PSTCKValidatedTransaction.m
//  Paystack
//
//  Created by Jubril Olambiwonnu on 24/05/2021.
//  Copyright © 2021 Paystack, Inc. All rights reserved.
//

#import "PSTCKValidatedTransaction.h"
#import "NSDictionary+Paystack.h"


@interface PSTCKValidatedTransaction()
@property (nonatomic) NSString *id;
@property (nonatomic, readwrite, nonnull, copy) NSDictionary *allResponseFields;


@end

@implementation PSTCKValidatedTransaction

- (instancetype)init
{
    self = [super init];
    if (self) {
        
    }
    return self;
}

+ (NSArray *)requiredFields {
    //return @[@"id", @"livemode", @"created"];
    return @[@"data"];
}

+ (instancetype)decodedObjectFromAPIResponse:(NSDictionary *)response {
    NSDictionary *dict = [response pstck_dictionaryByRemovingNullsValidatingRequiredFields:[self requiredFields]];
    if (!dict) {
        return nil;
    }
    NSLog(@"%@", dict);
    PSTCKValidatedTransaction *transaction = [self new];
    transaction.id = dict[@"data"][@"id"];
    transaction.allResponseFields = dict;

    return transaction;
}

@end
