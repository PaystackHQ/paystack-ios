# Guide

If you want to build mobile apps like [Taxify](http://www.taxify.eu), [Afro](http://www.getafrocab.com), [Okada Books](https://www.okadabooks.com) and enable people to make purchases directly in your app, our iOS and [Android](https://github.com/PaystackHQ/paystack-android) libraries can help.

Accepting payments in your app after collecting card information can be achieved by charging the card with our SDK. Reusable `authorization code`s from such transaction from can be used from your backend to charge the cards directly.

## Summarized flow

Once it's time to pay, and the user has provided card details on your app,

#### OPTION 1: Backend starts transaction (recommended)

a. App prompts backend to initialize a transaction, backend returns `access_code`.

b. Provide `access_code` and card details to our SDK's `chargeCard` function.

#### OPTION 2: App starts transaction

a. Provide transaction parameters and card params to our SDK's `chargeCard` function.

#### SDK will prompt user for PIN, OTP or Bank authentication as required

#### Once successful, we will send event to your webhook url and call the didTransactionSuccess callback


## Getting Started

### Step 0: Add Keychain Sharing entitlements to your app

### Step 1: Install the library

#### Manual installation

We publish our SDK as a static framework that you can copy directly into your app without any additional tools:

- Head to our [releases page](https://github.com/PaystackHQ/paystack-ios/releases/) and download the framework that's right for you.
- Unzip the file you downloaded.
- In Xcode, with your project open, click on 'File' then 'Add files to "Project"...'.
- Select Paystack.framework in the directory you just unzipped.
- Make sure 'Copy items if needed' is checked.
- Click 'Add'.
- In your project settings, go to the "Build Settings" tab, and make sure -ObjC is present under "Other Linker Flags".

#### Using [CocoaPods](https://cocoapods.org/)

We recommend using [CocoaPods](https://cocoapods.org/) to install the Paystack iOS library, since it makes it easy to keep your app's dependencies up to date.

If you haven't set up Cocoapods before, their site has installation instructions. Then, add 
```
pod 'Paystack' 
```
to your Podfile, and run pod install.

(Don't forget to use the .xcworkspace file to open your project in Xcode, instead of the .xcodeproj file, from here on out.)

#### Using Carthage

We also support installing our SDK using Carthage. You can simply add github "paystackhq/paystack-ios" to your Cartfile, and follow the Carthage installation instructions.

### Step 2: Configure API keys

First, you'll want to configure Paystack with your public API key. We recommend doing this in your `AppDelegate`'s `application:didFinishLaunchingWithOptions:` method so that it will be set for the entire lifecycle of your app.

```Swift
// AppDelegate.swift

import Paystack

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        Paystack.setDefaultPublicKey("pk_test_xxxx")
        return true
    }
}
```

```Objective-C
// AppDelegate.m

#import "AppDelegate.h"
#import <Paystack/Paystack.h>

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [Paystack setDefaultPublicKey:@"pk_test_xxxxx"];
    return YES;
}

@end
```

We've placed a test public API key as the PaystackPublicKey constant in the above snippet. You'll need to swap it out with your live public key in production. You can see all your API keys in your dashboard.

### Step 3: Collecting credit card information

#### Test Mode

When you're using your test public key, our libraries give you the ability to test your payment flow without having to charge real credit cards.

If you're building your own form or using `PSTCKPaymentCardTextField`, using any of:

1. card number `4084084084084081` with CVC `408` (along with any future expiration date); or;
2. card number `5060666666666666666` with CVC `123` and any future expiration date, PIN `1234`, OTP `123456`

will accomplish the same effect.

At some point in the flow of your app, you'll want to obtain payment details from the user. There are two ways to do this. You can (in increasing order of complexity):

- Use our pre-built form component, `PSTCKPaymentCardTextField`, to collect new credit card details
- Build your own credit card form from scratch

#### Using PSTCKPaymentCardTextField

To use our pre-built form component, we'll create a view controller called `PaymentViewController` and add a `PSTCKPaymentCardTextField` property to the view controller.

```Swift
// PaymentViewController.swift

class PaymentViewController: UIViewController, PSTCKPaymentCardTextFieldDelegate {
    let paymentTextField = PSTCKPaymentCardTextField()
}
```

```Objective-C
// PaymentViewController.m

#import "PaymentViewController.h"

@interface PaymentViewController ()<PSTCKPaymentCardTextFieldDelegate>
@property(nonatomic) PSTCKPaymentCardTextField *paymentTextField;
@end
```

Next, let's instantiate the `PSTCKPaymentCardTextField`, set the `PaymentViewController` as its `PSTCKPaymentCardTextFieldDelegate`, and add it to our view.

```Swift
// PaymentViewController.swift

override func viewDidLoad() {
    super.viewDidLoad();
    paymentTextField.frame = CGRectMake(15, 15, CGRectGetWidth(self.view.frame) - 30, 44)
    paymentTextField.delegate = self
    view.addSubview(paymentTextField)
}
```

```Objective-C
// PaymentViewController.m

- (void)viewDidLoad {
    [super viewDidLoad];
    self.paymentTextField = [[PSTCKPaymentCardTextField alloc] initWithFrame:CGRectMake(15, 15, CGRectGetWidth(self.view.frame) - 30, 44)];
    self.paymentTextField.delegate = self;
    [self.view addSubview:self.paymentTextField];
}
```

This will add an `PSTCKPaymentCardTextField` to the controller to accept card numbers, expiration dates, and CVCs. It'll format the input, and validate it on the fly.

When the user enters text into this field, the `paymentCardTextFieldDidChange:` method will be called on our view controller. In this callback, we can enable a save button that allows users to submit their valid cards if the form is valid:

```Swift
func paymentCardTextFieldDidChange(textField: PSTCKPaymentCardTextField) {
    // Toggle navigation, for example
    saveButton.enabled = textField.isValid
}
```

```Objective-C
- (void)paymentCardTextFieldDidChange:(PSTCKPaymentCardTextField *)textField { {
    // Toggle navigation, for example
    self.saveButton.enabled = textField.isValid;
}
```

#### Building your own form

If you build your own payment form, you'll need to collect at least your customers' card numbers, CVC and expiration dates.

### Step 4: Assembling Card information into `PSTCKCardParams`

If you're using `PSTCKPaymentCardTextField`, simply call its `cardParams` property to get the assembled card data.

```Swift
let cardParams = paymentTextField.cardParams as PSTCKCardParams
```

```Objective-C
PSTCKCardParams cardParams = [paymentTextField cardParams];
```

If you are using your own form, you can assemble the data into an `PSTCKCardParams` object thus:

```Swift
let cardParams = PSTCKCardParams.init();

// then set parameters thus from card
cardParams.number = card.number
cardParams.cvc = card.cvc
cardParams.expYear = card.expYear
cardParams.expMonth = card.expMonth

// or directly
cardParams.number = "2963781976222"
cardParams.cvc = "289"
cardParams.expYear = 2018
cardParams.expMonth = 9
```

```Objective-C
PSTCKCardParams cardParams = [[PSTCKCardParams alloc] init];

// then set parameters thus from card
cardParams.number = [card number];
cardParams.cvc = [card cvc];
cardParams.expYear = [card expYear];
cardParams.expMonth = [card expMonth];

// or directly
cardParams.number = "2963781976222";
cardParams.cvc = "289";
cardParams.expYear = 2018;
cardParams.expMonth = 9;
```

### Step 4: Getting payments

Our libraries shoulder the burden of PCI compliance by helping you avoid the need to send card data directly to your server. Instead, our libraries send credit card data directly to our servers, where we can charge them or create authorizations which you charge on your server.

We charge cards you send using parameters provided in your `PSTCKTransactionParams`. Assemble Transaction parameters into `PSTCKTransactionParams`, and send them along with the `cardParams` from the previous step to get a charge.

- **CardParams** - As gathered in [Step 3](#step-4-assembling-card-information-into-pstckcardparams)

- **TransactionParams** - This object allows you provide information about the transaction to be made. This  can be used in either of 2 ways:
    - **Resume an initialized transaction**: If employing this flow, you would send all required parameters 
    for the transaction from your backend to the Paystack API via the `transaction/initialize` call - 
    documented [here](https://developers.paystack.co/reference#initialize-a-transaction).. The 
    response of the call includes an `access_code`. This can be used to charge the card by doing 
    `transactionParams.access_code = {value from backend});`. Once an access code is set, others will be ignored.
    - **Initiate a fresh transaction on Paystack**: By setting the parameters: `amount`, `email`, `currency`, `plan`,
     `subaccount`, `transactionCharge`, `reference`, `bearer`. And calling the `setCustomFieldValue` and `setMetadataValue`
     you can set up a fresh transaction directly from the SDK. 
     Documentation for these parameters are same as for `transaction/initialize`.

- **ViewController** - A view controller to be used when presenting dialogs. The currently open ViewController is perfect.

You will need to specify callbacks too. Each will be called depending on how the transaction went.

- **didTransactionSuccess** will be called once the charge succeeds.

- **didRequestValidation** is called every time the SDK needs to request user input. This function currently only allows the app know that the SDK is requesting further user input. 

- **didEndWithError** is called if an error occurred during processing. Some types that you should watch include
    - *PSTCKErrorCode.PSTCKExpiredAccessCodeError*: This would be thrown if the access code has already been used to attempt a charge.
    - *PSTCKErrorCode.PSTCKConflictError*: This would be thrown if another transaction is currently being processed by the SDK


```Swift
@IBAction func charge(sender: UIButton) {
    // cardParams already fetched from our view or assembled by you
    let transactionParams = PSTCKTransactionParams.init();

    // building new Paystack Transaction
    transactionParams.amount = 1390;
    let custom_filters: NSMutableDictionary = [
        "recurring": true
    ];
    let items: NSMutableArray = [
        "Bag","Glasses"
    ];
    do {
        try transactionParams.setCustomFieldValue("iOS SDK", displayedAs: "Paid Via");
        try transactionParams.setCustomFieldValue("Paystack hats", displayedAs: "To Buy");
        try transactionParams.setMetadataValue("iOS SDK", forKey: "paid_via");
        try transactionParams.setMetadataValueDict(custom_filters, forKey: "custom_filters");
        try transactionParams.setMetadataValueArray(items, forKey: "items");
    } catch {
        print(error);
    }
    transactionParams.email = "e@ma.il";

    // check https://developers.paystack.co/docs/split-payments-overview for details on how these work
    // transactionParams.subaccount  = "ACCT_80d907euhish8d";
    // transactionParams.bearer  = "subaccount";
    // transactionParams.transaction_charge  = 280;

    // if a reference is not supplied, we will give one
    // transactionParams.reference = "ChargedFromiOSSDK@"

    PSTCKAPIClient.shared().chargeCard(cardParams, forTransaction: transactionParams, on: viewController,
               didEndWithError: { (error, reference) -> Void in
                handleError(error)
            }, didRequestValidation: { (reference) -> Void in
                // an OTP was requested, transaction has not yet succeeded
            }, didTransactionSuccess: { (reference) -> Void in
                // transaction may have succeeded, please verify on backend
        })
}
```

```Objective-C
- (IBAction)charge:(UIButton *)sender {
    // cardParams already fetched from our view or assembled by you

    PSTCKTransactionParams transactionParams = [[PSTCKTransactionParams alloc] init];

    // resuming a transaction initialized by backend
    transactionParams.access_code = '{access code from server}';

    [[PSTCKAPIClient sharedClient] chargeCard:cardParams
                               forTransaction:transactionParams
                             onViewController: viewController,
                              didEndWithError:^(NSError *error, NSString *reference){
                                                [self handleError:error];
                                            }
                         didRequestValidation: ^(NSString *reference){
                                                // an OTP was requested, transaction has not yet succeeded
                                            }
                        didTransactionSuccess: ^(NSString *reference){
                                                // transaction may have succeeded, please verify on backend
      }];

}
```

### Step 5: Send the reference to your backend

The blocks you gave to `chargeCard` will be called whenever Paystack returns with a reference (or error). You'll need to send the `reference` off to your backend so you can verify the transactions.

Here's how it looks:

```Swift
// ViewController.swift

func verifyCharge(reference: String) {
    let url = NSURL(string: "https://example.com/verify")!
    let request = NSMutableURLRequest(URL: url)
    request.HTTPMethod = "POST"
    let postBody = "reference=reference"
    let postData = postBody.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
    session.uploadTaskWithRequest(request, fromData: postData, completionHandler: { data, response, error in
        let successfulResponse = (response as? NSHTTPURLResponse)?.statusCode == 200
        if successfulResponse && error == nil && data != nil{
            // All was well
            let newStr = NSString(data: data!, encoding: NSUTF8StringEncoding)
            print(newStr) // All we did here is log it to the output window
        } else {
            if let e=error {
                print(e.description)
            } else {
                // There was no error returned though status code was not 200
                print("There was an error communicating with your payment backend.")
                // All we did here is log it to the output window
            }

        }
    }).resume()
}
```

```Objective-C
// ViewController.m

- (void)verifyCharge:(String *)reference
                           {
    NSURL *url = [NSURL URLWithString:@"https://example.com/verify"];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    request.HTTPMethod = @"POST";
    NSString *body     = [NSString stringWithFormat:@"reference=%@", reference];
    request.HTTPBody   = [body dataUsingEncoding:NSUTF8StringEncoding];
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
    NSURLSessionDataTask *task =
    [session dataTaskWithRequest:request
               completionHandler:^(NSData *data,
                                   NSURLResponse *response,
                                   NSError *error) {
                   if (error) {
                       ...
                   } else {
                       ...
                   }
               }];
    [task resume];
}

```

On the server, you just need to implement an endpoint that will accept the parameter: `reference`. Make sure any communication with your backend is SSL secured to prevent eavesdropping.


### Step 6: Implement verification on your server
Verify a charge by calling our REST API. An active `authorization_code` will be returned once the card has been charged successfully. You can learn more about our API [here](https://developers.paystack.co/docs/getting-started).

 **Endpoint:** GET: https://api.paystack.co/transaction/verify

 **Documentation:** https://developers.paystack.co/docs/verify-transaction

 **Parameters:**

 - reference - the transaction reference

**Example**

```bash
   $ curl https://api.paystack.co/transaction/verify/trx_sjdhf2987hb \
    -H "Authorization: Bearer SECRET_KEY" \
    -H "Content-Type: application/json" \
    -X GET

```

### Charging Returning Customers
See details for charging returning customers [here](https://developers.paystack.co/docs/charging-returning-customers). Note that only `reusable` authorizations can be charged with this endpoint.
