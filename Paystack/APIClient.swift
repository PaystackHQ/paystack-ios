//
//  APIClient.swift
//  Apple Pay POC
//
//  Created by Jubril Olambiwonnu on 22/06/2021.
//

import Foundation


typealias TransactionCompletionHandler = (Result<PSTKTransaction>) -> Void
typealias ChargeResponseHandler = (Result<ChargeResponse>) -> Void

public extension PSTCKAPIClient {
    @objc public func initializeTransaction(amount: Int, currency: String, email: String, key: String, completion: @escaping (String) -> Void) {
        let requestInlineURL = URL(string: "https://studio-api.paystack.co/checkout/request_inline")!
        let queryParams = [ URLQueryItem(name: "amount", value: String(amount)),
                            URLQueryItem(name: "currency", value: currency),
                            URLQueryItem(name: "email", value: email),
                            URLQueryItem(name: "key", value: key)
        ]
        if let url = requestInlineURL.appending(queryParams) {
            let resource = Resource<PSTKTransaction>(get: url)
            //URLSession.shared.load(resource) {completion($0)}
        }
    }
    
    
}

@objc public class APIClient: NSObject {
    let requestInlineURL = URL(string: "https://studio-api.paystack.co/checkout/request_inline")!
    let chargeURL = URL(string: "https://crayon.paystack.co/applepay/charge")!
    
//    @objc public func initializeTransaction(amount: Int, currency: String, email: String, key: String, completion: @escaping (Result<PSTKTransaction>) -> Void) {
//        let queryParams = [ URLQueryItem(name: "amount", value: String(amount)),
//                            URLQueryItem(name: "currency", value: currency),
//                            URLQueryItem(name: "email", value: email),
//                            URLQueryItem(name: "key", value: key)
//        ]
//        if let url = requestInlineURL.appending(queryParams) {
//            let resource = Resource<PSTKTransaction>(get: url)
//            URLSession.shared.load(resource) {completion($0)}
//        }
//    }
    
    func charge(with transID: String, and pkPayment: PKPaymentContainer, completion: @escaping ChargeResponseHandler) {
        let resource = Resource<ChargeResponse>(url: chargeURL, transID: transID, merchantID: merchantID, pkPayment: pkPayment)
        URLSession.shared.load(resource, completion: {completion($0)})
    }
}


extension URLSession {
    func load<A>(_ resource: Resource<A>, completion: @escaping (Result<A>) -> Void) {
        dataTask(with: resource.urlRequest) { data, _, error in
            guard error == nil, let data = data else {
                completion(Result<A>(object: nil, error: error))
                return
            }
            completion(resource.parse(data))
        }.resume()
    }
}

extension URL {
    func appending(_ queryItems: [URLQueryItem]) -> URL? {
        guard var urlComponents = URLComponents(url: self, resolvingAgainstBaseURL: true) else {
            return nil
        }
        urlComponents.queryItems = (urlComponents.queryItems ?? []) + queryItems
        return urlComponents.url
    }
}
