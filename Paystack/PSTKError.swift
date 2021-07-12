//
//  PSTKError.swift
//  Apple Pay POC
//
//  Created by Jubril Olambiwonnu on 22/06/2021.
//

import Foundation

struct PSTKError: Decodable, Error {
    var message: String
}

extension PSTKError: LocalizedError {
    var errorDescription: String? {
        return message
    }
}
