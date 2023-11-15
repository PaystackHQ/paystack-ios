//
//  PSTCKPaymentCardTextField.m
//  Paystack
//

#import <UIKit/UIKit.h>

#import "Paystack.h"
#import "PSTCKPaymentCardTextField.h"
#import "PSTCKPaymentCardTextFieldViewModel.h"
#import "PSTCKFormTextField.h"
#import "PSTCKCardValidator.h"
#import "UIImage+Paystack.h"

#define FAUXPAS_IGNORED_IN_METHOD(...)
__deprecated
@interface PSTCKPaymentCardTextField()<PSTCKFormTextFieldDelegate>

@property(nonatomic, readwrite, strong)PSTCKFormTextField *sizingField;

@property(nonatomic, readwrite, weak)UIImageView *brandImageView;
@property(nonatomic, readwrite, weak)UIView *fieldsView;

@property(nonatomic, readwrite, weak)PSTCKFormTextField *numberField;

@property(nonatomic, readwrite, weak)PSTCKFormTextField *expirationField;

@property(nonatomic, readwrite, weak)UIButton *bumpToExpField;


@property(nonatomic, readwrite, weak)PSTCKFormTextField *cvcField;

@property(nonatomic, readwrite, strong)PSTCKPaymentCardTextFieldViewModel *viewModel;

@property(nonatomic, readwrite, weak)UITextField *selectedField;

@property(nonatomic, assign)BOOL numberFieldShrunk;
@property(nonatomic, assign)BOOL bumped;

@end

@implementation PSTCKPaymentCardTextField

@synthesize font = _font;
@synthesize textColor = _textColor;
@synthesize textErrorColor = _textErrorColor;
@synthesize placeholderColor = _placeholderColor;
@dynamic enabled;

CGFloat const PSTCKPaymentCardTextFieldDefaultPadding = 10;

#if CGFLOAT_IS_DOUBLE
#define pstck_roundCGFloat(x) round(x)
#else
#define pstck_roundCGFloat(x) roundf(x)
#endif

#pragma mark initializers

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    
    self.borderColor = [self.class placeholderGrayColor];
    self.cornerRadius = 5.0f;
    self.borderWidth = 1.0f;

    self.clipsToBounds = YES;
    
    _viewModel = [PSTCKPaymentCardTextFieldViewModel new];
    _sizingField = [self buildTextField];
    
    UIImageView *brandImageView = [[UIImageView alloc] initWithImage:self.brandImage];
    brandImageView.contentMode = UIViewContentModeCenter;
    brandImageView.backgroundColor = [UIColor clearColor];
    if ([brandImageView respondsToSelector:@selector(setTintColor:)]) {
        brandImageView.tintColor = self.placeholderColor;
    }
    self.brandImageView = brandImageView;
    
    PSTCKFormTextField *numberField = [self buildTextField];
    numberField.formatsCardNumbers = YES;
    numberField.tag = PSTCKCardFieldTypeNumber;
    self.numberField = numberField;
    self.numberPlaceholder = [self.viewModel defaultPlaceholder];

    PSTCKFormTextField *expirationField = [self buildTextField];
    expirationField.tag = PSTCKCardFieldTypeExpiration;
    expirationField.alpha = 0;
    self.expirationField = expirationField;
    self.expirationPlaceholder = @"MM/YY";
    
    UIButton *bumpToExpField = [UIButton buttonWithType:UIButtonTypeCustom];
    [bumpToExpField addTarget:self action:@selector(tappedBumpButton:) forControlEvents:UIControlEventTouchUpInside];
    [bumpToExpField setTitle: @">" forState: UIControlStateNormal];
    [bumpToExpField setTitleColor:self.textColor forState:UIControlStateNormal];
    bumpToExpField.hidden = YES;
    self.bumpToExpField.alpha = 50;
    self.bumpToExpField = bumpToExpField;
    self.bumped = NO;
    
    PSTCKFormTextField *cvcField = [self buildTextField];
    cvcField.tag = PSTCKCardFieldTypeCVC;
    cvcField.alpha = 0;
    self.cvcField = cvcField;
    self.cvcPlaceholder = @"CVC";
    
    UIView *fieldsView = [[UIView alloc] init];
    fieldsView.clipsToBounds = YES;
    fieldsView.backgroundColor = [UIColor clearColor];
    self.fieldsView = fieldsView;
    
    [self addSubview:self.fieldsView];
    [self.fieldsView addSubview:cvcField];
    [self.fieldsView addSubview:expirationField];
    [self.fieldsView addSubview:numberField];
    [self addSubview:brandImageView];
    [self addSubview:bumpToExpField];
}

