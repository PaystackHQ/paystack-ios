//
//  PaymentHandler.swift
//  Apple Pay POC
//
//  Created by Jubril Olambiwonnu on 20/06/2021.
//

import Foundation
import PassKit

typealias PaymentCompletionHandler = (ChargeResponse?, Error?) -> Void
let merchantID = "merchant.com.jubril.applepaypoc"

class PaymentHandler: NSObject {
    
    var paymentController: PKPaymentAuthorizationController?
    var paymentSummaryItems = [PKPaymentSummaryItem]()
    var paymentStatus = PKPaymentAuthorizationStatus.failure
    var completionHandler: PaymentCompletionHandler!
    var apiClient = APIClient()
    var transaction: PSTKTransaction?
    var chargeResponse: ChargeResponse?
    let publicKey = "pk_live_0c2ec6e2b0b0c197ed7ba00abb5031def49ef44c"
    
    static let supportedNetworks: [PKPaymentNetwork] = [
        .amex,
        .discover,
        .masterCard,
        .visa
    ]
    
    class func applePayStatus() -> (canMakePayments: Bool, canSetupCards: Bool) {
        return (PKPaymentAuthorizationController.canMakePayments(),
                PKPaymentAuthorizationController.canMakePayments(usingNetworks: supportedNetworks))
    }
    
    func startPayment() {
//        apiClient.initializeTransaction(amount: 500, currency: "NGN", email: "jubrylola@gmail.com", key: publicKey) { [weak self]
//            result in
//            if let transaction = result.object {
//                self?.transaction = transaction
//                self?.presentPaymentSheet()
//            }
//            if let error = result.error {
//                self?.completionHandler?(nil, error)
//            }
//        }
    }
    
    func presentPaymentSheet() {
               
        let ticket = PKPaymentSummaryItem(label: "Afronation Entry", amount: NSDecimalNumber(string: "5.00"), type: .final)
        let total = PKPaymentSummaryItem(label: "Total", amount: NSDecimalNumber(string: "5.00"), type: .final)
        paymentSummaryItems = [ticket, total]
        
        // Create a payment request.
        let paymentRequest = PKPaymentRequest()
        paymentRequest.paymentSummaryItems = paymentSummaryItems
        paymentRequest.merchantIdentifier = merchantID
        paymentRequest.merchantCapabilities = .capability3DS
        paymentRequest.countryCode = "NG"
        paymentRequest.currencyCode = "NGN"
        paymentRequest.supportedNetworks = PaymentHandler.supportedNetworks
        paymentRequest.shippingType = .delivery
        paymentRequest.requiredBillingContactFields = [.name, .postalAddress, .phoneNumber, .emailAddress]
        
        // Display the payment request.
        paymentController = PKPaymentAuthorizationController(paymentRequest: paymentRequest)
        paymentController?.delegate = self
        paymentController?.present()
    }
    
}

extension PaymentHandler: PKPaymentAuthorizationControllerDelegate {
    
    func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didAuthorizePayment payment: PKPayment, handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {

        let status = PKPaymentAuthorizationStatus.success
        if status == .success && transaction != nil {
            apiClient.charge(with: String(transaction!.id), and: PKPaymentContainer(payment)) { result in
                if let response = result.object {
                    print(response.reference)
                    self.chargeResponse = response
                    completion(PKPaymentAuthorizationResult(status: status, errors: nil))
                    self.completionHandler?(self.chargeResponse, nil)
                }
                else {
                    print(result.error?.localizedDescription)
                    if let error = result.error {
                        completion(PKPaymentAuthorizationResult(status: status, errors: [error]))
                        self.completionHandler?(nil, error)

                    }
                }
            }
        }
        
        
        self.paymentStatus = status
    }
    
    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        controller.dismiss()
    }
    
}
