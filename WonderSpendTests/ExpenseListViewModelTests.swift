//
//  ExpenseListViewModelTests.swift
//  WonderSpendTests
//

import Testing
@testable import WonderSpend

struct ExpenseListViewModelTests {
    @Test
    func periodFilteringByDay() {
        let calendar = Calendar.current
        let baseDate = calendar.date(from: DateComponents(year: 2026, month: 2, day: 6)) ?? Date()
        let category = Category(name: "Food", emoji: "🍜", colorHex: "#DD6B20")
        let itemToday = Item(
            amount: 10,
            date: baseDate,
            category: category,
            shortDescription: "Lunch",
            note: "",
            merchant: "A",
            type: .expense
        )
        let itemYesterday = Item(
            amount: 5,
            date: calendar.date(byAdding: .day, value: -1, to: baseDate) ?? baseDate,
            category: category,
            shortDescription: "Snack",
            note: "",
            merchant: "B",
            type: .expense
        )

        let viewModel = ExpenseListViewModel()
        viewModel.periodFilter = .day
        viewModel.periodAnchorDate = baseDate

        let filtered = viewModel.itemsInPeriod(from: [itemToday, itemYesterday])
        #expect(filtered.count == 1)
        #expect(filtered.first?.merchant == "A")
    }

    @Test
    func periodTotalsByType() {
        let calendar = Calendar.current
        let baseDate = calendar.date(from: DateComponents(year: 2026, month: 2, day: 6)) ?? Date()
        let category = Category(name: "General", emoji: "🧾", colorHex: "#4A5568")
        let income = Item(
            amount: 100,
            date: baseDate,
            category: category,
            shortDescription: "Salary",
            note: "",
            merchant: "Pay",
            type: .income
        )
        let expense = Item(
            amount: 40,
            date: baseDate,
            category: category,
            shortDescription: "Groceries",
            note: "",
            merchant: "Shop",
            type: .expense
        )

        let viewModel = ExpenseListViewModel()
        viewModel.periodFilter = .day
        viewModel.periodAnchorDate = baseDate

        #expect(viewModel.periodIncome(from: [income, expense]) == 100)
        #expect(viewModel.periodExpense(from: [income, expense]) == 40)
        #expect(viewModel.periodBalance(from: [income, expense]) == 60)
    }
}
