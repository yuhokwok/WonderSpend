//
//  ExpenseLanguageInterpreter.swift
//  WonderSpend
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

struct ExpenseSuggestion {
    let amount: Double?
    let type: TransactionType?
    let categoryId: UUID?
    let categoryName: String?
    let shortDescription: String?
    let merchant: String?
    let date: Date?
}

enum ExpenseLanguageInterpreter {
    static func suggest(from input: String, categories: [Category]) async throws -> ExpenseSuggestion {
        #if canImport(FoundationModels)
        if #available(iOS 18.0, *) {
            return try await suggestWithFoundationModels(from: input, categories: categories)
        }
        #endif

        throw ExpenseLanguageInterpreterError.unavailable
    }

    static func suggestMultiple(from input: String, categories: [Category]) async throws -> [ExpenseSuggestion] {
        #if canImport(FoundationModels)
        if #available(iOS 18.0, *) {
            let response = try await suggestMultipleWithFoundationModels(from: input, categories: categories)
            if !response.isEmpty {
                return response
            }
        }
        #endif

        let parts = input
            .split(whereSeparator: { $0 == "\n" || $0 == ";" })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if parts.count <= 1 {
            return [try await suggest(from: input, categories: categories)]
        }

        var results: [ExpenseSuggestion] = []
        for part in parts {
            if let suggestion = try? await suggest(from: part, categories: categories) {
                results.append(suggestion)
            }
        }

        return results
    }
}

enum ExpenseLanguageInterpreterError: LocalizedError {
    case unavailable
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Apple Intelligence isn’t available on this device."
        case .invalidResponse:
            return "The model didn’t return enough information."
        }
    }
}

#if canImport(FoundationModels)
@available(iOS 18.0, *)
@Generable
private struct ExpenseParsingResult {
    @Guide(description: "Expense amount in HKD as a number, without currency symbols.")
    let amount: Double?

    @Guide(description: "Either \"expense\" or \"income\".")
    let type: String?

    @Guide(description: "One of the provided categories. Leave empty if unsure.")
    let category: String?

    @Guide(description: "Short description of the expense, max 6 words.")
    let shortDescription: String?

    @Guide(description: "Merchant name if mentioned.")
    let merchant: String?

    @Guide(description: "Transaction date in YYYY-MM-DD (e.g., 2026-02-06). Resolve relative dates like yesterday.")
    let date: String?
}

@available(iOS 18.0, *)
@Generable
private struct MultiExpenseParsingResult {
    @Guide(description: "A list of extracted transactions. Keep the same order as the input.")
    let entries: [ExpenseParsingResult]
}

@available(iOS 18.0, *)
private func suggestWithFoundationModels(
    from input: String,
    categories: [Category]
) async throws -> ExpenseSuggestion {
    let categoryNames = categories.map(\.name)
    let categoriesList = categoryNames.joined(separator: ", ")
    let todayString = isoDateString(from: Date())
    let instructions = """
    You extract structured expense data. Use HKD amounts. \
    Return expense or income. Choose a category from: \(categoriesList).
    Today is \(todayString). Use this to resolve relative dates.
    """
    let session = LanguageModelSession(instructions: instructions)
    let response = try await session.respond(
        to: "Input: \(input)",
        generating: ExpenseParsingResult.self
    )
    return mapSuggestion(from: response.content, categories: categories)
}

@available(iOS 18.0, *)
private func suggestMultipleWithFoundationModels(
    from input: String,
    categories: [Category]
) async throws -> [ExpenseSuggestion] {
    let categoryNames = categories.map(\.name)
    let categoriesList = categoryNames.joined(separator: ", ")
    let todayString = isoDateString(from: Date())
    let instructions = """
    You extract structured expense data. Use HKD amounts.
    If the input contains multiple transactions, return each one separately.
    Return expense or income. Choose a category from: \(categoriesList).
    Today is \(todayString). Use this to resolve relative dates.
    """
    let session = LanguageModelSession(instructions: instructions)
    let response = try await session.respond(
        to: "Input: \(input)",
        generating: MultiExpenseParsingResult.self
    )
    let entries = response.content.entries
    guard !entries.isEmpty else { return [] }
    return entries.map { mapSuggestion(from: $0, categories: categories) }
}

@available(iOS 18.0, *)
private func mapSuggestion(from parsed: ExpenseParsingResult, categories: [Category]) -> ExpenseSuggestion {
    let matchedCategoryId = categories.first {
        guard let category = parsed.category?.lowercased() else { return false }
        return $0.name.lowercased() == category
    }?.id

    let parsedType: TransactionType?
    if let type = parsed.type?.lowercased() {
        parsedType = type.contains("income") ? .income : type.contains("expense") ? .expense : nil
    } else {
        parsedType = nil
    }

    return ExpenseSuggestion(
        amount: parsed.amount.map { max(0, $0) },
        type: parsedType,
        categoryId: matchedCategoryId,
        categoryName: parsed.category,
        shortDescription: parsed.shortDescription,
        merchant: parsed.merchant,
        date: parseDate(from: parsed.date)
    )
}

@available(iOS 18.0, *)
private func parseDate(from value: String?) -> Date? {
    guard let value, !value.isEmpty else { return nil }
    if let date = dateFromIsoString(value) {
        return date
    }
    let fallback = DateFormatter()
    fallback.locale = Locale(identifier: "en_US_POSIX")
    fallback.dateFormat = "yyyy-MM-dd"
    return fallback.date(from: value)
}

@available(iOS 18.0, *)
private func isoDateString(from date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
}

@available(iOS 18.0, *)
private func dateFromIsoString(_ value: String) -> Date? {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: value)
}
#endif
