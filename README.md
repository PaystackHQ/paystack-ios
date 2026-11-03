# Paystack iOS SDK (legacy)
[![CocoaPods](https://img.shields.io/cocoapods/v/Paystack.svg?style=flat)](https://cocoapods.org/pods/Paystack)
[![CocoaPods](https://img.shields.io/cocoapods/l/Paystack.svg?style=flat)](https://github.com/paystackhq/paystack-ios/blob/master/LICENSE)
[![CocoaPods](https://img.shields.io/cocoapods/p/Paystack.svg?style=flat)](https://github.com/paystackhq/paystack-ios#)

> **This SDK is deprecated.** It receives maintenance fixes only. New integrations should use the new Paystack iOS SDK:
> **https://github.com/PaystackHQ/paystack-sdk-ios**. The `chargeCard` methods and other key APIs carry a deprecation warning pointing there.
> The warnings are warnings only: your app keeps building unless you treat warnings as errors.

> **CocoaPods trunk stops accepting new versions on 2 December 2026.** CocoaPods is moving its central Specs repo to read-only.
> Versions already published stay installable with `pod install`, but no new versions can be published after that date.
> See the CocoaPods announcement: [CocoaPods Specs Repo](https://blog.cocoapods.org/CocoaPods-Specs-Repo/).
> To keep getting updates, move to the [new SDK](https://github.com/PaystackHQ/paystack-sdk-ios), which supports Swift Package Manager.

The Paystack iOS SDK makes it easy to collect your users' card details inside your iOS app and charge them on Paystack's servers,
so sensitive card data never touches your server. You get a transaction reference back, which you verify from your server-side code.

## What's new in 3.1.0

- **Requery by access code.** Status checks now call `charge/requery/{access_code}`, using the access code you pass in
  `PSTCKTransactionParams.access_code`. Charges started without an access code temporarily fall back to the transaction id. That fallback
  will be removed in a future release, so initialize transactions on your server and always pass `access_code`.
- **Pending charges are polled.** A `pending` status is checked again every 5 seconds, up to 12 times (60 seconds), then the charge ends with
  an error that includes the reference so you can verify it on your server.
- **Public key on every request.** `Authorization: Bearer <public key>` and `Paystack-Version` (the SDK version) are now sent on every call,
  including the address-verification lookup. Changing `publicKey` on a client takes effect on the next request.
- **Fixes:** a second `chargeCard` call while one is running no longer overwrites the running charge's callbacks; crashes on a missing
  transaction id and on non-UTF-8 responses are fixed; the address-verification lookup always completes.
- **Build updates:** minimum iOS raised to 15.0; builds with current Xcode. See [Requirements](#requirements).

No public API changed. See the [CHANGELOG](CHANGELOG) for the full list.

## Requirements

| | Minimum |
| --- | --- |
| iOS deployment target | **15.0** (was 11.0). Apps supporting older iOS versions should stay on 3.0.17 |
| Xcode | **Xcode 26** or later (latest stable recommended) |
| Swift | 5.0 |
| Entitlements | **Keychain Sharing** must be enabled for your app (the SDK uses the keychain to encrypt card data) |

Building with the current iOS SDK also requires your app to use the **UIScene life cycle**: apps without a scene manifest fail to launch
with "UIScene life cycle is required for apps built with this SDK". The example app shows the setup (`SceneDelegate` in `AppDelegate.swift`
and `UIApplicationSceneManifest` in `Info.plist`). See Apple's
[Transitioning to the UIKit scene-based life cycle](https://developer.apple.com/documentation/uikit/transitioning-to-the-uikit-scene-based-life-cycle).

## Integration

The [guide](GUIDE.md) covers installation, charging cards and handling each authentication step. In short:

1. Your **server** calls [`transaction/initialize`](https://paystack.com/docs/api/transaction/#initialize) with your secret key and returns
   `data.access_code` to the app.
2. Your **app** sets the public key once: `Paystack.setDefaultPublicKey("pk_test_…")`.
3. Your **app** sets `transactionParams.access_code` and calls `PSTCKAPIClient.shared().chargeCard(…)`. The SDK handles PIN, OTP, 3DS and
   address verification.
4. Your **server** verifies the returned reference with [`transaction/verify`](https://paystack.com/docs/api/transaction/#verify) before
   giving value.

## Example app

`Example/Paystack iOS Example` is a minimal Swift integration using `PSTCKPaymentCardTextField`. It **doesn't need a backend**: it charges
with a public key and an access code that you paste into `ViewController.swift`.

1. Get your **test** public key from the [Paystack Dashboard](https://dashboard.paystack.com/#/settings/developer).
2. Initialize a test transaction with your **test** secret key (for example with `curl` against `transaction/initialize`) and copy
   `data.access_code`.
3. In `ViewController.swift`, set `paystackPublicKey` (under `// set Public key here`) and `accessCode` (under `// set access code here`).
4. Open `Paystack.xcworkspace`, choose the example scheme and run.

Access codes are single-use: initialize a new transaction for each test charge. The key and the access code must be from the same mode
(test or live). Don't commit real keys or access codes.

### Making a test charge

Use Paystack's [test cards](https://paystack.com/docs/payments/test-payments/) instead of a real card. To try the PIN + OTP flow:

```
5060 6666 6666 6666 666
CVV: 123
PIN: 1234
OTP: 123456
```

You can then see the payments in your Paystack Dashboard.

## Handling errors

See [PaystackError.h](Paystack/PublicHeaders/PaystackError.h) for the error codes the SDK can return, for example
`PSTCKExpiredAccessCodeError` when an access code has already been used, and `PSTCKConflictError` when a charge is started while another
is in progress.
