import SwiftUI

struct SettingsView: View {
    private let dictionaryManager = DictionaryManager.shared
    private let translationSettings = TranslationSettingsStore()
    @AppStorage("dictionaryDiagnosticsEnabled") private var diagnosticsEnabled = false
    @AppStorage(DictionaryManager.cloudFallbackEnabledKey) private var cloudFallbackEnabled = true
    @AppStorage(DictionaryManager.cloudFallbackTargetLanguageKey) private var cloudFallbackTargetLanguage = "en"
    @State private var endpointText = ""
    @State private var regionText = ""
    @State private var sourceLanguageText = ""
    @State private var targetLanguageText = ""
    @State private var apiKeyInput = ""
    @State private var hasStoredAPIKey = false
    @State private var cloudCacheCount = 0
    @State private var translationStatusMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionCard("System Status") {
                            HStack(spacing: 8) {
                                Text(hasStoredAPIKey ? "Translation Key Saved" : "Translation Key Missing")
                                    .subtleMetadataPillStyle()
                                    .foregroundStyle(hasStoredAPIKey ? Theme.learningHighlight : .secondary)

                                Text(diagnosticsEnabled ? "Diagnostics On" : "Diagnostics Off")
                                    .subtleMetadataPillStyle()
                                    .foregroundStyle(diagnosticsEnabled ? Theme.accent : .secondary)

                                Text(cloudFallbackEnabled ? "Cloud Fallback On" : "Cloud Fallback Off")
                                    .subtleMetadataPillStyle()
                                    .foregroundStyle(cloudFallbackEnabled ? Theme.accent : .secondary)
                            }
                        }

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
                            Toggle("Use cloud fallback for missing words", isOn: $cloudFallbackEnabled)

                            TextField("Cloud fallback target language (e.g. en)", text: $cloudFallbackTargetLanguage)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                            HStack(spacing: 10) {
                                Text("Cloud cache: \(cloudCacheCount) entries")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Button("Clear cache", role: .destructive) {
                                    dictionaryManager.clearCloudCache()
                                    cloudCacheCount = dictionaryManager.cloudCacheCount()
                                }
                                .buttonStyle(.bordered)
                            }

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
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                            TextField("Region", text: $regionText)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                            TextField("Source language (ISO code)", text: $sourceLanguageText)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                            TextField("Target language (ISO code)", text: $targetLanguageText)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                            SecureField("Key 1 (only needed to set/update)", text: $apiKeyInput)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

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
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.primary.opacity(0.08), in: Capsule())
                            }

                            Text("Cloud fallback translates missing words using your configured source and target language, then stores the result in local cache.")
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
        sourceLanguageText = translationSettings.sourceLanguage
        targetLanguageText = translationSettings.targetLanguage
        hasStoredAPIKey = translationSettings.hasAPIKey
        cloudCacheCount = dictionaryManager.cloudCacheCount()
    }

    private func saveTranslationSettings() {
        let store = translationSettings
        store.endpointText = endpointText
        store.regionText = regionText
        let source = sourceLanguageText.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = targetLanguageText.trimmingCharacters(in: .whitespacesAndNewlines)
        store.sourceLanguage = source.isEmpty ? TranslationSettingsStore.defaultSourceLanguage : source
        store.targetLanguage = target.isEmpty ? TranslationSettingsStore.defaultTargetLanguage : target

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
        cloudCacheCount = dictionaryManager.cloudCacheCount()
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
