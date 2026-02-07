//
//  ExpenseListView.swift
//  WonderSpend
//

import SwiftUI
import UIKit
import Charts

struct ExpenseListView<SettingsDestination: View>: View {
    let isLandscape: Bool
    let items: [Item]
    let categories: [Category]
    let currencyCode: String
    let navigationTitle: String
    let periodTitle: String
    let periodIncome: Double
    let periodExpense: Double
    let periodBalance: Double
    let expenseTrend: [TrendPoint]
    let showCharts: Bool
    let onAddExpense: () -> Void
    let onManageCategories: () -> Void
    let onDelete: (IndexSet) -> Void
    @Binding var selectedCategoryId: UUID?
    @Binding var selectedAngle: Double?
    @Binding var filter: TransactionFilter
    @Binding var periodFilter: PeriodFilter
    @Binding var periodAnchorDate: Date
    @Binding var customStartDate: Date
    @Binding var customEndDate: Date
    let settingsDestination: SettingsDestination

    @State private var isPresentingFilters = false

    var body: some View {
        Group {
            if isLandscape {
                HStack(spacing: 0) {
                    leftSummaryPane
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGroupedBackground))

                    Divider()

                    listPane
                        .frame(maxWidth: .infinity)
                }
            } else {
                listPane
            }
        }
        .navigationTitle(navigationTitle)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    triggerHaptic()
                    onManageCategories()
                } label: {
                    Label("Categories", systemImage: "tag")
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    triggerHaptic()
                    onAddExpense()
                } label: {
                    Label("Add Expense", systemImage: "plus")
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    settingsDestination
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .simultaneousGesture(
                    TapGesture().onEnded {
                        triggerHaptic()
                    }
                )
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    triggerHaptic()
                    isPresentingFilters = true
                } label: {
                    Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                }
                .popover(isPresented: Binding(
                    get: { isPresentingFilters && isPad },
                    set: { isPresentingFilters = $0 }
                )) {
                    filterForm
                        .frame(minWidth: 320, minHeight: 240)
                        .padding()
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { isPresentingFilters && !isPad },
            set: { isPresentingFilters = $0 }
        )) {
            NavigationStack {
                filterForm
                    .navigationTitle("Filters")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                isPresentingFilters = false
                            }
                        }
                    }
            }.presentationDetents([.medium])
        }

    }

    private var listPane: some View {
        List {
            if !isLandscape {
                if showCharts && !items.isEmpty {
                    trendSection
                    totalsSection
                }
            }

            if items.isEmpty {
                emptyStateSection
            } else {
                if let groupingStyle {
                    ForEach(groupedItems) { section in
                        Section(sectionTitle(for: section.key, style: groupingStyle)) {
                            ForEach(section.value) { item in
                                NavigationLink {
                                    EditExpenseView(currencyCode: currencyCode, item: item)
                                } label: {
                                    ExpenseRow(item: item, currencyCode: currencyCode)
                                }
                            }
                            .onDelete { offsets in
                                deleteGroupedItems(section.value, offsets: offsets)
                            }
                        }
                    }
                } else {
                    ForEach(items) { item in
                        NavigationLink {
                            EditExpenseView(currencyCode: currencyCode, item: item)
                        } label: {
                            ExpenseRow(item: item, currencyCode: currencyCode)
                        }
                    }
                    .onDelete(perform: onDelete)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
    }

    private var leftSummaryPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if showCharts && !items.isEmpty {
                    trendCard
                    totalsCard
                }
                if items.isEmpty {
                    emptyStateSection
                }
            }
            .padding(16)
        }
    }

    private var trendSection: some View {
        Section("Expense Trend") {
            trendCard
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var totalsSection: some View {
        Section {
            totalsCard
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var trendCard: some View {
        Group {
            if expenseTrend.isEmpty {
                Text("No expense data for this period.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Chart(expenseTrend) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Total", point.total)
                        )
                        .foregroundStyle(.blue)
                    }
                    .chartXAxis(.hidden)
                    .frame(height: 180)
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var totalsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(periodTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(periodBalance, format: .currency(code: currencyCode))
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
            }

            HStack {
                Text("Income")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(periodIncome, format: .currency(code: currencyCode))
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Expense")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(periodExpense, format: .currency(code: currencyCode))
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var filterSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                if let selectedCategory = selectedCategory {
                    HStack {
                        Text("Filtered by \(selectedCategory.emoji) \(selectedCategory.name)")
                            .font(.subheadline)
                        Spacer()
                        Button("Clear") {
                            selectedCategoryId = nil
                            selectedAngle = nil
                        }
                        .font(.subheadline)
                    }
                }

                Picker("Type", selection: $filter) {
                    ForEach(TransactionFilter.allCases, id: \.self) { filter in
                        Text(filter.title)
                            .tag(filter)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Period", selection: $periodFilter) {
                    ForEach(PeriodFilter.allCases, id: \.self) { period in
                        Text(period.title)
                            .tag(period)
                    }
                }
                .pickerStyle(.segmented)

                Text(periodTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                switch periodFilter {
                case .custom:
                    DatePicker("Start", selection: $customStartDate, displayedComponents: [.date])
                    DatePicker("End", selection: $customEndDate, displayedComponents: [.date])
                case .day:
                    DatePicker("Date", selection: $periodAnchorDate, displayedComponents: [.date])
                        .datePickerStyle(.compact)
                case .week:
                    DatePicker("Week of", selection: $periodAnchorDate, displayedComponents: [.date])
                        .datePickerStyle(.compact)
                case .month:
                    DatePicker("Month", selection: $periodAnchorDate, displayedComponents: [.date])
                        .datePickerStyle(.compact)
                case .year:
                    DatePicker("Year", selection: $periodAnchorDate, displayedComponents: [.date])
                        .datePickerStyle(.compact)
                }
            }
        }
    }

    private var filterForm: some View {
        Form {
            filterSection
        }
    }

    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    private var emptyStateSection: some View {
        Section {
            ContentUnavailableView(
                "No entries yet",
                systemImage: "tray.and.arrow.down",
                description: Text("Add a new expense or income to get started.")
            )
        }
    }

    private var selectedCategory: Category? {
        guard let selectedCategoryId else { return nil }
        return categories.first { $0.id == selectedCategoryId }
    }

    private enum GroupingStyle {
        case day
        case month
    }

    private var groupingStyle: GroupingStyle? {
        switch periodFilter {
        case .week, .month:
            return .day
        case .year:
            return .month
        case .day, .custom:
            return nil
        }
    }

    private struct GroupedSection: Identifiable {
        let id = UUID()
        let key: Date
        let value: [Item]
    }

    private var groupedItems: [GroupedSection] {
        guard let groupingStyle else { return [] }
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: items) { item -> Date in
            switch groupingStyle {
            case .day:
                return calendar.startOfDay(for: item.date)
            case .month:
                let components = calendar.dateComponents([.year, .month], from: item.date)
                return calendar.date(from: components) ?? calendar.startOfDay(for: item.date)
            }
        }
        return grouped
            .map { GroupedSection(key: $0.key, value: $0.value) }
            .sorted { $0.key > $1.key }
    }

    private func sectionTitle(for date: Date, style: GroupingStyle) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        switch style {
        case .day:
            formatter.dateFormat = "EEE, MMM d"
        case .month:
            formatter.dateFormat = "LLLL yyyy"
        }
        return formatter.string(from: date)
    }

    private func deleteGroupedItems(_ sectionItems: [Item], offsets: IndexSet) {
        let indices: [Int] = offsets.compactMap { index in
            guard sectionItems.indices.contains(index) else { return nil }
            let item = sectionItems[index]
            return items.firstIndex(where: { $0.id == item.id })
        }
        if !indices.isEmpty {
            onDelete(IndexSet(indices))
        }
    }

    private func triggerHaptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

private struct ExpenseRow: View {
    let item: Item
    let currencyCode: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(item.category.color)
                .frame(width: 10, height: 10)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.merchant.isEmpty ? "Untitled" : item.merchant)
                    .font(.headline)
                Text("\(item.category.emoji) \(item.category.name)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if !item.shortDescription.isEmpty {
                    Text(item.shortDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !item.note.isEmpty {
                    Text(item.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(amountText)
                    .font(.headline)
                    .monospacedDigit()
                    .foregroundStyle(amountColor)
                Text(item.date, format: .dateTime.year().month().day())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var amountText: String {
        let formatted = item.amount.formatted(.currency(code: currencyCode))
        return item.type == .income ? "+\(formatted)" : "-\(formatted)"
    }

    private var amountColor: Color {
        item.type == .income ? .green : .primary
    }
}
