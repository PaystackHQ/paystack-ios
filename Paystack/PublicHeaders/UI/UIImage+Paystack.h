//
//  UIImage+Paystack.h
//  Paystack
//

#import <UIKit/UIKit.h>
#import "PSTCKCardBrand.h"

@interface UIImage (Paystack)

+ (nonnull UIImage *)pstck_amexCardImage;
+ (nonnull UIImage *)pstck_dinersClubCardImage;
+ (nonnull UIImage *)pstck_discoverCardImage;
+ (nonnull UIImage *)pstck_jcbCardImage;
+ (nonnull UIImage *)pstck_masterCardCardImage;
+ (nonnull UIImage *)pstck_visaCardImage;
+ (nonnull UIImage *)pstck_unknownCardCardImage;

+ (nullable UIImage *)pstck_brandImageForCardBrand:(PSTCKCardBrand)brand;
+ (nullable UIImage *)pstck_cvcImageForCardBrand:(PSTCKCardBrand)brand;
+ (nullable UIImage *)pstck_safeImageNamed:(nonnull NSString *)imageName;

@end

void linkUIImageCategoryPaystack(void);
