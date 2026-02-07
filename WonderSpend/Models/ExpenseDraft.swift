//
//  ExpenseDraft.swift
//  WonderSpend
//

import Foundation

struct ExpenseDraft {
    var amount: Double
    var date: Date
    var categoryId: UUID?
    var type: TransactionType
    var shortDescription: String
    var note: String
    var merchant: String
}
