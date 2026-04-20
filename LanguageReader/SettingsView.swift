import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    private let dictionaryManager = DictionaryManager.shared
    private let translationSettings = TranslationSettingsStore()
    @Query(sort: \Document.updatedAt, order: .reverse) private var documents: [Document]
    @Query(sort: \VocabEntry.createdAt, order: .reverse) private var vocabEntries: [VocabEntry]
    @AppStorage(StudyLanguageSettingsStore.studyLanguageKey) private var studyLanguageCode = SupportedLanguage.freshInstallDefault.rawValue
    @AppStorage(AppAppearanceMode.storageKey) private var appearanceModeRawValue = AppAppearanceMode.defaultValue.rawValue
    @AppStorage(FlashcardSettings.sessionWordLimitKey) private var sessionWordLimit = FlashcardDeck.defaultSessionWordLimit
    @AppStorage(AutoImportSettings.autoTopUpEnabledKey) private var autoTopUpEnabled = AutoImportSettings.defaultAutoTopUpEnabled
    @AppStorage(AutoImportSettings.backgroundRefreshEnabledKey) private var backgroundRefreshEnabled = AutoImportSettings.defaultBackgroundRefreshEnabled
    @AppStorage(AutoImportSettings.allowRepeatImportsKey) private var allowRepeatImports = AutoImportSettings.defaultAllowRepeatImports
    @State private var endpointText = ""
    @State private var regionText = ""
    @State private var sourceLanguageText = ""
    @State private var targetLanguageText = ""
    @State private var apiKeyInput = ""
    @State private var hasStoredAPIKey = false
    @State private var qualitySnapshot: DictionaryQualitySnapshot?
    @State private var isEvaluatingQuality = false
    @State private var qualityStatusMessage: String?
    @State private var translationStatusMessage: String?
    @State private var autoImportStatusMessage: String?
    @State private var isRunningAutoImport = false
    @State private var lastAutoTopUpAttemptAt: Date?
    @State private var lastAutoTopUpSuccessAt: Date?

    private var selectedStudyLanguage: SupportedLanguage {
        SupportedLanguage.resolve(studyLanguageCode) ?? .freshInstallDefault
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionCard("Study Language") {
                            Picker("Study Language", selection: $studyLanguageCode) {
                                ForEach(SupportedLanguage.allCases) { language in
                                    Text(language.displayName).tag(language.rawValue)
                                }
                            }
                            .pickerStyle(.segmented)

                            Text("New imports, discovery, vocab, flashcards, and dictionary quality checks follow this selection.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        SectionCard("Appearance") {
                            Text("Choose how the app should look.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(AppAppearanceMode.allCases) { mode in
                                    Button {
                                        appearanceModeRawValue = mode.rawValue
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(mode.title)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.primary)
                                            Text(mode.subtitle)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(10)
                                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(Theme.accent.opacity(selectedAppearanceMode == mode ? 0.22 : 0.04))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(
                                                    selectedAppearanceMode == mode
                                                        ? Theme.accent.opacity(0.9)
                                                        : Color.white.opacity(0.15),
                                                    lineWidth: selectedAppearanceMode == mode ? 1.5 : 1
                                                )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        SectionCard("System Status") {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    Text(hasStoredAPIKey ? "Translation Key Saved" : "Translation Key Missing")
                                        .subtleMetadataPillStyle()
                                        .foregroundStyle(hasStoredAPIKey ? Theme.learningHighlight : .secondary)
                                }
                            }
                        }

                        SectionCard("Flashcards") {
                            HStack {
                                Text("Words per session")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Picker("Words per session", selection: $sessionWordLimit) {
                                    ForEach(FlashcardSettings.sessionWordLimitOptions, id: \.self) { option in
                                        Text("\(option)").tag(option)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                            }

                            Text("Controls how many due words start each flashcard session. Default is 5 words.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        SectionCard("Auto Content") {
                            Toggle("Auto top-up \(selectedStudyLanguage.displayName) lessons", isOn: $autoTopUpEnabled)
                                .toggleStyle(.switch)

                            Toggle("Allow repeat imports when feed is dry", isOn: $allowRepeatImports)
                                .toggleStyle(.switch)

                            Toggle("Allow background refresh", isOn: $backgroundRefreshEnabled)
                                .toggleStyle(.switch)
                                .onChange(of: backgroundRefreshEnabled) { _, enabled in
                                    if enabled {
                                        AutoImportBackgroundScheduler.scheduleIfNeeded()
                                    }
                                }

                            Text("Defaults: each manual pull targets 3 lessons, duration window is 5-20 minutes, and auto trigger runs when unread imported \(selectedStudyLanguage.displayName.lowercased()) lessons are below 3.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            if let lastAutoTopUpAttemptAt {
                                Text("Last auto attempt: \(lastAutoTopUpAttemptAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            if let lastAutoTopUpSuccessAt {
                                Text("Last auto success: \(lastAutoTopUpSuccessAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            Button(isRunningAutoImport ? "Running..." : "Run Pull Now") {
                                runAutoImportPackNow()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isRunningAutoImport)

                            if let autoImportStatusMessage {
                                Text(autoImportStatusMessage)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        SectionCard("Dictionary Quality") {
                            HStack {
                                Text("Evaluation")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Button(isEvaluatingQuality ? "Evaluating..." : "Refresh quality") {
                                    evaluateDictionaryQuality(enrichFromRemote: true)
                                }
                                .buttonStyle(.bordered)
                                .disabled(isEvaluatingQuality)
                            }

                            Text("Based on your saved \(selectedStudyLanguage.displayName.lowercased()) documents and saved vocab meanings. Refresh quality will also fill missing meanings from cloud fallback before scoring.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            if isEvaluatingQuality {
                                HStack(spacing: 8) {
                                    ProgressView()
                                    Text("Running dictionary quality checks...")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            } else if let qualitySnapshot {
                                VStack(alignment: .leading, spacing: 6) {
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

                            TextField("Region (optional)", text: $regionText)
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

                            Text("Cloud fallback translates missing words using your configured source and target language, then stores the result in local cache. Region is optional for global translator resources.")
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
                sessionWordLimit = normalizedSessionWordLimit
                loadTranslationSettings()
                evaluateDictionaryQuality()
                loadAutoImportStatus()
            }
            .onChange(of: studyLanguageCode) { _, _ in
                evaluateDictionaryQuality()
                loadAutoImportStatus()
            }
        }
    }

    private func loadTranslationSettings() {
        endpointText = translationSettings.endpointText
        regionText = translationSettings.regionText
        sourceLanguageText = translationSettings.sourceLanguage
        targetLanguageText = translationSettings.targetLanguage
        hasStoredAPIKey = translationSettings.hasAPIKey
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
                translationStatusMessage = "Saved endpoint, language codes, and API key."
            } catch {
                translationStatusMessage = "Failed to save API key."
            }
        } else {
            translationStatusMessage = "Saved endpoint and language codes."
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

    private func loadAutoImportStatus() {
        let defaults = UserDefaults.standard
        lastAutoTopUpAttemptAt = defaults.object(
            forKey: AutoImportSettings.lastAutoTopUpAttemptAtKey(for: selectedStudyLanguage)
        ) as? Date
        lastAutoTopUpSuccessAt = defaults.object(
            forKey: AutoImportSettings.lastAutoTopUpSuccessAtKey(for: selectedStudyLanguage)
        ) as? Date
    }

    private func runAutoImportPackNow() {
        guard !isRunningAutoImport else { return }
        isRunningAutoImport = true

        Task {
            let summary = await AutoImportCoordinator.shared.importSmartPack(modelContext: modelContext)
            await MainActor.run {
                autoImportStatusMessage = summary.statusMessage
                isRunningAutoImport = false
                loadAutoImportStatus()
            }
        }
    }

    private func evaluateDictionaryQuality(enrichFromRemote: Bool = false) {
        isEvaluatingQuality = true
        qualityStatusMessage = enrichFromRemote
            ? "Filling missing meanings from your library, then recalculating quality..."
            : nil

        Task {
            let fixture = makeLibraryQualityFixture()
            let snapshot: DictionaryQualitySnapshot
            if enrichFromRemote {
                snapshot = await dictionaryManager.evaluateQualityWithRemoteEnrichment(fixture: fixture)
            } else {
                snapshot = dictionaryManager.evaluateQuality(fixture: fixture)
            }
            await MainActor.run {
                qualitySnapshot = snapshot
                isEvaluatingQuality = false
                qualityStatusMessage = nil
            }
        }
    }

    private func makeLibraryQualityFixture() -> DictionaryQualityFixture? {
        let corpusSentences = documents
            .filter { $0.languageCode == selectedStudyLanguage }
            .map(\.body)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let goldEntries = vocabEntries
            .filter { $0.languageCode == selectedStudyLanguage }
            .compactMap { entry -> DictionaryQualityGoldEntry? in
            let key = entry.normalizedKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let meaning = entry.meaning.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty, !meaning.isEmpty else { return nil }

            let acceptedMeanings = splitMeaningCandidates(meaning)
            guard !acceptedMeanings.isEmpty else { return nil }

            return DictionaryQualityGoldEntry(
                word: key,
                acceptedMeanings: acceptedMeanings,
                matchMode: .contains
            )
        }

        guard !corpusSentences.isEmpty || !goldEntries.isEmpty else {
            return nil
        }

        let hasCorpus = !corpusSentences.isEmpty
        let hasGold = !goldEntries.isEmpty

        return DictionaryQualityFixture(
            name: "Library Quality",
            languageCode: selectedStudyLanguage.rawValue,
            corpusSentences: corpusSentences,
            goldEntries: goldEntries,
            thresholds: DictionaryQualityThresholds(
                tokenCoverageMinimum: hasCorpus ? 0.70 : 0.0,
                uniqueCoverageMinimum: hasCorpus ? 0.60 : 0.0,
                goldHitRateMinimum: hasGold ? 0.80 : 0.0,
                goldAccuracyMinimum: hasGold ? 0.60 : 0.0
            )
        )
    }

    private func splitMeaningCandidates(_ meaning: String) -> [String] {
        meaning
            .split(whereSeparator: { $0 == ";" || $0 == "," || $0 == "/" || $0 == "|" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }

    private func percentText(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }

    private var selectedAppearanceMode: AppAppearanceMode {
        AppAppearanceMode(rawValue: appearanceModeRawValue) ?? .defaultValue
    }

    private var normalizedSessionWordLimit: Int {
        FlashcardSettings.normalizedSessionWordLimit(sessionWordLimit)
    }

    private func normalizedSourceLanguageCode() -> String {
        let raw = sourceLanguageText.trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty ? selectedStudyLanguage.rawValue : raw.lowercased()
    }
}
