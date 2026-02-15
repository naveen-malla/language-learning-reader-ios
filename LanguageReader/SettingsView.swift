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
    @State private var qualitySnapshot: DictionaryQualitySnapshot?
    @State private var isEvaluatingQuality = false
    @State private var qualityStatusMessage: String?
    @State private var translationStatusMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionCard("System Status") {
                            ScrollView(.horizontal, showsIndicators: false) {
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
                                .glassInputFieldStyle()

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

                            Divider()

                            HStack {
                                Text("Evaluation")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Button(isEvaluatingQuality ? "Evaluating..." : "Refresh quality") {
                                    evaluateDictionaryQuality()
                                }
                                .buttonStyle(.bordered)
                                .disabled(isEvaluatingQuality)
                            }

                            if isEvaluatingQuality {
                                HStack(spacing: 8) {
                                    ProgressView()
                                    Text("Running dictionary quality checks...")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            } else if let qualitySnapshot {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Language: \(qualitySnapshot.requestedLanguageCode.uppercased())")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)

                                    Text("Fixture: \(qualitySnapshot.fixtureName) (\(qualitySnapshot.fixtureLanguageCode.uppercased()))")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)

                                    if qualitySnapshot.usedFallbackFixture {
                                        Text("No fixture exists for \(qualitySnapshot.requestedLanguageCode.uppercased()). Showing baseline \(qualitySnapshot.fixtureLanguageCode.uppercased()) metrics.")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }

                                    LabeledContent(
                                        "Token coverage",
                                        value: "\(percentText(qualitySnapshot.tokenCoverage)) (\(qualitySnapshot.tokenHits)/\(qualitySnapshot.tokenTotal))"
                                    )
                                    LabeledContent(
                                        "Unique coverage",
                                        value: "\(percentText(qualitySnapshot.uniqueCoverage)) (\(qualitySnapshot.uniqueHits)/\(qualitySnapshot.uniqueTotal))"
                                    )
                                    LabeledContent(
                                        "Gold hit rate",
                                        value: "\(percentText(qualitySnapshot.goldHitRate)) (\(qualitySnapshot.goldHits)/\(qualitySnapshot.goldTotal))"
                                    )
                                    LabeledContent(
                                        "Gold accuracy",
                                        value: "\(percentText(qualitySnapshot.goldAccuracy)) (\(qualitySnapshot.goldCorrect)/\(qualitySnapshot.goldTotal))"
                                    )

                                    Text(qualitySnapshot.thresholdPassed ? "Quality gate: PASS" : "Quality gate: FAIL")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(qualitySnapshot.thresholdPassed ? Theme.learningHighlight : .red)

                                    ForEach(qualitySnapshot.thresholdChecks, id: \.metricName) { check in
                                        HStack {
                                            Text(check.metricName)
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                            Spacer()
                                            Text("\(percentText(check.actual)) / \(percentText(check.expectedMinimum))")
                                                .font(.footnote.monospacedDigit())
                                                .foregroundStyle(check.passed ? Theme.learningHighlight : .red)
                                        }
                                    }

                                    if !qualitySnapshot.unresolvedTop.isEmpty {
                                        let unresolved = qualitySnapshot.unresolvedTop
                                            .prefix(6)
                                            .map { "\($0.word)(\($0.count))" }
                                            .joined(separator: ", ")
                                        Text("Top unresolved: \(unresolved)")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            } else if let qualityStatusMessage {
                                Text(qualityStatusMessage)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("No quality evaluation available yet.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        SectionCard("Translation API") {
                            LabeledContent("Provider", value: "Azure Translator")

                            TextField("Endpoint", text: $endpointText)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .glassInputFieldStyle()

                            TextField("Region", text: $regionText)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .glassInputFieldStyle()

                            TextField("Source language (ISO code)", text: $sourceLanguageText)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .glassInputFieldStyle()

                            TextField("Target language (ISO code)", text: $targetLanguageText)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .glassInputFieldStyle()

                            SecureField("Key 1 (only needed to set/update)", text: $apiKeyInput)
                                .glassInputFieldStyle()

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
                                    .background(.thinMaterial, in: Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                                    )
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
                evaluateDictionaryQuality()
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

    private func evaluateDictionaryQuality() {
        isEvaluatingQuality = true
        qualityStatusMessage = nil

        Task {
            let snapshot = dictionaryManager.evaluateQuality()
            await MainActor.run {
                qualitySnapshot = snapshot
                isEvaluatingQuality = false
            }
        }
    }

    private func percentText(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }
}