- (void)tappedBumpButton:(id)bumpButton {
#pragma unused(bumpButton)
    self.bumped = YES;
    self.bumpToExpField.hidden = YES;
    if([self.viewModel validationStateForField:PSTCKCardFieldTypeNumber]==PSTCKCardValidationStateValid){
        [self selectNextField];
    }
}

- (PSTCKPaymentCardTextFieldViewModel *)viewModel {
    if (_viewModel == nil) {
        _viewModel = [PSTCKPaymentCardTextFieldViewModel new];
    }
    return _viewModel;
}

#pragma mark appearance properties

+ (UIColor *)placeholderGrayColor {
    return [UIColor lightGrayColor];
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    [super setBackgroundColor:[backgroundColor copy]];
    self.numberField.backgroundColor = self.backgroundColor;
}

- (UIColor *)backgroundColor {
    return [super backgroundColor] ?: [UIColor whiteColor];
}

- (void)setFont:(UIFont *)font {
    _font = [font copy];
    
    for (UITextField *field in [self allFields]) {
        field.font = _font;
    }
    
    self.sizingField.font = _font;
    
    [self setNeedsLayout];
}

- (UIFont *)font {
    return _font ?: [UIFont systemFontOfSize:18];
}

- (void)setTextColor:(UIColor *)textColor {
    _textColor = [textColor copy];
    
    for (PSTCKFormTextField *field in [self allFields]) {
        field.defaultColor = _textColor;
    }
}

- (void)setContentVerticalAlignment:(UIControlContentVerticalAlignment)contentVerticalAlignment {
    [super setContentVerticalAlignment:contentVerticalAlignment];
    for (UITextField *field in [self allFields]) {
        field.contentVerticalAlignment = contentVerticalAlignment;
    }
    switch (contentVerticalAlignment) {
        case UIControlContentVerticalAlignmentCenter:
            self.brandImageView.contentMode = UIViewContentModeCenter;
            break;
        case UIControlContentVerticalAlignmentBottom:
            self.brandImageView.contentMode = UIViewContentModeBottom;
            break;
        case UIControlContentVerticalAlignmentFill:
            self.brandImageView.contentMode = UIViewContentModeTop;
            break;
        case UIControlContentVerticalAlignmentTop:
            self.brandImageView.contentMode = UIViewContentModeTop;
            break;
    }
}

- (UIColor *)textColor {
    return _textColor ?: [UIColor blackColor];
}

- (void)setTextErrorColor:(UIColor *)textErrorColor {
    _textErrorColor = [textErrorColor copy];
    
    for (PSTCKFormTextField *field in [self allFields]) {
        field.errorColor = _textErrorColor;
    }
}

- (UIColor *)textErrorColor {
    return _textErrorColor ?: [UIColor redColor];
}

- (void)setPlaceholderColor:(UIColor *)placeholderColor {
    _placeholderColor = [placeholderColor copy];
    
    if ([self.brandImageView respondsToSelector:@selector(setTintColor:)]) {
        self.brandImageView.tintColor = placeholderColor;
    }
    
    for (PSTCKFormTextField *field in [self allFields]) {
        field.placeholderColor = _placeholderColor;
    }
}

- (UIColor *)placeholderColor {
    return _placeholderColor ?: [self.class placeholderGrayColor];
}

