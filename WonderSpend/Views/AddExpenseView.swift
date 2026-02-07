//
//  AddExpenseView.swift
//  WonderSpend
//

import SwiftUI
import SwiftData

struct AddExpenseView: View {
    let currencyCode: String
    let aiParsingEnabled: Bool
    let onSave: (Item) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.name) private var categories: [Category]

    @State private var amount: Double = 0
    @State private var date = Date()
    @State private var selectedCategoryId: UUID?
    @State private var type: TransactionType = .expense
    @State private var shortDescription = ""
    @State private var note = ""
    @State private var merchant = ""
    @State private var multiInput = ""
    @State private var multiDrafts: [ExpenseDraft] = []
    @State private var isAnalyzing = false
    @State private var analysisErrorMessage: String?

    private let draft: ExpenseDraft?
    @State private var inputMode: InputMode = .single

    init(
        currencyCode: String,
        aiParsingEnabled: Bool,
        draft: ExpenseDraft? = nil,
        onSave: @escaping (Item) -> Void
    ) {
        self.currencyCode = currencyCode
        self.aiParsingEnabled = aiParsingEnabled
        self.draft = draft
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Input Mode") {
                    Picker("Input Mode", selection: $inputMode) {
                        ForEach(InputMode.allCases, id: \.self) { mode in
                            Text(mode.title)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if inputMode == .single {
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
                        if categories.isEmpty {
                            Text("Add a category first.")
                                .foregroundStyle(.secondary)
                        } else {
                            Picker("Category", selection: $selectedCategoryId) {
                                ForEach(categories) { category in
                                    Text("\(category.emoji) \(category.name)")
                                        .tag(Optional(category.id))
                                }
                            }
                        }
                        DatePicker("Date", selection: $date, displayedComponents: [.date])
                    }

                    Section("Note") {
                        TextField("Optional note", text: $note, axis: .vertical)
                            .lineLimit(1...3)
                    }
                } else {
                    Section("Quick Add") {
                        TextEditor(text: $multiInput)
                            .frame(minHeight: 120)
                            .overlay(alignment: .topLeading) {
                                if multiInput.isEmpty {
                                    Text("e.g. Yesterday coffee 35; Lunch 68; Salary 12000")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 8)
                                        .padding(.leading, 4)
                                }
                            }
                        Button {
                            Task {
                                await analyzeMultiInput()
                            }
                        } label: {
                            if isAnalyzing {
                                ProgressView()
                            } else {
                                Text("Analyze Multiple Entries")
                            }
                        }
                        .disabled(!aiParsingEnabled || multiInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAnalyzing)

                        if !aiParsingEnabled {
                            Text("Enable Apple Intelligence in Settings to analyze multi-entry input.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !multiDrafts.isEmpty {
                        Section("Suggested Entries") {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(Array(multiDrafts.enumerated()), id: \.offset) { index, draft in
                                        suggestedCard(draft, index: index)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .frame(maxHeight: 240)
                            .scrollIndicators(.visible)
                        }
                    }
                }
            }
            .navigationTitle("New Expense")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        triggerHaptic()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if inputMode == .single {
                        Button("Save") {
                            triggerHaptic()
                            guard let selectedCategory = selectedCategory else { return }
                            let newItem = Item(
                                amount: amount,
                                date: date,
                                category: selectedCategory,
                                shortDescription: shortDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                                note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                                merchant: merchant.trimmingCharacters(in: .whitespacesAndNewlines),
                                type: type
                            )
                            onSave(newItem)
                            dismiss()
                        }
                        .disabled(!canSave)
                    } else {
                        Button("Create All") {
                            triggerHaptic()
                            createAllDrafts()
                            dismiss()
                        }
                        .disabled(multiDrafts.isEmpty)
                    }
                }
            }
            .onAppear {
                applyDraftIfNeeded()
                if selectedCategoryId == nil {
                    selectedCategoryId = categories.first?.id
                }
            }
            .onChange(of: categories) { _, _ in
                if selectedCategoryId == nil {
                    selectedCategoryId = categories.first?.id
                }
            }
            .alert("Couldn’t analyze input", isPresented: isShowingAnalysisError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(analysisErrorMessage ?? "Please try again.")
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

    private var isShowingAnalysisError: Binding<Bool> {
        Binding(
            get: { analysisErrorMessage != nil },
            set: { newValue in
                if !newValue {
                    analysisErrorMessage = nil
                }
            }
        )
    }

    @MainActor
    private func analyzeMultiInput() async {
        let trimmed = multiInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard aiParsingEnabled else {
            analysisErrorMessage = "Enable Apple Intelligence in Settings."
            return
        }

        isAnalyzing = true
        defer { isAnalyzing = false }

        do {
            let suggestions = try await ExpenseLanguageInterpreter.suggestMultiple(
                from: trimmed,
                categories: categories
            )
            guard !suggestions.isEmpty else {
                analysisErrorMessage = "No transactions were detected."
                return
            }
            var availableCategories = categories
            let newDrafts = suggestions.map { suggestion -> ExpenseDraft in
                let categoryId = resolveSuggestedCategory(suggestion, categories: &availableCategories)
                return ExpenseDraft(
                    amount: suggestion.amount ?? 0,
                    date: suggestion.date ?? Date(),
                    categoryId: categoryId,
                    type: suggestion.type ?? .expense,
                    shortDescription: suggestion.shortDescription ?? "",
                    note: "",
                    merchant: suggestion.merchant ?? ""
                )
            }
            withAnimation {
                multiDrafts = newDrafts
            }
        } catch {
            analysisErrorMessage = error.localizedDescription
        }
    }

    private func resolveSuggestedCategory(_ suggestion: ExpenseSuggestion, categories: inout [Category]) -> UUID? {
        if let categoryId = suggestion.categoryId {
            return categoryId
        }

        guard let name = suggestion.categoryName, !name.isEmpty else { return categories.first?.id }
        if let existing = categories.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return existing.id
        }

        let newCategory = Category(
            name: name,
            emoji: "🧾",
            colorHex: CategoryColorPalette.colorHex(for: name)
        )
        modelContext.insert(newCategory)
        categories.append(newCategory)
        return newCategory.id
    }

    private func suggestedCard(_ draft: ExpenseDraft, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(draft.type.title)
                Spacer()
                Text(draft.amount, format: .currency(code: currencyCode))
            }
            if let categoryName = categoryName(for: draft.categoryId) {
                Text("Category: \(categoryName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(draft.date, format: .dateTime.year().month().day())
                .font(.caption)
                .foregroundStyle(.secondary)
            if !draft.shortDescription.isEmpty {
                Text("“\(draft.shortDescription)”")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Button("Create") {
                    createDraft(at: index)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canCreate(draft: draft))
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func categoryName(for id: UUID?) -> String? {
        guard let id else { return nil }
        return categories.first { $0.id == id }.map { "\($0.emoji) \($0.name)" }
    }

    private func createDraft(at index: Int) {
        guard multiDrafts.indices.contains(index) else { return }
        let draft = multiDrafts[index]
        createItem(from: draft)
        multiDrafts.remove(at: index)
    }

    private func createAllDrafts() {
        multiDrafts.forEach { createItem(from: $0) }
        multiDrafts.removeAll()
    }

    private func createItem(from draft: ExpenseDraft) {
        guard let categoryId = draft.categoryId,
              let category = categories.first(where: { $0.id == categoryId }) else { return }
        let item = Item(
            amount: draft.amount,
            date: draft.date,
            category: category,
            shortDescription: draft.shortDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            note: draft.note.trimmingCharacters(in: .whitespacesAndNewlines),
            merchant: draft.merchant.trimmingCharacters(in: .whitespacesAndNewlines),
            type: draft.type
        )
        onSave(item)
    }

    private func canCreate(draft: ExpenseDraft) -> Bool {
        draft.amount > 0 && draft.categoryId != nil
    }

    private func applyDraftIfNeeded() {
        guard let draft else { return }
        inputMode = .single
        amount = draft.amount
        date = draft.date
        selectedCategoryId = draft.categoryId
        type = draft.type
        shortDescription = draft.shortDescription
        note = draft.note
        merchant = draft.merchant
    }

    private func triggerHaptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

private enum InputMode: String, CaseIterable {
    case single
    case multi

    var title: String {
        switch self {
        case .single:
            return "Manual"
        case .multi:
            return "Quick Add"
        }
    }
}
