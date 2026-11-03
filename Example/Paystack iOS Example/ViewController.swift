//
//  ViewController.swift
//  Paystack iOS Exampe (Simple)
//

import UIKit
import Paystack

class ViewController: UIViewController, PSTCKPaymentCardTextFieldDelegate {
    
    // MARK: REPLACE THESE
    // This sample runs without a backend: it charges with a hard-coded public key and access code.
    // Find your public key at https://dashboard.paystack.co/#/settings/developer
    // set Public key here
    let paystackPublicKey = "public_key"

    // set access code here
    // Get one from a transaction/initialize call (response `data.access_code`) made with your secret key,
    // in the same mode (test/live) as the public key. Access codes are single-use: initialize a new
    // transaction for each test charge.
    let accessCode = "access_code"
    
    let card : PSTCKCard = PSTCKCard()
    
    // MARK: Overrides
    override func viewDidLoad() {
        // hide token label and email box
        tokenLabel.text=nil
        chargeCardButton.isEnabled = false
        // clear text from card details
        // comment these to use the sample data set
        super.viewDidLoad();
    }
    
    // MARK: Helpers
    func showOkayableMessage(_ title: String, message: String){
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: UIAlertController.Style.alert
        )
        let action = UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil)
        alert.addAction(action)
        present(alert, animated: true, completion: nil)
    }
    
    func dismissKeyboardIfAny(){
        // Dismiss Keyboard if any
        cardDetailsForm.resignFirstResponder()
        
    }
    
    
    // MARK: Properties
    @IBOutlet weak var cardDetailsForm: PSTCKPaymentCardTextField!
    @IBOutlet weak var chargeCardButton: UIButton!
    @IBOutlet weak var tokenLabel: UILabel!
    
    // MARK: Actions
    @IBAction func cardDetailsChanged(_ sender: PSTCKPaymentCardTextField) {
        chargeCardButton.isEnabled = sender.isValid
    }
    
    @IBAction func chargeCard(_ sender: UIButton) {
        
        dismissKeyboardIfAny()
        
        // Make sure public key has been set
        if (paystackPublicKey == "" || !paystackPublicKey.hasPrefix("pk_")) {
            showOkayableMessage("You need to set your Paystack public key.", message:"You can find your public key at https://dashboard.paystack.co/#/settings/developer .")
            // You need to set your Paystack public key.
            return
        }
        
        Paystack.setDefaultPublicKey(paystackPublicKey)
        
        if cardDetailsForm.isValid {
            
            // Make sure the access code has been set
            if accessCode == "" {
                showOkayableMessage("You need to set an access code.", message:"Initialize a transaction with your secret key and paste data.access_code into accessCode in ViewController.swift.")
                return
            }
            chargeWithSDK(accessCode: accessCode)
        }
        
    }
    
    func outputOnLabel(str: String){
        DispatchQueue.main.async {
            if let former = self.tokenLabel.text {
                self.tokenLabel.text = former + "\n" + str
            } else {
                self.tokenLabel.text = str
            }
        }
    }
    
    func chargeWithSDK(accessCode: String){
        outputOnLabel(str: "Charging with access code " + accessCode)
        let transactionParams = PSTCKTransactionParams.init();
        transactionParams.access_code = accessCode;
        // use library to create charge and get its reference
        PSTCKAPIClient.shared().chargeCard(self.cardDetailsForm.cardParams, forTransaction: transactionParams, on: self, didEndWithError: { (error, reference) in
            self.outputOnLabel(str: "Charge errored")
            // what should I do if an error occured?
            print(error)
            if error._code == PSTCKErrorCode.PSTCKExpiredAccessCodeError.rawValue{
                // access code could not be used
                // we may as well try afresh
            }
            if error._code == PSTCKErrorCode.PSTCKConflictError.rawValue{
                // another transaction is currently being
                // processed by the SDK... please wait
            }
            if let errorDict = (error._userInfo as! NSDictionary?){
                if let errorString = errorDict.value(forKeyPath: "com.paystack.lib:ErrorMessageKey") as! String? {
                    if let reference=reference {
                        self.showOkayableMessage("An error occured while completing "+reference, message: errorString)
                        self.outputOnLabel(str: reference + ": " + errorString)
                    } else {
                        self.showOkayableMessage("An error occured", message: errorString)
                        self.outputOnLabel(str: errorString)
                    }
                }
            }
            self.chargeCardButton.isEnabled = true;
        }, didRequestValidation: { (reference) in
            self.outputOnLabel(str: "requested validation: " + reference)
        }, willPresentDialog: {
            // make sure dialog can show
            // if using a "processing" dialog, please hide it
            self.outputOnLabel(str: "will show a dialog")
        }, dismissedDialog: {
            // if using a processing dialog, please make it visible again
            self.outputOnLabel(str: "dismissed dialog")
        }) { (reference) in
            self.outputOnLabel(str: "succeeded: " + reference)
            self.chargeCardButton.isEnabled = true;
            // Verify on your server before giving value:
            // GET https://api.paystack.co/transaction/verify/<reference> with your secret key.
            self.outputOnLabel(str: "verify " + reference + " on your server (transaction/verify)")
        }
        return
    }
}
