//
//  MainTabView.swift
//  WonderSpend
//

import SwiftUI

struct MainTabView: View {
    enum Tab {
        case list
        case summary
    }

    let items: [Item]
    let categories: [Category]
    let currencyCode: String
    let navigationTitle: String
    let isLandscape: Bool
    let periodTitle: String
    let periodIncome: Double
    let periodExpense: Double
    let periodBalance: Double
    let expenseTrend: [TrendPoint]
    let categoryTotalsExpense: [CategoryTotal]
    @Binding var selectedCategoryId: UUID?
    @Binding var selectedAngle: Double?
    @Binding var filter: TransactionFilter
    @Binding var periodFilter: PeriodFilter
    @Binding var periodAnchorDate: Date
    @Binding var customStartDate: Date
    @Binding var customEndDate: Date
    let onAddExpense: () -> Void
    let onManageCategories: () -> Void
    let onDelete: (IndexSet) -> Void
    let settingsDestination: SettingsView

    @State private var selectedTab: Tab = .list

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ExpenseListView(
                    isLandscape: isLandscape,
                    items: items,
                    categories: categories,
                    currencyCode: currencyCode,
                    navigationTitle: navigationTitle,
                    periodTitle: periodTitle,
                    periodIncome: periodIncome,
                    periodExpense: periodExpense,
                    periodBalance: periodBalance,
                    expenseTrend: expenseTrend,
                    showCharts: true,
                    onAddExpense: onAddExpense,
                    onManageCategories: onManageCategories,
                    onDelete: onDelete,
                    selectedCategoryId: $selectedCategoryId,
                    selectedAngle: $selectedAngle,
                    filter: $filter,
                    periodFilter: $periodFilter,
                    periodAnchorDate: $periodAnchorDate,
                    customStartDate: $customStartDate,
                    customEndDate: $customEndDate,
                    settingsDestination: settingsDestination
                )
            }
            .tabItem {
                Label("List", systemImage: "list.bullet")
            }
            .tag(Tab.list)

            NavigationStack {
                InsightsView(
                    itemsEmpty: items.isEmpty,
                    currencyCode: currencyCode,
                    periodTitle: periodTitle,
                    periodIncome: periodIncome,
                    periodExpense: periodExpense,
                    periodBalance: periodBalance,
                    categoryTotalsExpense: categoryTotalsExpense,
                    selectedCategoryId: $selectedCategoryId,
                    selectedAngle: $selectedAngle,
                    periodFilter: $periodFilter,
                    periodAnchorDate: $periodAnchorDate,
                    customStartDate: $customStartDate,
                    customEndDate: $customEndDate
                )
            }
            .tabItem {
                Label("Summary", systemImage: "chart.pie")
            }
            .tag(Tab.summary)
        }
    }

}
