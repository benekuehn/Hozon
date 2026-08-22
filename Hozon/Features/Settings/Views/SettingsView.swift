import SwiftUI

struct SettingsView: View {
    let apiKeyStore: ShioriAPIKeyStore

    @State private var apiKey: String
    @State private var confirmationMessage: String?
    @State private var errorMessage: String?
    @State private var isEditingAPIKey = false
    @State private var isShowingRemovalConfirmation = false

    init(apiKeyStore: ShioriAPIKeyStore) {
        self.apiKeyStore = apiKeyStore
        _apiKey = State(initialValue: "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if apiKeyStore.hasAPIKey {
                        LabeledContent("API Key") {
                            Label("Saved", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }

                        if let storedAt = apiKeyStore.apiKeyStoredAt {
                            LabeledContent("Stored") {
                                Text(storedAt, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if isEditingAPIKey {
                            apiKeyEditor
                        } else {
                            Button("Replace API Key") {
                                isEditingAPIKey = true
                            }
                            .accessibilityHint("Lets you replace the saved Shiori API key.")
                        }

                        Button("Delete API Key", role: .destructive) {
                            isShowingRemovalConfirmation = true
                        }
                        .accessibilityHint("Removes the saved Shiori API key from this device.")
                    } else if isEditingAPIKey {
                        apiKeyEditor
                    } else {
                        Button("Add API Key") {
                            isEditingAPIKey = true
                        }
                        .accessibilityHint("Lets you enter a Shiori API key to store in the device Keychain.")
                    }
                } header: {
                    Text("Shiori")
                } footer: {
                    Text("Your key is stored securely in Keychain and is only used to connect to Shiori.\(apiKeyStore.hasAPIKey && apiKeyStore.apiKeyStoredAt == nil ? " The saved date is unavailable for this existing key." : "")")
                }

                if let confirmationMessage {
                    Section {
                        Label(confirmationMessage, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .accessibilityLabel(confirmationMessage)
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Couldn’t Save API Key", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .confirmationDialog(
                "Remove Shiori API Key?",
                isPresented: $isShowingRemovalConfirmation,
                titleVisibility: .visible
            ) {
                Button("Remove API Key", role: .destructive) {
                    removeKey()
                }
            } message: {
                Text("The app will stop syncing with Shiori until you add a new key.")
            }
        }
        .background(AppTheme.background)
    }

    @ViewBuilder
    private var apiKeyEditor: some View {
        SecureField("API Key", text: $apiKey)
            .textContentType(.password)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .accessibilityHint("Enter the API key from your Shiori account.")

        Button(apiKeyStore.hasAPIKey ? "Save Replacement Key" : "Save API Key") {
            saveKey()
        }
        .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .accessibilityHint("Saves your API key in the device Keychain.")

        Button("Cancel", role: .cancel) {
            apiKey = ""
            isEditingAPIKey = false
        }
    }

    private func saveKey() {
        do {
            try apiKeyStore.save(apiKey)
            apiKey = ""
            isEditingAPIKey = false
            confirmationMessage = "API key saved."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removeKey() {
        do {
            try apiKeyStore.remove()
            apiKey = ""
            isEditingAPIKey = false
            confirmationMessage = "API key removed."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    SettingsView(apiKeyStore: ShioriAPIKeyStore())
}
