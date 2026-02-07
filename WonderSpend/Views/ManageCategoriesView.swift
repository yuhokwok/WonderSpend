//
//  ManageCategoriesView.swift
//  WonderSpend
//

import SwiftUI
import SwiftData

struct ManageCategoriesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.name) private var categories: [Category]
    @Query private var items: [Item]

    @State private var isPresentingEditor = false
    @State private var editingCategory: Category?
    @State private var reassignRequest: CategoryReassignRequest?
    @State private var deleteBlockedMessage: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach(categories) { category in
                    let isUsed = items.contains { $0.category.id == category.id }
                    Button {
                        editingCategory = category
                        isPresentingEditor = true
                    } label: {
                        HStack {
                            Circle()
                                .fill(category.color)
                                .frame(width: 12, height: 12)
                            Text("\(category.emoji) \(category.name)")
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions(allowsFullSwipe: false) {
                        if isUsed {
                            Button("Reassign to...") {
                                reassignRequest = CategoryReassignRequest(
                                    category: category,
                                    shouldDelete: false
                                )
                            }
                            .tint(.blue)
                        }
                    }
                }
                .onDelete(perform: deleteCategories)
            }
            .navigationTitle("Categories")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        editingCategory = nil
                        isPresentingEditor = true
                    } label: {
                        Label("Add Category", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isPresentingEditor) {
                CategoryEditorView(category: editingCategory)
            }
            .sheet(item: $reassignRequest) { request in
                CategoryReassignView(
                    category: request.category,
                    shouldDelete: request.shouldDelete
                ) { replacement in
                    reassignItems(from: request.category, to: replacement)
                    if request.shouldDelete {
                        modelContext.delete(request.category)
                    }
                }
            }
            .alert("Unable to delete", isPresented: isShowingDeleteBlocked) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(deleteBlockedMessage ?? "Add another category before deleting this one.")
            }
        }
    }

    private var isShowingDeleteBlocked: Binding<Bool> {
        Binding(
            get: { deleteBlockedMessage != nil },
            set: { newValue in
                if !newValue {
                    deleteBlockedMessage = nil
                }
            }
        )
    }

    private func deleteCategories(offsets: IndexSet) {
        for index in offsets {
            let category = categories[index]
            let isUsed = items.contains { $0.category.id == category.id }
            let alternatives = categories.filter { $0.id != category.id }

            if isUsed && alternatives.isEmpty {
                deleteBlockedMessage = "Add another category before deleting \(category.name)."
                return
            }

            if isUsed {
                reassignRequest = CategoryReassignRequest(
                    category: category,
                    shouldDelete: true
                )
            } else {
                modelContext.delete(category)
            }
        }
    }

    private func reassignItems(from category: Category, to replacement: Category) {
        for item in items where item.category.id == category.id {
            item.category = replacement
        }
    }
}
