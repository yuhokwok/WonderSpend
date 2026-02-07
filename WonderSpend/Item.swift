//
//  Item.swift
//  WonderSpend
//
//  Created by Yu Ho Kwok on 2/5/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var amount: Double
    var date: Date
    var category: Category
    var shortDescription: String
    var note: String
    var merchant: String
    var type: TransactionType

    init(
        amount: Double,
        date: Date,
        category: Category,
        shortDescription: String,
        note: String,
        merchant: String,
        type: TransactionType
    ) {
        self.amount = amount
        self.date = date
        self.category = category
        self.shortDescription = shortDescription
        self.note = note
        self.merchant = merchant
        self.type = type
    }
}

enum TransactionType: String, CaseIterable, Codable {
    case expense
    case income

    var title: String {
        switch self {
        case .expense:
            return "Expense"
        case .income:
            return "Income"
        }
    }
}
