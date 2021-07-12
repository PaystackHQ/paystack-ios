//
//  Result.swift
//  Apple Pay POC
//
//  Created by Jubril Olambiwonnu on 23/06/2021.
//

import Foundation

public struct Result<A> {
    var object: A?
    var error: Error?
}

extension Result where A: Decodable {
    init(data: Data) {
        do {
            self.object = try JSONDecoder().decode(A.self, from: data)
        }
        catch {
            self.error = try? JSONDecoder().decode(PSTKError.self, from: data)
        }
    }
}
