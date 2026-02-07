//
//  CategoryReassignView.swift
//  WonderSpend
//

import SwiftUI
import SwiftData

struct CategoryReassignRequest: Identifiable {
    let id = UUID()
    let category: Category
    let shouldDelete: Bool
}

struct CategoryReassignView: View {
    let category: Category
    let shouldDelete: Bool
    let onConfirm: (Category) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.name) private var categories: [Category]
    @Query private var items: [Item]

    @State private var selectedCategoryId: UUID?

    var body: some View {
        NavigationStack {
            Form {
                Section("Reassign to") {
                    if replacements.isEmpty {
                        Text("Create another category first.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Category", selection: $selectedCategoryId) {
                            ForEach(replacements) { replacement in
                                Text("\(replacement.emoji) \(replacement.name)")
                                    .tag(Optional(replacement.id))
                            }
                        }
                    }
                }

                Section("Summary") {
                    Text("Expenses affected: \(itemsToMove.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(shouldDelete ? "Delete \(category.name)" : "Reassign \(category.name)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmButtonTitle) {
                        guard let selectedCategory = selectedCategory else { return }
                        onConfirm(selectedCategory)
                        dismiss()
                    }
                    .disabled(selectedCategory == nil)
                }
            }
            .onAppear {
                if selectedCategoryId == nil {
                    selectedCategoryId = replacements.first?.id
                }
            }
        }
    }

    private var replacements: [Category] {
        categories.filter { $0.id != category.id }
    }

    private var itemsToMove: [Item] {
        items.filter { $0.category.id == category.id }
    }

    private var selectedCategory: Category? {
        guard let selectedCategoryId else { return nil }
        return replacements.first { $0.id == selectedCategoryId }
    }

    private var confirmButtonTitle: String {
        shouldDelete ? "Reassign & Delete" : "Reassign"
    }
}