- (void)setNumberPlaceholder:(NSString * __nullable)numberPlaceholder {
    _numberPlaceholder = [numberPlaceholder copy];
    self.numberField.placeholder = _numberPlaceholder;
}

- (void)setExpirationPlaceholder:(NSString * __nullable)expirationPlaceholder {
    _expirationPlaceholder = [expirationPlaceholder copy];
    self.expirationField.placeholder = _expirationPlaceholder;
}

- (void)setCvcPlaceholder:(NSString * __nullable)cvcPlaceholder {
    _cvcPlaceholder = [cvcPlaceholder copy];
    self.cvcField.placeholder = _cvcPlaceholder;
}

- (void)setCursorColor:(UIColor *)cursorColor {
    self.tintColor = cursorColor;
}

- (UIColor *)cursorColor {
    return self.tintColor;
}

- (void)setBorderColor:(UIColor * __nullable)borderColor {
    self.layer.borderColor = [[borderColor copy] CGColor];
}

- (UIColor * __nullable)borderColor {
    return [[UIColor alloc] initWithCGColor:self.layer.borderColor];
}

- (void)setCornerRadius:(CGFloat)cornerRadius {
    self.layer.cornerRadius = cornerRadius;
}

- (CGFloat)cornerRadius {
    return self.layer.cornerRadius;
}

- (void)setBorderWidth:(CGFloat)borderWidth {
    self.layer.borderWidth = borderWidth;
}

- (CGFloat)borderWidth {
    return self.layer.borderWidth;
}

- (void)setKeyboardAppearance:(UIKeyboardAppearance)keyboardAppearance {
    _keyboardAppearance = keyboardAppearance;
    for (PSTCKFormTextField *field in [self allFields]) {
        field.keyboardAppearance = keyboardAppearance;
    }
}

- (void)setInputAccessoryView:(UIView *)inputAccessoryView {
    _inputAccessoryView = inputAccessoryView;
    
    for (PSTCKFormTextField *field in [self allFields]) {
        field.inputAccessoryView = inputAccessoryView;
    }
}

#pragma mark UIControl

- (void)setEnabled:(BOOL)enabled {
    [super setEnabled:enabled];
    for (PSTCKFormTextField *textField in [self allFields]) {
        textField.enabled = enabled;
    };
}

#pragma mark UIResponder & related methods

- (BOOL)isFirstResponder {
    return [self.selectedField isFirstResponder];
}

- (BOOL)canBecomeFirstResponder {
    return [[self firstResponderField] canBecomeFirstResponder];
}

- (BOOL)becomeFirstResponder {
    return [[self firstResponderField] becomeFirstResponder];
}

- (PSTCKFormTextField *)firstResponderField {

    if ([self.viewModel validationStateForField:PSTCKCardFieldTypeNumber] != PSTCKCardValidationStateValid) {
        return self.numberField;
    } else if ([self.viewModel validationStateForField:PSTCKCardFieldTypeExpiration] != PSTCKCardValidationStateValid) {
        return self.expirationField;
    } else {
        return self.cvcField;
    }
}

- (BOOL)canResignFirstResponder {
    return [self.selectedField canResignFirstResponder];
}

- (BOOL)resignFirstResponder {
    [super resignFirstResponder];
    BOOL success = [self.selectedField resignFirstResponder];
    [self setNumberFieldShrunk:[self shouldShrinkNumberField] animated:YES completion:nil];
    return success;
}

- (BOOL)selectNextField {
    return [[self nextField] becomeFirstResponder];
}

- (BOOL)selectPreviousField {
    return [[self previousField] becomeFirstResponder];
}

- (PSTCKFormTextField *)nextField {
    if (self.selectedField == self.numberField) {
        Boolean stay = NO;
        if(self.viewModel.brand==PSTCKCardBrandVerve){
            stay = (self.numberField.text.length < 19);
            if(stay){
                stay = !self.bumped;
            }
        }
        self.bumpToExpField.hidden = !stay;
        self.bumped = NO;
        if(stay){
            return self.numberField;
        }
        if ([self.viewModel validationStateForField:self.expirationField.tag] == PSTCKCardValidationStateValid) {
            return self.cvcField;
        }
        return self.expirationField;
    } else if (self.selectedField == self.expirationField) {
        return self.cvcField;
    }
    return nil;
}

