//
//  HttpMethod.swift
//  Apple Pay POC
//
//  Created by Jubril Olambiwonnu on 23/06/2021.
//

import Foundation

enum HttpMethod {
    case get
    case post
}

extension HttpMethod {
    var method: String {
        switch self {
        case .get: return "GET"
        case .post: return "POST"
        }
    }
}
