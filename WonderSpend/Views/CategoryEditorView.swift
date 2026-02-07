//
//  CategoryEditorView.swift
//  WonderSpend
//

import SwiftUI
import SwiftData

struct CategoryEditorView: View {
    let category: Category?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name: String
    @State private var emoji: String
    @State private var color: Color

    init(category: Category?) {
        self.category = category
        _name = State(initialValue: category?.name ?? "")
        _emoji = State(initialValue: category?.emoji ?? "")
        _color = State(initialValue: category?.color ?? Color.blue)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $name)
                    TextField("Emoji", text: $emoji)
                    ColorPicker("Color", selection: $color, supportsOpacity: false)
                }
            }
            .navigationTitle(category == nil ? "New Category" : "Edit Category")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCategory()
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func saveCategory() {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedEmoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        let storedEmoji = cleanedEmoji.isEmpty ? "🧾" : String(cleanedEmoji.prefix(2))
        let colorHex = color.hexString

        if let category {
            category.name = cleanedName
            category.emoji = storedEmoji
            category.colorHex = colorHex
        } else {
            let newCategory = Category(name: cleanedName, emoji: storedEmoji, colorHex: colorHex)
            modelContext.insert(newCategory)
        }
    }
}
