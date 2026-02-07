//
//  SettingsView.swift
//  WonderSpend
//

import SwiftUI

struct SettingsView: View {
    @Binding var userName: String
    @Binding var aiParsingEnabled: Bool
    @Binding var speechLanguage: String
    @Environment(\.dismiss) private var dismiss
    @State private var nameInput: String

    init(
        userName: Binding<String>,
        aiParsingEnabled: Binding<Bool>,
        speechLanguage: Binding<String>
    ) {
        _userName = userName
        _aiParsingEnabled = aiParsingEnabled
        _speechLanguage = speechLanguage
        _nameInput = State(initialValue: userName.wrappedValue)
    }

    var body: some View {
        Form {
            Section("Profile") {
                TextField("Name", text: $nameInput)
            }

            Section("Apple Intelligence") {
                Toggle("Enable Quick Add Parsing", isOn: $aiParsingEnabled)
            }

            Section("Speech") {
                Picker("Language", selection: $speechLanguage) {
                    ForEach(SpeechLanguageOption.allCases, id: \.self) { option in
                        Text(option.title)
                            .tag(option.rawValue)
                    }
                }
            }

            Section("About") {
                Text("WonderSpend helps you track expenses and income with a simple monthly view.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    userName = nameInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    dismiss()
                }
            }
        }
    }
}
