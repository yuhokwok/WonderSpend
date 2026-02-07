//
//  SpeechOverlayView.swift
//  WonderSpend
//

import SwiftUI
import UIKit

struct SpeechOverlayView: View {
    let isListening: Bool
    let isAnalyzing: Bool
    let transcript: String
    let isCancelling: Bool
    let errorMessage: String?
    let drafts: [ExpenseDraft]
    let currencyCode: String
    let categories: [Category]
    let onCreate: (ExpenseDraft) -> Void
    let onCreateAll: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            header

            if isListening {
                statusBubble(text: "Listening…", prominent: true)
            }

            if !transcript.isEmpty {
                statusBubble(text: transcript, prominent: false)
            }

            if isCancelling {
                statusBubble(text: "Release to cancel", prominent: true)
                    .foregroundStyle(.red)
            }

            if isAnalyzing {
                statusBubble(text: "Analyzing…", prominent: false)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if !drafts.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(drafts.enumerated()), id: \.offset) { index, draft in
                            suggestedCard(draft, index: index)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 260)
                .scrollIndicators(.visible)

                if drafts.count > 1 {
                    Button("Create All") {
                        triggerHaptic()
                        onCreateAll()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: 360)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .shadow(radius: 8, y: 6)
        .padding(.horizontal, 16)
    }

    private var header: some View {
        HStack {
            Text("Quick Add")
                .font(.headline)
            Spacer()
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func statusBubble(text: String, prominent: Bool) -> some View {
        Text(text)
            .font(prominent ? .headline : .subheadline)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func suggestedCard(_ draft: ExpenseDraft, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
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
            Button("Create") {
                triggerHaptic()
                onCreate(draft)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func categoryName(for id: UUID?) -> String? {
        guard let id else { return nil }
        return categories.first { $0.id == id }.map { "\($0.emoji) \($0.name)" }
    }

    private func triggerHaptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