- (PSTCKFormTextField *)previousField {
    if (self.selectedField == self.cvcField) {
        return self.expirationField;
    } else if (self.selectedField == self.expirationField) {
        return self.numberField;
    }
    return nil;
}

#pragma mark public convenience methods

- (void)clear {
    for (PSTCKFormTextField *field in [self allFields]) {
        field.text = @"";
    }
    self.viewModel = [PSTCKPaymentCardTextFieldViewModel new];
    [self onChange];
    [self updateImageForFieldType:PSTCKCardFieldTypeNumber];
    __weak id weakself = self;
    [self setNumberFieldShrunk:NO animated:YES completion:^(__unused BOOL completed){
        __strong id strongself = weakself;
        if ([strongself isFirstResponder]) {
            [[strongself numberField] becomeFirstResponder];
        }
    }];
}

- (BOOL)isValid {
    return [self.viewModel isValid];
}

#pragma mark readonly variables

- (NSString *)cardNumber {
    return self.viewModel.cardNumber;
}

- (NSUInteger)expirationMonth {
    return [self.viewModel.expirationMonth integerValue];
}

- (NSUInteger)expirationYear {
    return [self.viewModel.expirationYear integerValue];
}

- (NSString *)cvc {
    return self.viewModel.cvc;
}

- (PSTCKCardParams *)cardParams {
    PSTCKCardParams *c = [[PSTCKCardParams alloc] init];
    c.number = self.cardNumber;
    c.expMonth = self.expirationMonth;
    c.expYear = self.expirationYear;
    c.cvc = self.cvc;
    return c;
}

- (void)setCardParams:(PSTCKCardParams *)cardParams {
    [self setText:cardParams.number inField:PSTCKCardFieldTypeNumber];
    BOOL expirationPresent = cardParams.expMonth && cardParams.expYear;
    if (expirationPresent) {
        NSString *text = [NSString stringWithFormat:@"%02lu%02lu",
                          (unsigned long)cardParams.expMonth,
                          (unsigned long)cardParams.expYear%100];
        [self setText:text inField:PSTCKCardFieldTypeExpiration];
    }
    else {
        [self setText:@"" inField:PSTCKCardFieldTypeExpiration];
    }
    [self setText:cardParams.cvc inField:PSTCKCardFieldTypeCVC];
    
    BOOL shrinkNumberField = [self shouldShrinkNumberField];
    [self setNumberFieldShrunk:shrinkNumberField animated:NO completion:nil];
    
    // update the card image, falling back to the number field image if not editing
    if ([self.expirationField isFirstResponder]) {
        [self updateImageForFieldType:PSTCKCardFieldTypeExpiration];
    }
    else if ([self.cvcField isFirstResponder]) {
        [self updateImageForFieldType:PSTCKCardFieldTypeCVC];
    }
    else {
        [self updateImageForFieldType:PSTCKCardFieldTypeNumber];
    }
}

- (PSTCKCardParams *)card {
    if (!self.isValid) { return nil; }
    return self.cardParams;
}

- (void)setCard:(PSTCKCardParams *)card {
    [self setCardParams:card];
}

- (void)setText:(NSString *)text inField:(PSTCKCardFieldType)field {
    NSString *nonNilText = text == nil ? @"" : text;
    PSTCKFormTextField *textField = nil;
    switch (field) {
        case PSTCKCardFieldTypeNumber:
            textField = self.numberField;
            break;
        case PSTCKCardFieldTypeExpiration:
            textField = self.expirationField;
            break;
        case PSTCKCardFieldTypeCVC:
            textField = self.cvcField;
            break;
    }
    self.selectedField = (self.isFirstResponder) ? textField : nil;
    id delegate = (id<UITextFieldDelegate>)self;
    NSRange range = NSMakeRange(0, textField.text.length);
    [delegate textField:textField shouldChangeCharactersInRange:range
      replacementString:nonNilText];
}

