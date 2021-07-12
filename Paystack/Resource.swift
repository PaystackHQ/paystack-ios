//
//  Resource.swift
//  Apple Pay POC
//
//  Created by Jubril Olambiwonnu on 23/06/2021.
//

import Foundation

struct Resource<A> {
    var urlRequest: URLRequest
    let parse: (Data) -> Result<A>
}


extension Resource where A: Decodable {
    init(get url: URL) {
        self.urlRequest = URLRequest(url: url)
        self.parse = { Result(data: $0) }
    }
    
    init(url: URL, transID: String, merchantID: String, pkPayment: PKPaymentContainer) {
        let requestHeader = ["Content-Type" : "application/x-www-form-urlencoded"]
        var request = URLRequest(url: url)
        var requestBodyComponents = URLComponents()
        
        if let data = try? JSONEncoder().encode(pkPayment) {
            let query = URLQueryItem(name: "paymentObject", value: (String(data: data, encoding: .utf8) ?? "").percentEscapeString())
            print(query.description)
            requestBodyComponents.queryItems = [ URLQueryItem(name: "paymentObject", value: (String(data: data, encoding: .utf8) ?? "").percentEscapeString()),
                                                 URLQueryItem(name: "transaction", value: transID),
                                                 URLQueryItem(name: "merchantIdentifier", value: merchantID)
            ]
        }
        request.httpMethod = HttpMethod.post.method
        request.allHTTPHeaderFields = requestHeader
        request.httpBody = requestBodyComponents.query?.data(using: .utf8)
        self.urlRequest = request
        self.parse = { Result(data: $0) }
    }
    
}

extension String {
     func percentEscapeString() -> String {
      var characterSet = CharacterSet.alphanumerics
      characterSet.insert(charactersIn: "-._* ")
      
      return self
        .addingPercentEncoding(withAllowedCharacters: characterSet)!
        .replacingOccurrences(of: " ", with: "+")
        .replacingOccurrences(of: " ", with: "+", options: [], range: nil)
    }
}
