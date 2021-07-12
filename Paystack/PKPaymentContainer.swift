//
//  EncodablePKPayment.swift
//  Apple Pay POC
//
//  Created by Jubril Olambiwonnu on 21/06/2021.
//

import Foundation
import PassKit

struct PKPaymentContainer: Encodable {
    var payment: PKPayment
    
    init(_ payment: PKPayment) {
        self.payment = payment
        
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var billingContactContainer = container.nestedContainer(keyedBy: CodingKeys.self, forKey: .billingContact)
        try billingContactContainer.encode([payment.billingContact?.postalAddress?.street ?? ""], forKey: .addressLines)
        try billingContactContainer.encode(payment.billingContact?.postalAddress?.state, forKey: .administrativeArea)
        try billingContactContainer.encode(payment.billingContact?.postalAddress?.country, forKey: .country)
        try billingContactContainer.encode(payment.billingContact?.postalAddress?.isoCountryCode, forKey: .countryCode)
        try billingContactContainer.encode(payment.billingContact?.postalAddress?.postalCode, forKey: .postalCode)
        try billingContactContainer.encode(payment.billingContact?.postalAddress?.subAdministrativeArea, forKey: .subAdministrativeArea)
        try billingContactContainer.encode(payment.billingContact?.postalAddress?.subLocality, forKey: .subLocality)
        try billingContactContainer.encode(payment.billingContact?.postalAddress?.city, forKey: .locality)
        try billingContactContainer.encode(payment.billingContact?.name?.familyName, forKey: .familyName)
        try billingContactContainer.encode(payment.billingContact?.name?.givenName, forKey: .givenName)
        
        var tokenContainer = container.nestedContainer(keyedBy: CodingKeys.self, forKey: .token)
        try tokenContainer.encode(payment.token.transactionIdentifier, forKey: .transactionIdentifier)
        
        var paymentMethod = tokenContainer.nestedContainer(keyedBy: CodingKeys.self, forKey: .paymentMethod)
        try paymentMethod.encode(payment.token.paymentMethod.displayName, forKey: .displayName)
        try paymentMethod.encode(payment.token.paymentMethod.network?.rawValue, forKey: .network)
        try paymentMethod.encode(cardTypeString(for: payment.token.paymentMethod.type), forKey: .type)
        
        if let paymentDataDictionary = try? JSONSerialization.jsonObject(with: payment.token.paymentData, options: .mutableContainers) as? [AnyHashable : Any] {
            var paymentData = tokenContainer.nestedContainer(keyedBy: CodingKeys.self, forKey: .paymentData)
            print(paymentDataDictionary)
            try paymentData.encode(paymentDataDictionary["data"] as? String, forKey: .data)
            try paymentData.encode(paymentDataDictionary["signature"] as? String, forKey: .signature)
            try paymentData.encode(paymentDataDictionary["version"] as? String, forKey: .version)
            
            if let headerDict = paymentDataDictionary["header"] as? [AnyHashable : Any] {
                var header = paymentData.nestedContainer(keyedBy: CodingKeys.self, forKey: .header)
                try header.encode(headerDict["publicKeyHash"] as? String, forKey: .publicKeyHash)
                try header.encode(headerDict["ephemeralPublicKey"] as? String, forKey: .ephemeralPublicKey)
                try header.encode(headerDict["transactionId"] as? String, forKey: .transactionId)
            }
        }
    }
    
    func cardTypeString(for type: PKPaymentMethodType) -> String {
        var paymentType = ""
        switch type {
        case .debit:
            paymentType = "debit"
        case .credit:
            paymentType = "credit"
        case .store:
            paymentType = "store"
        case .prepaid:
            paymentType = "prepaid"
        default:
            paymentType = "unknown"
        }
        return paymentType
    }
    
    enum CodingKeys: String, CodingKey {
        case billingContact
        case token
        case data
        case paymentData
        case addressLines
        case administrativeArea
        case country
        case countryCode
        case postalCode
        case subAdministrativeArea
        case subLocality
        case locality
        case familyName
        case givenName
        case transactionIdentifier
        case paymentMethod
        case displayName
        case network
        case type
        case version
        case signature
        case header
        case publicKeyHash
        case ephemeralPublicKey
        case transactionId
    }
}
