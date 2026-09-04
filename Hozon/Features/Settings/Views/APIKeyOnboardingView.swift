import SwiftUI

struct APIKeyOnboardingView: View {
    @Environment(\.colorScheme) private var colorScheme

    let apiKeyStore: ShioriAPIKeyStore

    @State private var apiKey = ""
    @State private var errorMessage: String?
    @FocusState private var isAPIKeyFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Enter the API key from your Shiori account to start syncing your links and feeds.")
                        .foregroundStyle(.secondary)

                    VStack(spacing: 12) {
                        SecureField("API Key", text: $apiKey)
                            .textContentType(.password)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($isAPIKeyFieldFocused)
                            .submitLabel(.done)
                            .onSubmit {
                                guard hasEnteredAPIKey else { return }
                                saveAPIKey()
                            }
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(AppTheme.rowBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .accessibilityHint("Enter the API key from your Shiori account.")

                        if let errorMessage {
                            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .accessibilityLabel(errorMessage)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button(action: saveAPIKey) {
                            Text("Save API Key")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(accentForeground)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(!hasEnteredAPIKey)
                        .opacity(hasEnteredAPIKey ? 1 : 0.45)
                        .accessibilityHint("Saves your API key in the device Keychain.")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            .navigationTitle("Add your Shiori API Key")
            .navigationBarTitleDisplayMode(.inline)
            .background(AppTheme.background)
        }
        .background(AppTheme.background)
        .onAppear { isAPIKeyFieldFocused = true }
    }

    private var hasEnteredAPIKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var accentForeground: Color {
        colorScheme == .dark ? .black : .white
    }

    private func saveAPIKey() {
        guard hasEnteredAPIKey else { return }

        do {
            try apiKeyStore.save(apiKey)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    APIKeyOnboardingView(apiKeyStore: .preview())
        .tint(AppTheme.accent)
}
