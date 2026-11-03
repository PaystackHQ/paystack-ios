//
//  PSTCKAPIClientExtension.swift
//  PaystackiOS

import Foundation

@objc extension PSTCKAPIClient {
    
    public func fetchStates(country: String, completion: @escaping ([PSTCKState], Error?) -> Void) {
        var components = URLComponents(string: "https://api.paystack.co/address_verification/states")
        components?.queryItems = [URLQueryItem(name: "country", value: country)]
        guard let url = components?.url else {
            completion([PSTCKState](), StringError("Could not build the address verification request"))
            return
        }
        guard let key = publicKey, !key.isEmpty else {
            completion([PSTCKState](), StringError("A Paystack public key is required"))
            return
        }
        // Same per-request headers as PSTCKAPIClient -authorizedRequestWithURL:method: (ObjC, private).
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue(pstckPaystackVersionHeaderValue(), forHTTPHeaderField: "Paystack-Version")
        URLSession.shared.dataTask(with: request, completionHandler: { data, _, error in
            if let error = error {
                completion([PSTCKState](), error)
                return
            }
            guard let data = data,
                  let responseJSON = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] else {
                completion([PSTCKState](), StringError("Could not fetch issuing country states"))
                return
            }
            guard responseJSON["status"] as? Bool == true else {
                completion([PSTCKState](), StringError(responseJSON["message"] as? String ?? "Could not fetch issuing country states"))
                return
            }
            guard let items = responseJSON["data"] as? [[String: Any]] else {
                completion([PSTCKState](), StringError("Could not fetch issuing country states"))
                return
            }
            completion(items.compactMap { PSTCKState(dict: $0) }, nil)
        }).resume()
    }    
}

/// Mirrors +[PSTCKAPIClient paystackVersionHeaderValue]: the SDK version from the project config
/// (framework CFBundleShortVersionString), falling back to PSTCKSDKVersion for static builds.
fileprivate func pstckPaystackVersionHeaderValue() -> String {
    let bundle = Bundle(for: PSTCKAPIClient.self)
    if bundle != Bundle.main,
       let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String,
       !version.isEmpty {
        return version
    }
    return PSTCKSDKVersion
}


@objc public class PSTCKState: NSObject {
    public var name: String
    public var abbreviation: String
    
    init(name: String, abb: String) {
        self.name = name
        self.abbreviation = abb
    }
    
    init?(dict: [String : Any]) {
        if let name = dict["name"] as? String, let abb = dict["abbreviation"] as? String {
            self.name = name
            self.abbreviation = abb
            return
        }
       return nil
    }
}

struct StringError : LocalizedError {
    var errorDescription: String? { return errorMessage }
    var failureReason: String? { return errorMessage }
    var recoverySuggestion: String? { return "" }
    var helpAnchor: String? { return "" }
    
    private var errorMessage : String
    
    init(_ description: String)
    {
        errorMessage = description
    }
}




