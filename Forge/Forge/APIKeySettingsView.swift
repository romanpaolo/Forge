//
//  APIKeySettingsView.swift
//  Forge
//
//  Settings sheet for entering and saving the Anthropic API key.
//  The key is stored in the iOS Keychain — never hardcoded or logged.
//

import SwiftUI

struct APIKeySettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var apiKey: String = ""
    @State private var isRevealed: Bool = false
    @State private var saveError: String?
    @State private var showingSaveError: Bool = false

    private var hasExistingKey: Bool { KeychainHelper.hasAPIKey }

    var body: some View {
        NavigationStack {
            Form {
                apiKeySection
                if hasExistingKey {
                    clearSection
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveKey() }
                        .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("Save Failed", isPresented: $showingSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "Unknown error.")
            }
        }
        .onAppear {
            apiKey = KeychainHelper.loadAPIKey() ?? ""
        }
    }

    // MARK: - Sections

    private var apiKeySection: some View {
        Section {
            HStack {
                Group {
                    if isRevealed {
                        TextField("sk-ant-api03-…", text: $apiKey)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    } else {
                        SecureField("sk-ant-api03-…", text: $apiKey)
                    }
                }
                .font(.system(.body, design: .monospaced))

                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("Anthropic API Key")
        } footer: {
            Text("Get your key at console.anthropic.com — Claude Sonnet is used for transcription. The key is stored in the iOS Keychain and never leaves your device.")
        }
    }

    private var clearSection: some View {
        Section {
            Button("Clear Saved Key", role: .destructive) {
                KeychainHelper.deleteAPIKey()
                apiKey = ""
            }
        }
    }

    // MARK: - Actions

    private func saveKey() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        do {
            try KeychainHelper.saveAPIKey(trimmed)
            dismiss()
        } catch {
            saveError = error.localizedDescription
            showingSaveError = true
        }
    }
}

#Preview {
    APIKeySettingsView()
}
