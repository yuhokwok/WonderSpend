//
//  QuickAddView.swift
//  WonderSpend
//

import SwiftUI
import SwiftData

struct QuickAddView: View {
    let currencyCode: String
    let aiParsingEnabled: Bool
    let speechLanguage: String
    let autoStartListening: Bool
    let onSave: (Item) -> Void
    let onDismiss: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.name) private var categories: [Category]

    @StateObject private var speechModel: SpeechQuickAddModel
    @State private var drafts: [ExpenseDraft] = []
    @State private var reviewDraft: ExpenseDraft?
    @State private var isPresentingReview = false
    @State private var analysisErrorMessage: String?
    @State private var isAnalyzing = false
    @State private var isListening = false

    init(
        currencyCode: String,
        aiParsingEnabled: Bool,
        speechLanguage: String,
        autoStartListening: Bool,
        onSave: @escaping (Item) -> Void,
        onDismiss: (() -> Void)? = nil
    ) {
        self.currencyCode = currencyCode
        self.aiParsingEnabled = aiParsingEnabled
        self.speechLanguage = speechLanguage
        self.autoStartListening = autoStartListening
        self.onSave = onSave
        self.onDismiss = onDismiss
        _speechModel = StateObject(wrappedValue: SpeechQuickAddModel(localeIdentifier: speechLanguage))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Quick Add")
                    .font(.title2)
                    .bold()

                Text("Hold the floating button to speak, or tap the mic.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                micButton

                if isListening {
                    bubble(text: "Listening…", isProminent: true)
                        .transition(.opacity.combined(with: .scale))
                } else if isAnalyzing {
                    bubble(text: "Analyzing…", isProminent: false)
                        .transition(.opacity.combined(with: .scale))
                } else if !drafts.isEmpty {
                    ScrollView {
                        suggestedList
                            .padding(.vertical, 8)
                    }
                    .frame(maxHeight: 260)
                    .scrollIndicators(.visible)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                if let speechError = speechModel.errorMessage {
                    Text(speechError)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }

                if !speechModel.transcript.isEmpty {
                    Text(speechModel.transcript)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                }

                if !aiParsingEnabled {
                    Text("Enable Apple Intelligence in Settings to analyze speech.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle("Quick Add")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        performDismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Analyze") {
                        Task {
                            await analyzeTranscript()
                        }
                    }
                    .disabled(!aiParsingEnabled || speechModel.transcript.isEmpty || isAnalyzing)
                }
            }
            .overlay(alignment: .bottom) {
                if !drafts.isEmpty {
                    HStack {
                        if drafts.count == 1, let draft = drafts.first {
                            Button("Review & Edit") {
                                triggerHaptic()
                                reviewDraft = draft
                                isPresentingReview = true
                            }
                            .buttonStyle(.bordered)

                            Button("Create") {
                                triggerHaptic()
                                createItem(from: draft)
                                performDismiss()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!canCreate(from: draft))
                        } else {
                            Button("Create All") {
                                triggerHaptic()
                                createAllDrafts()
                                performDismiss()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                }
            }
            .sheet(isPresented: $isPresentingReview) {
                AddExpenseView(
                    currencyCode: currencyCode,
                    aiParsingEnabled: aiParsingEnabled,
                    draft: reviewDraft
                ) { newItem in
                    onSave(newItem)
                    removeDraft(matching: reviewDraft)
                }
            }
            .alert("Quick Add Error", isPresented: isShowingAnalysisError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(analysisErrorMessage ?? "Please try again.")
            }
            .onChange(of: speechModel.transcript) { _, _ in
                if !drafts.isEmpty || reviewDraft != nil {
                    drafts = []
                    reviewDraft = nil
                }
            }
            .onChange(of: speechLanguage) { _, newValue in
                speechModel.updateLocale(identifier: newValue)
            }
            .onAppear {
                if autoStartListening {
                    isListening = true
                    Task { await speechModel.start() }
                }
            }
        }
    }

    private var micButton: some View {
        Button {
            Task {
                if speechModel.isRecording {
                    isListening = false
                    await speechModel.stop()
                    await analyzeTranscript()
                } else {
                    isListening = true
                    await speechModel.start()
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(speechModel.isRecording ? Color.red : Color.blue)
                    .frame(width: 86, height: 86)
                Image(systemName: speechModel.isRecording ? "waveform" : "mic.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .accessibilityLabel(speechModel.isRecording ? "Stop recording" : "Start recording")
    }

    private var suggestedList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(drafts.count == 1 ? "Suggested" : "Suggested (\(drafts.count))")
                .font(.headline)

            ForEach(Array(drafts.enumerated()), id: \.offset) { index, draft in
                suggestedCard(draft, index: index)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
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
                Button("Review") {
                    triggerHaptic()
                    reviewDraft = draft
                    isPresentingReview = true
                }
                .buttonStyle(.bordered)

                Button("Create") {
                    triggerHaptic()
                    createDraft(at: index)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canCreate(from: draft))
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func bubble(text: String, isProminent: Bool) -> some View {
        Text(text)
            .font(isProminent ? .headline : .subheadline)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(.thinMaterial, in: Capsule())
    }

    @MainActor
    private func analyzeTranscript() async {
        let text = speechModel.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard aiParsingEnabled else {
            analysisErrorMessage = "Enable Apple Intelligence in Settings."
            return
        }

        isAnalyzing = true
        defer { isAnalyzing = false }

        do {
            let suggestions = try await ExpenseLanguageInterpreter.suggestMultiple(
                from: text,
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
                drafts = newDrafts
            }
        } catch {
            analysisErrorMessage = error.localizedDescription
        }
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

    private func categoryName(for id: UUID?) -> String? {
        guard let id else { return nil }
        return categories.first { $0.id == id }.map { "\($0.emoji) \($0.name)" }
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

    private func canCreate(from draft: ExpenseDraft) -> Bool {
        draft.amount > 0 && draft.categoryId != nil
    }

    private func triggerHaptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func removeDraft(matching draft: ExpenseDraft?) {
        guard let draft else { return }
        if let index = drafts.firstIndex(where: { existing in
            existing.amount == draft.amount
                && existing.date == draft.date
                && existing.categoryId == draft.categoryId
                && existing.type == draft.type
                && existing.shortDescription == draft.shortDescription
                && existing.note == draft.note
                && existing.merchant == draft.merchant
        }) {
            drafts.remove(at: index)
            if drafts.isEmpty {
                performDismiss()
            }
        }
        reviewDraft = nil
    }

    private func createDraft(at index: Int) {
        guard drafts.indices.contains(index) else { return }
        let draft = drafts[index]
        createItem(from: draft)
        drafts.remove(at: index)
        if drafts.isEmpty {
            performDismiss()
        }
    }

    private func createAllDrafts() {
        drafts.forEach { createItem(from: $0) }
        drafts.removeAll()
    }

    private func performDismiss() {
        if let onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }
}
