//
//  ContentView.swift
//  WonderSpend
//
//  Created by Yu Ho Kwok on 2/5/26.
//

import SwiftUI
import SwiftData
import UIKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.date, order: .reverse) private var items: [Item]
    @Query(sort: \Category.name) private var categories: [Category]

    @AppStorage("userName") private var userName = ""
    @AppStorage("aiParsingEnabled") private var aiParsingEnabled = true
    @AppStorage("speechLanguage") private var speechLanguage = "en-US"

    @State private var isPresentingAddExpense = false
    @State private var isPresentingManageCategories = false
    @State private var isPresentingQuickAdd = false
    @State private var quickAddAutoStart = false
    @StateObject private var speechModel = SpeechQuickAddModel(localeIdentifier: "en-US")
    @State private var speechDrafts: [ExpenseDraft] = []
    @State private var isSpeechListening = false
    @State private var isSpeechAnalyzing = false
    @State private var speechErrorMessage: String?
    @State private var isSpeechCancelling = false
    @State private var suppressSpeechTap = false
    @State private var isSpeechHolding = false
    @StateObject private var viewModel = ExpenseListViewModel()
    @Namespace private var quickAddNamespace

    private let currencyCode = "HKD"

    var body: some View {
        GeometryReader { proxy in
            let isPadLandscape = UIDevice.current.userInterfaceIdiom == .pad
                && proxy.size.width > proxy.size.height
            let isLandscape = proxy.size.width > proxy.size.height
            let overlayBottomPadding: CGFloat = isPadLandscape ? 90 : 120

            ZStack(alignment: .bottom) {
                MainTabView(
                    items: periodItems,
                    categories: categories,
                    currencyCode: currencyCode,
                    navigationTitle: navigationTitle,
                    isLandscape: isLandscape,
                    periodTitle: viewModel.periodTitle(),
                    periodIncome: periodIncome,
                    periodExpense: periodExpense,
                    periodBalance: periodBalance,
                    expenseTrend: viewModel.expenseTrend(from: items),
                    categoryTotalsExpense: categoryTotals(for: .expense),
                    selectedCategoryId: $viewModel.selectedCategoryId,
                    selectedAngle: $viewModel.selectedAngle,
                    filter: $viewModel.filter,
                    periodFilter: $viewModel.periodFilter,
                    periodAnchorDate: $viewModel.periodAnchorDate,
                    customStartDate: $viewModel.customStartDate,
                    customEndDate: $viewModel.customEndDate,
                    onAddExpense: { isPresentingAddExpense = true },
                    onManageCategories: { isPresentingManageCategories = true },
                    onDelete: deleteItems,
                    settingsDestination: SettingsView(
                        userName: $userName,
                        aiParsingEnabled: $aiParsingEnabled,
                        speechLanguage: $speechLanguage
                    )
                )
                .sheet(isPresented: $isPresentingAddExpense) {
                    AddExpenseView(
                        currencyCode: currencyCode,
                        aiParsingEnabled: aiParsingEnabled
                    ) { newItem in
                        modelContext.insert(newItem)
                    }
                }
                .sheet(isPresented: $isPresentingManageCategories) {
                    ManageCategoriesView()
                }
                if shouldShowSpeechOverlay {
                    SpeechOverlayView(
                        isListening: isSpeechListening,
                        isAnalyzing: isSpeechAnalyzing,
                        transcript: speechModel.transcript,
                        isCancelling: isSpeechCancelling,
                        errorMessage: speechErrorMessage ?? speechModel.errorMessage,
                        drafts: speechDrafts,
                        currencyCode: currencyCode,
                        categories: categories,
                        onCreate: createSpeechDraft,
                        onCreateAll: createAllSpeechDrafts,
                        onDismiss: dismissSpeechOverlay
                    )
                    .padding(.bottom, overlayBottomPadding)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                speechFloatingButton

                if isPresentingQuickAdd {
                    quickAddOverlay
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .task {
                seedDefaultCategoriesIfNeeded()
            }
            .onAppear {
                speechModel.updateLocale(identifier: speechLanguage)
            }
            .onChange(of: speechLanguage) { _, newValue in
                speechModel.updateLocale(identifier: newValue)
            }
        }
    }

    private var speechFloatingButton: some View {
        let size: CGFloat = 64
        let radius = size / 2
        let center = CGPoint(x: size / 2, y: size / 2)

        return buttonContent
            .matchedGeometryEffect(id: "quickAddBubble", in: quickAddNamespace)
            .frame(width: size, height: size)
            .contentShape(Circle())
            .accessibilityLabel("Hold to quick add")
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isSpeechHolding {
                            isSpeechHolding = true
                            suppressSpeechTap = true
                            startSpeechHold()
                        }
                        let distance = hypot(value.location.x - center.x, value.location.y - center.y)
                        let nowCancelling = distance > radius
                        if nowCancelling != isSpeechCancelling {
                            isSpeechCancelling = nowCancelling
                        }
                    }
                    .onEnded { _ in
                        if isSpeechHolding {
                            endSpeechHold(cancelled: isSpeechCancelling)
                        }
                        isSpeechHolding = false
                        if isSpeechCancelling {
                            isSpeechCancelling = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            suppressSpeechTap = false
                        }
                    }
            )
            .simultaneousGesture(
                TapGesture()
                    .onEnded {
                        guard !suppressSpeechTap else { return }
                        quickAddAutoStart = false
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            isPresentingQuickAdd = true
                        }
                    }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.trailing, 20)
            .padding(.bottom, 32)
    }

    private var quickAddOverlay: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        isPresentingQuickAdd = false
                    }
                }

            QuickAddView(
                currencyCode: currencyCode,
                aiParsingEnabled: aiParsingEnabled,
                speechLanguage: speechLanguage,
                autoStartListening: quickAddAutoStart,
                onSave: { newItem in
                    modelContext.insert(newItem)
                },
                onDismiss: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        isPresentingQuickAdd = false
                    }
                }
            )
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .matchedGeometryEffect(id: "quickAddBubble", in: quickAddNamespace)
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.top, 40)
            .padding(.bottom, 24)
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var buttonContent: some View {
        if #available(iOS 18.0, *) {
            Image(systemName: "waveform.circle.fill")
                .foregroundStyle(.white)
                .font(.system(size: 48))
                .padding(6)
                .glassEffect(.regular.tint(.blue).interactive(), in: .circle)
                .shadow(radius: 6, y: 4)
                .offset(y: 45)
        } else {
            Image(systemName: "waveform.circle.fill")
                .foregroundStyle(.white)
                .font(.system(size: 52))
                .foregroundStyle(.white, .blue)
                .shadow(radius: 6, y: 4)
                .offset(y: 45)
        }
    }

    private var periodIncome: Double {
        viewModel.periodIncome(from: items)
    }

    private var periodExpense: Double {
        viewModel.periodExpense(from: items)
    }

    private var periodBalance: Double {
        viewModel.periodBalance(from: items)
    }

    private var periodItems: [Item] {
        viewModel.periodItems(from: items)
    }

    private func categoryTotals(for type: TransactionType) -> [CategoryTotal] {
        viewModel.categoryTotals(for: type, from: items)
    }

    private func seedDefaultCategoriesIfNeeded() {
        guard categories.isEmpty else { return }

        let defaults: [(String, String, String)] = [
            ("General", "🧾", "#4A5568"),
            ("Food", "🍜", "#DD6B20"),
            ("Transport", "🚇", "#2B6CB0"),
            ("Shopping", "🛍️", "#D53F8C"),
            ("Bills", "💡", "#805AD5"),
            ("Health", "🧘", "#38A169"),
            ("Entertainment", "🎬", "#D69E2E"),
            ("Travel", "✈️", "#319795")
        ]

        for entry in defaults {
            let category = Category(name: entry.0, emoji: entry.1, colorHex: entry.2)
            modelContext.insert(category)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(periodItems[index])
            }
        }
    }

    private var shouldShowSpeechOverlay: Bool {
        isSpeechListening || isSpeechAnalyzing || !speechDrafts.isEmpty || speechErrorMessage != nil || speechModel.errorMessage != nil
    }

    private func startSpeechHold() {
        guard !isSpeechListening else { return }
        speechErrorMessage = nil
        speechDrafts = []
        speechModel.transcript = ""
        speechModel.errorMessage = nil
        isSpeechListening = true
        Task {
            await speechModel.start()
            if speechModel.errorMessage != nil {
                isSpeechListening = false
            }
        }
    }

    private func endSpeechHold(cancelled: Bool) {
        guard isSpeechListening else { return }
        isSpeechListening = false
        Task {
            await speechModel.stop()
            if cancelled {
                isPresentingQuickAdd = false
                dismissSpeechOverlay()
                return
            }
            await analyzeSpeechTranscript()
        }
    }

    @MainActor
    private func analyzeSpeechTranscript() async {
        let text = speechModel.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard aiParsingEnabled else {
            speechErrorMessage = "Enable Apple Intelligence in Settings."
            return
        }

        isSpeechAnalyzing = true
        defer { isSpeechAnalyzing = false }

        do {
            let suggestions = try await ExpenseLanguageInterpreter.suggestMultiple(
                from: text,
                categories: categories
            )
            guard !suggestions.isEmpty else {
                speechErrorMessage = "No transactions were detected."
                return
            }
            var availableCategories = categories
            let drafts = suggestions.map { suggestion -> ExpenseDraft in
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
                speechDrafts = drafts
            }
        } catch {
            speechErrorMessage = error.localizedDescription
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

    private func createSpeechDraft(_ draft: ExpenseDraft) {
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
        modelContext.insert(item)
        speechDrafts.removeAll(where: { $0.amount == draft.amount && $0.date == draft.date && $0.categoryId == draft.categoryId })
        if speechDrafts.isEmpty {
            dismissSpeechOverlay()
        }
    }

    private func createAllSpeechDrafts() {
        let draftsToCreate = speechDrafts
        draftsToCreate.forEach { draft in
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
            modelContext.insert(item)
        }
        dismissSpeechOverlay()
    }

    private func dismissSpeechOverlay() {
        speechDrafts = []
        speechErrorMessage = nil
        isSpeechCancelling = false
        speechModel.transcript = ""
    }

    private var navigationTitle: String {
        let trimmed = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "WonderSpend" : "Hi, \(trimmed)"
    }

    private var periodTitle: String {
        viewModel.periodTitle()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Category.self, Item.self], inMemory: true)
}