- (CGSize)intrinsicContentSize {
    
    CGSize imageSize = self.brandImage.size;
    
    self.sizingField.text = self.viewModel.defaultPlaceholder;
    CGFloat textHeight = [self.sizingField measureTextSize].height;
    CGFloat imageHeight = imageSize.height + (PSTCKPaymentCardTextFieldDefaultPadding * 2);
    CGFloat height = pstck_roundCGFloat((MAX(MAX(imageHeight, textHeight), 44)));
    
    CGFloat width = pstck_roundCGFloat([self widthForCardNumber:self.viewModel.defaultPlaceholder] + imageSize.width + (PSTCKPaymentCardTextFieldDefaultPadding * 3));
    
    return CGSizeMake(width, height);
}

- (CGRect)brandImageRectForBounds:(CGRect)bounds {
    return CGRectMake(PSTCKPaymentCardTextFieldDefaultPadding, 2, self.brandImageView.image.size.width, bounds.size.height - 2);
}

- (CGRect)bumpRectForBounds:(CGRect)bounds {
    return CGRectMake(CGRectGetWidth(bounds) - [self widthForText:@"  >  "] - (PSTCKPaymentCardTextFieldDefaultPadding / 2)  , 2, [self widthForText:@"  >  "], bounds.size.height - 2);
}

- (CGRect)fieldsRectForBounds:(CGRect)bounds {
    CGRect brandImageRect = [self brandImageRectForBounds:bounds];
    return CGRectMake(CGRectGetMaxX(brandImageRect), 0, CGRectGetWidth(bounds) - CGRectGetMaxX(brandImageRect), CGRectGetHeight(bounds));
}

- (CGRect)numberFieldRectForBounds:(CGRect)bounds {
    CGFloat placeholderWidth = [self widthForCardNumber:self.numberField.placeholder] - 4;
    CGFloat numberWidth = [self widthForCardNumber:self.viewModel.defaultPlaceholder] - 4;
    CGFloat numberFieldWidth = MAX(placeholderWidth, numberWidth);
    CGFloat nonFragmentWidth = [self widthForCardNumber:[self.viewModel numberWithoutLastDigits]] - 13;
    CGFloat numberFieldX = self.numberFieldShrunk ? PSTCKPaymentCardTextFieldDefaultPadding - nonFragmentWidth : 8;
    return CGRectMake(numberFieldX, 0, numberFieldWidth, CGRectGetHeight(bounds));
}

- (CGRect)cvcFieldRectForBounds:(CGRect)bounds {
    CGRect fieldsRect = [self fieldsRectForBounds:bounds];

    CGFloat cvcWidth = MAX([self widthForText:self.cvcField.placeholder], [self widthForText:@"8888"]);
    CGFloat cvcX = self.numberFieldShrunk ?
    CGRectGetWidth(fieldsRect) - cvcWidth - PSTCKPaymentCardTextFieldDefaultPadding / 2  :
    CGRectGetWidth(fieldsRect);
    return CGRectMake(cvcX, 0, cvcWidth, CGRectGetHeight(bounds));
}

- (CGRect)expirationFieldRectForBounds:(CGRect)bounds {
    CGRect numberFieldRect = [self numberFieldRectForBounds:bounds];
    CGRect cvcRect = [self cvcFieldRectForBounds:bounds];

    CGFloat expirationWidth = MAX([self widthForText:self.expirationField.placeholder], [self widthForText:@"88/88"]);
    CGFloat expirationX = (CGRectGetMaxX(numberFieldRect) + CGRectGetMinX(cvcRect) - expirationWidth) / 2;
    return CGRectMake(expirationX, 0, expirationWidth, CGRectGetHeight(bounds));
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGRect bounds = self.bounds;

    self.bumpToExpField.frame = [self bumpRectForBounds:bounds];
    self.brandImageView.frame = [self brandImageRectForBounds:bounds];
    self.fieldsView.frame = [self fieldsRectForBounds:bounds];
    self.numberField.frame = [self numberFieldRectForBounds:bounds];
    self.cvcField.frame = [self cvcFieldRectForBounds:bounds];
    self.expirationField.frame = [self expirationFieldRectForBounds:bounds];
    
}

