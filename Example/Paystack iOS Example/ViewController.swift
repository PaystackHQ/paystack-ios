//
//  ViewController.swift
//  Paystack iOS Exampe (Simple)
//

import UIKit
import Paystack

class ViewController: UIViewController, PSTCKPaymentCardTextFieldDelegate {
    
    // MARK: REPLACE THESE
    // Replace these values with your application's keys
    // Find this at https://dashboard.paystack.co/#/settings/developer
    let paystackPublicKey = ""
    // let paystackPublicKey = "pk_live_ed8a7004bb85bf636a0a22c635ad9d1788caa5de"
    
    // To set this up, see https://github.com/PaystackHQ/sample-charge-card-backend
    let backendURLString = ""
    // let backendURLString = "https://calm-scrubland-33409.herokuapp.com"
    
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
            
            if backendURLString != "" {
                fetchAccessCodeAndChargeCard()
                return
            }
            showOkayableMessage("Backend not configured", message:"To run this sample, please configure your backend.")
//            chargeWithSDK(newCode:"");
            
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
    
    func fetchAccessCodeAndChargeCard(){
        if let url = URL(string: backendURLString  + "/new-access-code") {
            self.makeBackendRequest(url: url, message: "fetching access code", completion: { str in
                self.outputOnLabel(str: "Fetched access code: "+str)
                self.chargeWithSDK(newCode: str as NSString)
            })
        }
    }
    
    func chargeWithSDK(newCode: NSString){
        let transactionParams = PSTCKTransactionParams.init();
        transactionParams.access_code = newCode as String;
        //transactionParams.additionalAPIParameters = ["enforce_otp": "true"];
//        transactionParams.email = "ibrahim@paystack.co";
//        transactionParams.amount = 2000;
//        let dictParams: NSMutableDictionary = [
//            "recurring": true
//        ];
//        let arrParams: NSMutableArray = [
//            "0","go"
//        ];
//        do {
//            try transactionParams.setMetadataValueDict(dictParams, forKey: "custom_filters");
//            try transactionParams.setMetadataValueArray(arrParams, forKey: "custom_array");
//        } catch {
//            print(error)
//        }
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
                        self.verifyTransaction(reference: reference)
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
            self.verifyTransaction(reference: reference)
        }
        return
    }
    
    func initializeTransaction() {
        let transactionParams = PSTCKTransactionParams()
       // PSTCKAPIClient.shared().initializeTransaction(transactionParams, didSucceed: <#T##PSTCKErrorCompletionBlock##PSTCKErrorCompletionBlock##(Error, String?) -> Void#>, didEndWithError: <#T##PSTCKErrorCompletionBlock##PSTCKErrorCompletionBlock##(Error, String?) -> Void#>)
    }
    
    
    func verifyTransaction(reference: String){
        if let url = URL(string: backendURLString  + "/verify/" + reference) {
            makeBackendRequest(url: url, message: "verifying " + reference, completion:{(str) -> Void in
                self.outputOnLabel(str: "Message from paystack on verifying " + reference + ": " + str)
            })
        }
    }
    
    func makeBackendRequest(url: URL, message: String, completion: @escaping (_ result: String) -> Void){
        let session = URLSession(configuration: URLSessionConfiguration.default)
        self.outputOnLabel(str: "Backend: " + message)
        session.dataTask(with: url, completionHandler: { data, response, error in
            let successfulResponse = (response as? HTTPURLResponse)?.statusCode == 200
            if successfulResponse && error == nil && data != nil {
                if let str = NSString(data: data!, encoding: String.Encoding.utf8.rawValue){
                    completion(str as String)
                } else {
                    self.outputOnLabel(str: "<Unable to read response> while "+message)
                    print("<Unable to read response>")
                }
            } else {
                if let error = error {
                    print(error.localizedDescription)
                    self.outputOnLabel(str: error.localizedDescription)
                } else {
                    // There was no error returned though status code was not 200
                    print("There was an error communicating with your payment backend.")
                    self.outputOnLabel(str: "There was an error communicating with your payment backend while "+message)
                }
            }
        }).resume()
    }
}
