//
//  InsightsView.swift
//  WonderSpend
//

import SwiftUI
import UIKit

struct InsightsView: View {
    let itemsEmpty: Bool
    let currencyCode: String
    let periodTitle: String
    let periodIncome: Double
    let periodExpense: Double
    let periodBalance: Double
    let categoryTotalsExpense: [CategoryTotal]
    @Binding var selectedCategoryId: UUID?
    @Binding var selectedAngle: Double?
    @Binding var periodFilter: PeriodFilter
    @Binding var periodAnchorDate: Date
    @Binding var customStartDate: Date
    @Binding var customEndDate: Date

    var body: some View {
        Group {
            if itemsEmpty {
                ContentUnavailableView(
                    "No expenses yet",
                    systemImage: "chart.pie",
                    description: Text("Add an expense to see your category breakdown.")
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        filterCard
                        totalsCard
                        CategoryChartView(
                            totals: categoryTotalsExpense,
                            currencyCode: currencyCode,
                            selectedCategoryId: $selectedCategoryId,
                            selectedAngle: $selectedAngle,
                            showsSectionHeader: false,
                            title: "Expenses"
                        )
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Insights")
        .background(Color(.systemGroupedBackground))
    }

    private var filterCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time Range")
                .font(.headline)

            Picker("Period", selection: $periodFilter) {
                ForEach(PeriodFilter.allCases, id: \.self) { period in
                    Text(period.title)
                        .tag(period)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: periodFilter) { _, _ in
                triggerHaptic()
            }

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

    private func triggerHaptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
