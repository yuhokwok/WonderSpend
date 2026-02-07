//
//  CategoryChartView.swift
//  WonderSpend
//

import Charts
import SwiftUI

struct CategoryChartView: View {
    let totals: [CategoryTotal]
    let currencyCode: String
    @Binding var selectedCategoryId: UUID?
    @Binding var selectedAngle: Double?
    let showsSectionHeader: Bool
    let title: String

    var body: some View {
        let content = VStack(alignment: .leading, spacing: 12) {
            if totals.isEmpty {
                Text("No \(title.lowercased()) this month.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(totals) { entry in
                    SectorMark(
                        angle: .value("Amount", entry.total),
                        innerRadius: .ratio(0.55),
                        angularInset: 1.5
                    )
                    .foregroundStyle(entry.category.color)
                }
                .frame(height: 220)
                .chartAngleSelection(value: $selectedAngle)
                .onChange(of: selectedAngle) { _, _ in
                    updateSelectedCategoryFromAngle()
                }

                ForEach(totals) { entry in
                    Button {
                        selectedCategoryId = entry.category.id
                    } label: {
                        HStack {
                            Circle()
                                .fill(entry.category.color)
                                .frame(width: 10, height: 10)
                            Text("\(entry.category.emoji) \(entry.category.name)")
                                .font(.callout)
                            Spacer()
                            Text(entry.total, format: .currency(code: currencyCode))
                                .font(.callout)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        if showsSectionHeader {
            Section(title) {
                content
            }
        } else {
            content
        }
    }

    private func updateSelectedCategoryFromAngle() {
        guard let selectedAngle else {
            selectedCategoryId = nil
            return
        }

        var runningTotal: Double = 0
        for entry in totals {
            runningTotal += entry.total
            if selectedAngle <= runningTotal {
                selectedCategoryId = entry.category.id
                return
            }
        }
    }
}
