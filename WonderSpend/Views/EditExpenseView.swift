//
//  EditExpenseView.swift
//  WonderSpend
//

import SwiftUI
import SwiftData

struct EditExpenseView: View {
    let currencyCode: String
    let item: Item

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.name) private var categories: [Category]

    @State private var amount: Double
    @State private var date: Date
    @State private var selectedCategoryId: UUID?
    @State private var type: TransactionType
    @State private var shortDescription: String
    @State private var note: String
    @State private var merchant: String

    init(currencyCode: String, item: Item) {
        self.currencyCode = currencyCode
        self.item = item
        _amount = State(initialValue: item.amount)
        _date = State(initialValue: item.date)
        _selectedCategoryId = State(initialValue: item.category.id)
        _type = State(initialValue: item.type)
        _shortDescription = State(initialValue: item.shortDescription)
        _note = State(initialValue: item.note)
        _merchant = State(initialValue: item.merchant)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    TextField(
                        "0.00",
                        value: $amount,
                        format: .currency(code: currencyCode)
                    )
                    .keyboardType(.decimalPad)
                }

                Section("Details") {
                    TextField("Merchant", text: $merchant)
                    TextField("Short Description", text: $shortDescription)
                    Picker("Type", selection: $type) {
                        ForEach(TransactionType.allCases, id: \.self) { type in
                            Text(type.title)
                                .tag(type)
                        }
                    }
                    Picker("Category", selection: $selectedCategoryId) {
                        ForEach(categories) { category in
                            Text("\(category.emoji) \(category.name)")
                                .tag(Optional(category.id))
                        }
                    }
                    DatePicker("Date", selection: $date, displayedComponents: [.date])
                }

                Section("Note") {
                    TextField("Optional note", text: $note, axis: .vertical)
                        .lineLimit(1...3)
                }
            }
            .navigationTitle("Edit Expense")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let selectedCategory = selectedCategory else { return }
                        item.amount = amount
                        item.date = date
                        item.category = selectedCategory
                        item.shortDescription = shortDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                        item.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
                        item.merchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
                        item.type = type
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .onChange(of: categories) { _, _ in
                if selectedCategoryId == nil {
                    selectedCategoryId = categories.first?.id
                }
            }
        }
    }

    private var selectedCategory: Category? {
        guard let selectedCategoryId else { return nil }
        return categories.first { $0.id == selectedCategoryId }
    }

    private var canSave: Bool {
        amount > 0 && selectedCategory != nil
    }
}
