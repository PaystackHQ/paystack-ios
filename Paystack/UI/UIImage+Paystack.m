//
//  UIImage+Paystack.m
//  Paystack
//

#import "UIImage+Paystack.h"

#define FAUXPAS_IGNORED_IN_METHOD(...)

// Dummy class for locating the framework bundle
@interface PSTCKBundleLocator : NSObject
@end
@implementation PSTCKBundleLocator
@end

@implementation UIImage (Paystack)

+ (UIImage *)pstck_amexCardImage {
    return [UIImage pstck_brandImageForCardBrand:PSTCKCardBrandAmex];
}

+ (UIImage *)pstck_dinersClubCardImage {
    return [UIImage pstck_brandImageForCardBrand:PSTCKCardBrandDinersClub];
}

+ (UIImage *)pstck_discoverCardImage {
    return [UIImage pstck_brandImageForCardBrand:PSTCKCardBrandDiscover];
}

+ (UIImage *)pstck_jcbCardImage {
    return [UIImage pstck_brandImageForCardBrand:PSTCKCardBrandJCB];
}

+ (UIImage *)pstck_masterCardCardImage {
    return [UIImage pstck_brandImageForCardBrand:PSTCKCardBrandMasterCard];
}

+ (UIImage *)pstck_visaCardImage {
    return [UIImage pstck_brandImageForCardBrand:PSTCKCardBrandVisa];
}

+ (UIImage *)pstck_unknownCardCardImage {
    return [UIImage pstck_brandImageForCardBrand:PSTCKCardBrandUnknown];
}

+ (UIImage *)pstck_brandImageForCardBrand:(PSTCKCardBrand)brand {
    FAUXPAS_IGNORED_IN_METHOD(APIAvailability);
    NSString *imageName;
    BOOL templateSupported = [[UIImage new] respondsToSelector:@selector(imageWithRenderingMode:)];
    switch (brand) {
        case PSTCKCardBrandAmex:
            imageName = @"pstck_card_amex";
            break;
        case PSTCKCardBrandDinersClub:
            imageName = @"pstck_card_diners";
            break;
        case PSTCKCardBrandDiscover:
            imageName = @"pstck_card_discover";
            break;
        case PSTCKCardBrandJCB:
            imageName = @"pstck_card_jcb";
            break;
        case PSTCKCardBrandMasterCard:
            imageName = @"pstck_card_mastercard";
            break;
        case PSTCKCardBrandVerve:
            imageName = @"pstck_card_verve";
            break;
        case PSTCKCardBrandUnknown:
            imageName = templateSupported ? @"pstck_card_placeholder_template" : @"pstck_card_placeholder";
            break;
        case PSTCKCardBrandVisa:
            imageName = @"pstck_card_visa";
    }
    UIImage *image = [UIImage pstck_safeImageNamed:imageName];
    if (brand == PSTCKCardBrandUnknown && templateSupported) {
        image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    return image;
}

+ (UIImage *)pstck_cvcImageForCardBrand:(PSTCKCardBrand)brand {
    NSString *imageName = brand == PSTCKCardBrandAmex ? @"pstck_card_cvc_amex" : @"pstck_card_cvc";
    return [UIImage pstck_safeImageNamed:imageName];
}

+ (UIImage *)pstck_safeImageNamed:(NSString *)imageName {
    if ([[UIImage class] respondsToSelector:@selector(imageNamed:inBundle:compatibleWithTraitCollection:)]) {
        return [UIImage imageNamed:imageName inBundle:[NSBundle bundleForClass:[PSTCKBundleLocator class]] compatibleWithTraitCollection:nil];
    }
    return [UIImage imageNamed:imageName];
}

@end

void linkUIImageCategoryPaystack(void){}
