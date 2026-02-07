//
//  TransactionFilter.swift
//  WonderSpend
//

enum TransactionFilter: String, CaseIterable {
    case all
    case expense
    case income

    var title: String {
        switch self {
        case .all:
            return "All"
        case .expense:
            return "Expense"
        case .income:
            return "Income"
        }
    }
}
