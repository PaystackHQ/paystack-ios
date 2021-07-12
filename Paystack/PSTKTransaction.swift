//
//  PSTKTransaction.swift
//  Apple Pay POC
//
//  Created by Jubril Olambiwonnu on 22/06/2021.
//

import Foundation

public struct PSTKTransaction: Decodable {
    var id: Int
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dataContainer = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .data)
        id = try dataContainer.decode(Int.self, forKey: .id)
    }
    
    enum CodingKeys: String, CodingKey {
        case data
        case id
    }
    
}
