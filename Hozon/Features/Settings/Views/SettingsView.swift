import SwiftUI

struct SettingsView: View {
    private enum Layout {
        static let apiKeyActionSize: CGFloat = 44
    }

    let apiKeyStore: ShioriAPIKeyStore

    @State private var apiKey: String
    @State private var errorMessage: String?
    @State private var isEditingAPIKey = false
    @FocusState private var isAPIKeyFieldFocused: Bool

    init(apiKeyStore: ShioriAPIKeyStore) {
        self.apiKeyStore = apiKeyStore
        _apiKey = State(initialValue: "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if apiKeyStore.hasAPIKey {
                        HStack {
                            Label("API Key Configured", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)

                            Spacer()

                            Button("Remove", role: .destructive) {
                                removeKey()
                            }
                            .buttonStyle(.borderless)
                            .accessibilityHint("Removes the saved Shiori API key from this device.")
                        }
                        .listRowBackground(AppTheme.rowBackground)
                        .listRowSeparator(.hidden)
                    } else if isEditingAPIKey {
                        apiKeyEditor
                    } else {
                        Button("Add API Key") {
                            apiKey = ""
                            isEditingAPIKey = true
                        }
                        .frame(maxWidth: .infinity, minHeight: Layout.apiKeyActionSize, alignment: .leading)
                        .foregroundStyle(AppTheme.accent)
                        .accessibilityHint("Lets you enter a Shiori API key to store in the device Keychain.")
                        .listRowBackground(AppTheme.rowBackground)
                        .listRowSeparator(.hidden)
                    }
                } header: {
                    Text("Shiori")
                }
            }
            .navigationTitle("Settings")
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .alert("Couldn’t Update API Key", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .background(AppTheme.background)
    }

    @ViewBuilder
    private var apiKeyEditor: some View {
        HStack(spacing: 8) {
            SecureField("API Key", text: $apiKey)
                .textContentType(.password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isAPIKeyFieldFocused)
                .submitLabel(.done)
                .onSubmit {
                    guard hasEnteredAPIKey else { return }
                    saveKey()
                }
                .accessibilityHint("Enter the API key from your Shiori account.")

            Button(action: cancelEditingAPIKey) {
                Image(systemName: "xmark")
                    .frame(width: Layout.apiKeyActionSize, height: Layout.apiKeyActionSize)
                    .foregroundStyle(.secondary)
                    .background(Color.secondary.opacity(0.15), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel adding API key")

            Button(action: saveKey) {
                Image(systemName: "checkmark")
                    .frame(width: Layout.apiKeyActionSize, height: Layout.apiKeyActionSize)
                    .foregroundStyle(.white)
                    .background(AppTheme.accent, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!hasEnteredAPIKey)
            .accessibilityLabel("Save API key")
            .accessibilityHint("Saves your API key in the device Keychain.")
        }
        .onAppear { isAPIKeyFieldFocused = true }
        .listRowBackground(AppTheme.rowBackground)
        .listRowSeparator(.hidden)
    }

    private var hasEnteredAPIKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func cancelEditingAPIKey() {
        apiKey = ""
        isEditingAPIKey = false
        isAPIKeyFieldFocused = false
    }

    private func saveKey() {
        do {
            try apiKeyStore.save(apiKey)
            apiKey = ""
            isEditingAPIKey = false
            isAPIKeyFieldFocused = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removeKey() {
        do {
            try apiKeyStore.remove()
            apiKey = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