#pragma mark - private helper methods

- (PSTCKFormTextField *)buildTextField {
    PSTCKFormTextField *textField = [[PSTCKFormTextField alloc] initWithFrame:CGRectZero];
    textField.backgroundColor = [UIColor clearColor];
    textField.keyboardType = UIKeyboardTypeNumberPad;
    textField.font = self.font;
    textField.defaultColor = self.textColor;
    textField.errorColor = self.textErrorColor;
    textField.placeholderColor = self.placeholderColor;
    textField.formDelegate = self;
    return textField;
}

- (NSArray *)allFields {
    return @[self.numberField, self.expirationField, self.cvcField];
}

typedef void (^PSTCKNumberShrunkCompletionBlock)(BOOL completed);
- (void)setNumberFieldShrunk:(BOOL)shrunk animated:(BOOL)animated
                  completion:(PSTCKNumberShrunkCompletionBlock)completion {
    
    if (_numberFieldShrunk == shrunk) {
        if (completion) {
            completion(YES);
        }
        return;
    }
    
    _numberFieldShrunk = shrunk;
    void (^animations)(void) = ^void() {
        for (UIView *view in @[self.expirationField, self.cvcField]) {
            view.alpha = 1.0f * shrunk;
        }
        [self layoutSubviews];
    };
    
    FAUXPAS_IGNORED_IN_METHOD(APIAvailability);
    NSTimeInterval duration = animated * 0.3;
    if ([UIView respondsToSelector:@selector(animateWithDuration:delay:usingSpringWithDamping:initialSpringVelocity:options:animations:completion:)]) {
        [UIView animateWithDuration:duration
                              delay:0
             usingSpringWithDamping:0.85f
              initialSpringVelocity:0
                            options:0
                         animations:animations
                         completion:completion];
    } else {
        [UIView animateWithDuration:duration
                         animations:animations
                         completion:completion];
    }
}

- (BOOL)shouldShrinkNumberField {
    return [self.viewModel validationStateForField:PSTCKCardFieldTypeNumber] == PSTCKCardValidationStateValid;
}

- (CGFloat)widthForText:(NSString *)text {
    self.sizingField.formatsCardNumbers = NO;
    [self.sizingField setText:text];
    return [self.sizingField measureTextSize].width + 8;
}

- (CGFloat)widthForTextWithLength:(NSUInteger)length {
    NSString *text = [@"" stringByPaddingToLength:length withString:@"M" startingAtIndex:0];
    return [self widthForText:text];
}

- (CGFloat)widthForCardNumber:(NSString *)cardNumber {
    self.sizingField.formatsCardNumbers = YES;
    [self.sizingField setText:cardNumber];
    return [self.sizingField measureTextSize].width + 20;
}

#pragma mark PSTCKPaymentTextFieldDelegate

