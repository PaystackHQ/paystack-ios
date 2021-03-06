//
//  PSTCKCreditCardTextFieldTest.m
//  Paystack
//

@import XCTest;

#import "Paystack.h"
#import "PSTCKPaymentCardTextFieldViewModel.h"

@interface PSTCKPaymentCardTextFieldViewModelTest : XCTestCase
@property(nonatomic)PSTCKPaymentCardTextFieldViewModel *viewModel;
@end

@implementation PSTCKPaymentCardTextFieldViewModelTest

- (void)setUp {
    [super setUp];
    _viewModel = [PSTCKPaymentCardTextFieldViewModel new];
}

- (void)testCardNumber {
    NSArray *tests = @[
                       @[@"", @""],
                       @[@"4242", @"4242"],
                       @[@"4242424242424242", @"4242424242424242"],
                       @[@"4242 4242 4242 4242", @"4242424242424242"],
                       @[@"4242xxx4242", @"42424242"],
                       @[@"12345678901234567890", @"12345678901234567890"],
                       ];
    for (NSArray *test in tests) {
        self.viewModel.cardNumber = test[0];
        XCTAssertEqualObjects(self.viewModel.cardNumber, test[1]);
    }
}

- (void)testRawExpiration {
    NSArray *tests = @[
                       @[@"", @"", @"", @"", @(PSTCKCardValidationStateIncomplete)],
                       @[@"12/23", @"12/23", @"12", @"23", @(PSTCKCardValidationStateValid)],
                       @[@"1223", @"12/23", @"12", @"23", @(PSTCKCardValidationStateValid)],
                       @[@"1", @"1", @"1", @"", @(PSTCKCardValidationStateIncomplete)],
                       @[@"2", @"02/", @"02", @"", @(PSTCKCardValidationStateIncomplete)],
                       @[@"12", @"12/", @"12", @"", @(PSTCKCardValidationStateIncomplete)],
                       @[@"12/2", @"12/2", @"12", @"2", @(PSTCKCardValidationStateIncomplete)],
                       @[@"99/23", @"99", @"99", @"23", @(PSTCKCardValidationStateInvalid)],
                       @[@"10/12", @"10/12", @"10", @"12", @(PSTCKCardValidationStateInvalid)],
                       @[@"12*23", @"12/23", @"12", @"23", @(PSTCKCardValidationStateValid)],
                       @[@"12/*", @"12/", @"12", @"", @(PSTCKCardValidationStateIncomplete)],
                       @[@"*", @"", @"", @"", @(PSTCKCardValidationStateIncomplete)],
                       ];
    for (NSArray *test in tests) {
        self.viewModel.rawExpiration = test[0];
        XCTAssertEqualObjects(self.viewModel.rawExpiration, test[1]);
        XCTAssertEqualObjects(self.viewModel.expirationMonth, test[2]);
        XCTAssertEqualObjects(self.viewModel.expirationYear, test[3]);
        XCTAssertEqualObjects(@([self.viewModel validationStateForField:PSTCKCardFieldTypeExpiration]), test[4]);
    }
}

- (void)testCVC {
    NSArray *tests = @[
                       @[@"1", @"1"],
                       @[@"1234", @"1234"],
                       @[@"12345", @"1234"],
                       @[@"1x", @"1"],
                       ];
    for (NSArray *test in tests) {
        self.viewModel.cvc = test[0];
        XCTAssertEqualObjects(self.viewModel.cvc, test[1]);
    }
}

- (void)testNumberWithoutLastDigits {
    self.viewModel.cardNumber = @"4242424242424242";
    XCTAssertEqualObjects([self.viewModel numberWithoutLastDigits], @"424242424242");
    
    self.viewModel.cardNumber = @"378282246310005";
    XCTAssertEqualObjects([self.viewModel numberWithoutLastDigits], @"37828224631");
    
    self.viewModel.cardNumber = @"";
    XCTAssertEqualObjects([self.viewModel numberWithoutLastDigits], @"1234 5678 1234 5678");
}

- (void)testValidity {
    self.viewModel.cardNumber = @"4242424242424242";
    self.viewModel.rawExpiration = @"12/24";
    self.viewModel.cvc = @"123";
    XCTAssertTrue([self.viewModel isValid]);
    
    self.viewModel.cvc = @"12";
    XCTAssertFalse([self.viewModel isValid]);
}

@end
