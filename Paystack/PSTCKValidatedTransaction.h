//
//  PSTCKValidatedTransaction.h
//  PaystackiOS
//
//  Created by Jubril Olambiwonnu on 24/05/2021.
//  Copyright © 2021 Paystack, Inc. All rights reserved.
//


#import <Foundation/Foundation.h>
#import "PSTCKAPIResponseDecodable.h"


/**
 *  A transaction returned after validating the acces code sent from your severI. You should not have to instantiate one of these directly.
 */
@interface PSTCKValidatedTransaction : NSObject<PSTCKAPIResponseDecodable>

/**
 *  You cannot directly instantiate an PSTCKValidatedTransaction. You should only use one that has been returned from an PSTCKAPIClient callback.
 */
- (nonnull instancetype) init;

@property (nonatomic, readonly, nonnull) NSString *id;


@end