- (void)formTextFieldDidBackspaceOnEmpty:(__unused PSTCKFormTextField *)formTextField {
    PSTCKFormTextField *previous = [self previousField];
    [previous becomeFirstResponder];
    [previous deleteBackward];
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    self.selectedField = (PSTCKFormTextField *)textField;
    switch ((PSTCKCardFieldType)textField.tag) {
        case PSTCKCardFieldTypeNumber:
            [self setNumberFieldShrunk:NO animated:YES completion:nil];
            if ([self.delegate respondsToSelector:@selector(paymentCardTextFieldDidBeginEditingNumber:)]) {
                [self.delegate paymentCardTextFieldDidBeginEditingNumber:self];
            }
            break;
        case PSTCKCardFieldTypeCVC:
            [self setNumberFieldShrunk:YES animated:YES completion:nil];
            if ([self.delegate respondsToSelector:@selector(paymentCardTextFieldDidBeginEditingCVC:)]) {
                [self.delegate paymentCardTextFieldDidBeginEditingCVC:self];
            }
            break;
        case PSTCKCardFieldTypeExpiration:
            [self setNumberFieldShrunk:YES animated:YES completion:nil];
            if ([self.delegate respondsToSelector:@selector(paymentCardTextFieldDidBeginEditingExpiration:)]) {
                [self.delegate paymentCardTextFieldDidBeginEditingExpiration:self];
            }
            break;
    }
    [self updateImageForFieldType:textField.tag];
}

- (void)textFieldDidEndEditing:(__unused UITextField *)textField {
    self.selectedField = nil;
}

- (BOOL)textField:(PSTCKFormTextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {

    BOOL deletingLastCharacter = (range.location == textField.text.length - 1 && range.length == 1 && [string isEqualToString:@""]);
    if (deletingLastCharacter && [textField.text hasSuffix:@"/"] && range.location > 0) {
        range.location -= 1;
        range.length += 1;
    }
    
    NSString *newText = [textField.text stringByReplacingCharactersInRange:range withString:string];
    PSTCKCardFieldType fieldType = textField.tag;
    switch (fieldType) {
        case PSTCKCardFieldTypeNumber:
            self.viewModel.cardNumber = newText;
            textField.text = self.viewModel.cardNumber;
            break;
        case PSTCKCardFieldTypeExpiration: {
            self.viewModel.rawExpiration = newText;
            textField.text = self.viewModel.rawExpiration;
            break;
        }
        case PSTCKCardFieldTypeCVC:
            self.viewModel.cvc = newText;
            textField.text = self.viewModel.cvc;
            break;
    }
    
    [self updateImageForFieldType:fieldType];

    PSTCKCardValidationState state = [self.viewModel validationStateForField:fieldType];
    textField.validText = YES;
    switch (state) {
        case PSTCKCardValidationStateInvalid:
            textField.validText = NO;
            break;
        case PSTCKCardValidationStateIncomplete:
            break;
        case PSTCKCardValidationStateValid: {
            [self selectNextField];
            break;
        }
    }
    [self onChange];

    return NO;
}

- (UIImage *)brandImage {
    if (self.selectedField) {
        return [self brandImageForFieldType:self.selectedField.tag];
    } else {
        return [self brandImageForFieldType:PSTCKCardFieldTypeNumber];
    }
}

+ (UIImage *)cvcImageForCardBrand:(PSTCKCardBrand)cardBrand {
    return [UIImage pstck_cvcImageForCardBrand:cardBrand];
}

+ (UIImage *)brandImageForCardBrand:(PSTCKCardBrand)cardBrand {
    return [UIImage pstck_brandImageForCardBrand:cardBrand];
}

- (UIImage *)brandImageForFieldType:(PSTCKCardFieldType)fieldType {
    if (fieldType == PSTCKCardFieldTypeCVC) {
        return [self.class cvcImageForCardBrand:self.viewModel.brand];
    }

    return [self.class brandImageForCardBrand:self.viewModel.brand];
}

- (void)updateImageForFieldType:(PSTCKCardFieldType)fieldType {
    UIImage *image = [self brandImageForFieldType:fieldType];
    if (image != self.brandImageView.image) {
        self.brandImageView.image = image;
        
        CATransition *transition = [CATransition animation];
        transition.duration = 0.2f;
        transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        transition.type = kCATransitionFade;
        
        [self.brandImageView.layer addAnimation:transition forKey:nil];

        [self setNeedsLayout];
    }
}

- (void)onChange {
    if ([self.delegate respondsToSelector:@selector(paymentCardTextFieldDidChange:)]) {
        [self.delegate paymentCardTextFieldDidChange:self];
    }
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}

@end

