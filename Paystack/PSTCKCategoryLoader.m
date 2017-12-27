//
//  PSTCKCategoryLoader.m
//  Paystack
//

#ifdef PSTCK_STATIC_LIBRARY_BUILD

#import "PSTCKCategoryLoader.h"
#import "NSDictionary+Paystack.h"
#import "UIImage+Paystack.h"

@implementation PSTCKCategoryLoader

+ (void)loadCategories {
    linkDictionaryCategory();
    linkUIImageCategoryPaystack();
}

@end

#endif
