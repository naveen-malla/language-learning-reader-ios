import SwiftUI

struct SettingsView: View {
    private let dictionaryManager = DictionaryManager.shared
    private let translationSettings = TranslationSettingsStore()
    @AppStorage("dictionaryDiagnosticsEnabled") private var diagnosticsEnabled = false
    @State private var endpointText = ""
    @State private var regionText = ""
    @State private var apiKeyInput = ""
    @State private var hasStoredAPIKey = false
    @State private var translationStatusMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionCard("Dictionary") {
                            LabeledContent("Source", value: dictionaryManager.sourceDescription)

                            Text("Alar Kannada–English dictionary (ODbL)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Text("The app prefers a local SQLite file in Documents. If none is present, it uses the bundled dictionary.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        SectionCard("Dictionary Quality") {
                            Toggle("Show diagnostics", isOn: $diagnosticsEnabled)

                            Button("Create overrides file") {
                                dictionaryManager.ensureOverridesFile()
                            }
                            .buttonStyle(.bordered)

                            Text("Overrides file: \(DictionaryPaths.overridesFileName) (Documents)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Text("Missing list: \(DictionaryPaths.missingFileName) (Documents)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        SectionCard("Translation API") {
                            LabeledContent("Provider", value: "Azure Translator")

                            TextField("Endpoint", text: $endpointText)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()

                            TextField("Region", text: $regionText)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()

                            SecureField("Key 1 (only needed to set/update)", text: $apiKeyInput)

                            HStack(spacing: 10) {
                                Button("Save Translation Settings") {
                                    saveTranslationSettings()
                                }
                                .buttonStyle(.borderedProminent)

                                Button("Clear API Key", role: .destructive) {
                                    clearAPIKey()
                                }
                                .buttonStyle(.bordered)
                                .disabled(!hasStoredAPIKey)
                            }

                            Text(hasStoredAPIKey ? "API key is stored in Keychain." : "No API key stored.")
                                .foregroundStyle(.secondary)

                            if let translationStatusMessage {
                                Text(translationStatusMessage)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            Text("Kannada dictionary endpoints are unavailable in Azure. Word meanings continue to use the local dictionary.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadTranslationSettings()
            }
        }
    }

    private func loadTranslationSettings() {
        endpointText = translationSettings.endpointText
        regionText = translationSettings.regionText
        hasStoredAPIKey = translationSettings.hasAPIKey
    }

    private func saveTranslationSettings() {
        let store = translationSettings
        store.endpointText = endpointText
        store.regionText = regionText
        store.sourceLanguage = "kn"
        store.targetLanguage = "en"

        if !apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            do {
                try store.saveAPIKey(apiKeyInput)
                apiKeyInput = ""
                translationStatusMessage = "Saved endpoint, region, and API key."
            } catch {
                translationStatusMessage = "Failed to save API key."
            }
        } else {
            translationStatusMessage = "Saved endpoint and region."
        }

        hasStoredAPIKey = store.hasAPIKey
    }

    private func clearAPIKey() {
        do {
            try translationSettings.clearAPIKey()
            hasStoredAPIKey = false
            translationStatusMessage = "Removed API key."
        } catch {
            translationStatusMessage = "Failed to remove API key."
        }
    }
}
