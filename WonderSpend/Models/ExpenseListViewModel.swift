//
//  ExpenseListViewModel.swift
//  WonderSpend
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class ExpenseListViewModel: ObservableObject {
    @Published var selectedCategoryId: UUID?
    @Published var selectedAngle: Double?
    @Published var filter: TransactionFilter = .all
    @Published var periodFilter: PeriodFilter = .month
    @Published var periodAnchorDate = Date()
    @Published var customStartDate = Calendar.current.startOfDay(for: Date())
    @Published var customEndDate = Date()

    func periodTitle() -> String {
        let interval = periodDateInterval()
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: interval.start, to: interval.end)
    }

    func periodDateInterval() -> DateInterval {
        let calendar = Calendar.current

        switch periodFilter {
        case .day:
            let start = calendar.startOfDay(for: periodAnchorDate)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
            return DateInterval(start: start, end: end)
        case .week:
            let start = calendar.dateInterval(of: .weekOfYear, for: periodAnchorDate)?.start
                ?? calendar.startOfDay(for: periodAnchorDate)
            let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
            return DateInterval(start: start, end: end)
        case .month:
            let start = calendar.dateInterval(of: .month, for: periodAnchorDate)?.start
                ?? calendar.startOfDay(for: periodAnchorDate)
            let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
            return DateInterval(start: start, end: end)
        case .year:
            let start = calendar.dateInterval(of: .year, for: periodAnchorDate)?.start
                ?? calendar.startOfDay(for: periodAnchorDate)
            let end = calendar.date(byAdding: .year, value: 1, to: start) ?? start
            return DateInterval(start: start, end: end)
        case .custom:
            let start = min(customStartDate, customEndDate)
            let end = max(customStartDate, customEndDate)
            let adjustedEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end)) ?? end
            return DateInterval(start: calendar.startOfDay(for: start), end: adjustedEnd)
        }
    }

    func itemsInPeriod(from items: [Item]) -> [Item] {
        let interval = periodDateInterval()
        return items.filter { interval.contains($0.date) }
    }

    func applyTypeFilter(to items: [Item]) -> [Item] {
        switch filter {
        case .all:
            return items
        case .expense:
            return items.filter { $0.type == .expense }
        case .income:
            return items.filter { $0.type == .income }
        }
    }

    func periodIncome(from items: [Item]) -> Double {
        itemsInPeriod(from: items)
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.amount }
    }

    func periodExpense(from items: [Item]) -> Double {
        itemsInPeriod(from: items)
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
    }

    func periodBalance(from items: [Item]) -> Double {
        periodIncome(from: items) - periodExpense(from: items)
    }

    func periodItems(from items: [Item]) -> [Item] {
        let filteredItems = items.filter { item in
            if let selectedCategoryId {
                return item.category.id == selectedCategoryId
            }
            return true
        }

        return applyTypeFilter(to: itemsInPeriod(from: filteredItems))
    }

    func categoryTotals(for type: TransactionType, from items: [Item]) -> [CategoryTotal] {
        let totals = Dictionary(
            grouping: itemsInPeriod(from: items).filter { $0.type == type },
            by: \Item.category
        )
            .map { category, items in
                CategoryTotal(
                    category: category,
                    total: items.reduce(0) { $0 + $1.amount }
                )
            }

        return totals.sorted { $0.total > $1.total }
    }

    func expenseTrend(from items: [Item]) -> [TrendPoint] {
        let calendar = Calendar.current
        let expenseItems = itemsInPeriod(from: items).filter { $0.type == .expense }
        let grouped = Dictionary(grouping: expenseItems) { item in
            calendar.startOfDay(for: item.date)
        }

        return grouped
            .map { date, items in
                TrendPoint(date: date, total: items.reduce(0) { $0 + $1.amount })
            }
            .sorted { $0.date < $1.date }
    }
}
