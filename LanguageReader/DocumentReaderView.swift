import SwiftUI
import SwiftData

struct DocumentReaderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \VocabEntry.createdAt, order: .reverse) private var vocabEntries: [VocabEntry]
    let document: Document

    @State private var selection: WordSelection?
    @State private var readerMode: ReaderMode = .word
    @State private var isVideoMode = false
    @State private var sentenceIndex = 0
    @State private var sentenceInsights: SentenceInsights?
    @State private var translatedSentence: String?
    @State private var isTranslatingSentence = false
    @State private var translationTask: Task<Void, Never>?
    @State private var subtitleTranslationTask: Task<Void, Never>?
    @State private var wordLookupTask: Task<Void, Never>?
    @State private var sentenceMeaningPrefetchTask: Task<Void, Never>?
    @State private var scrollOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 1
    @State private var viewportHeight: CGFloat = 1
    @State private var statusByKey: [String: VocabStatus] = [:]
    @State private var cachedSentenceBlocks: [SentenceBlock] = []
    @State private var ignoredKeys: Set<String> = []
    @State private var videoCurrentTime = 0.0
    @State private var videoDuration = 0.0
    @State private var requestedVideoSeekTime: Double?
    @State private var videoPlaybackState: YouTubePlayerPlaybackState = .idle
    @State private var translatedSubtitleCues: [TranslatedSubtitleCue]?
    @State private var isLoadingSubtitleTranslation = false
    @State private var subtitleTranslationMessage: String?
    @State private var legacySubtitleCueBackfillTask: Task<Void, Never>?
    @State private var isLoadingLegacySubtitleCues = false

    private let normalizer = TextNormalizer()
    private let sentenceInsightsBuilder = SentenceInsightsBuilder()
    private let sentenceTranslator = SentenceTranslationService()
    private let subtitleTranslationService = SubtitleTranslationService()
    private let learningStateResolver = WordLearningStateResolver()
    private let ignoredWordsStore = IgnoredWordsStore()
    private var documentLanguageCode: String { document.languageCode.rawValue }

    private var sentenceReaderModel: SentenceReaderModel {
        SentenceReaderModel(blocks: cachedSentenceBlocks)
    }

    private var selectedSentenceBlock: SentenceBlock? {
        sentenceReaderModel.sentence(at: sentenceIndex)
    }

    private var subtitleCues: [TimedSubtitleCue] {
        document.subtitleCues
    }

    private var hasVideoSource: Bool {
        document.sourceType == .youtube && document.sourceVideoID != nil
    }

    private var activeSubtitleCueIndex: Int? {
        SubtitleCueTimeline.activeIndex(for: subtitleCues, at: videoCurrentTime)
    }

    private var supportsVideoMode: Bool {
        hasVideoSource && subtitleCues.isEmpty == false
    }

    private var legacyVideoToggle: ReaderTopBarToggle? {
        guard hasVideoSource else { return nil }

        if isVideoMode {
            return ReaderTopBarToggle(
                label: "Read",
                systemImage: "book.closed",
                accessibilityLabel: "Switch back to reading mode",
                isEnabled: true,
                showsProgress: false,
                action: { toggleVideoMode() }
            )
        }

        if supportsVideoMode {
            return ReaderTopBarToggle(
                label: "Watch",
                systemImage: "play.rectangle",
                accessibilityLabel: "Switch to video mode",
                isEnabled: true,
                showsProgress: false,
                action: { toggleVideoMode() }
            )
        }

        guard isLoadingLegacySubtitleCues, document.sourceVideoID != nil else {
            return nil
        }

        return ReaderTopBarToggle(
            label: "Preparing",
            systemImage: "hourglass",
            accessibilityLabel: "Preparing video subtitles",
            isEnabled: false,
            showsProgress: true,
            action: {}
        )
    }

    private var topBarProgress: Double {
        if isVideoMode {
            let totalDuration = max(videoDuration, Double(document.sourceDurationSeconds ?? 0), 1)
            return min(max(videoCurrentTime / totalDuration, 0), 1)
        }

        if readerMode == .sentence {
            return sentenceReaderModel.progress(for: sentenceIndex)
        }

        let maxOffset = max(contentHeight - viewportHeight, 1)
        let value = Double(-scrollOffset / maxOffset)
        return min(max(value, 0), 1)
    }

    private var topBarSeekHandler: ((Double) -> Void)? {
        if isVideoMode {
            return { seekVideo(to: $0) }
        }
        if readerMode == .sentence {
            return { seekSentence(to: $0) }
        }
        return nil
    }

    private var scrollBottomPadding: CGFloat { 120 }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ReaderBackground()

                Group {
                    if isVideoMode {
                        videoModeContent(for: proxy)
                    } else if readerMode == .word {
                        wordModeContent(for: proxy)
                    } else {
                        sentenceModeContent(for: proxy)
                    }
                }
                .transition(.slide.combined(with: .opacity))
                .animation(.easeInOut(duration: 0.22), value: readerMode)
                .animation(.easeInOut(duration: 0.22), value: isVideoMode)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                ReaderTopBar(
                    progress: topBarProgress,
                    onClose: { dismiss() },
                    onSeek: topBarSeekHandler,
                    videoToggle: legacyVideoToggle
                )
            }
            .overlay(alignment: .bottom) {
                if !isVideoMode {
                    ReaderModeDockButton(
                        mode: readerMode,
                        safeBottom: proxy.safeAreaInsets.bottom,
                        onToggleMode: { toggleReaderMode() }
                    )
                    .padding(.horizontal, 16)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            markDocumentOpened()
            refreshSentenceBlocks()
            refreshStatusMap()
            refreshIgnoredKeys()
            translatedSubtitleCues = SubtitleCueTimeline.compatibleTranslatedCues(
                from: document.translatedSubtitleCues,
                with: subtitleCues
            )
            videoDuration = Double(document.sourceDurationSeconds ?? 0)
            loadLegacySubtitleCuesIfNeeded()
            prefetchEnglishSubtitlesIfNeeded()
        }
        .onChange(of: document.body) { _, _ in
            refreshSentenceBlocks()
            refreshSentenceInsightsIfNeeded()
        }
        .onChange(of: readerMode) { _, newMode in
            guard newMode == .sentence else { return }
            refreshSentenceInsightsForCurrentSentence()
        }
        .onChange(of: sentenceIndex) { _, _ in
            guard readerMode == .sentence else { return }
            refreshSentenceInsightsForCurrentSentence()
        }
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
            refreshStatusMap()
        }
        .onDisappear {
            translationTask?.cancel()
            subtitleTranslationTask?.cancel()
            wordLookupTask?.cancel()
            sentenceMeaningPrefetchTask?.cancel()
            legacySubtitleCueBackfillTask?.cancel()
            legacySubtitleCueBackfillTask = nil
            isLoadingLegacySubtitleCues = false
        }
        .sheet(item: $selection) { selected in
            WordDetailSheet(
                word: selected.text,
                meaning: selected.lookup.meaning,
                diagnostics: selected.lookup,
                isMeaningLoading: selected.isMeaningLoading,
                onAdd: {
                    addToVocab(word: selected.text, meaning: selected.lookup.meaning, status: .level1)
                    selection = nil
                },
                onReportMissing: {
                    DictionaryManager.shared.reportMissing(
                        word: selected.text,
                        languageCode: documentLanguageCode
                    )
                },
                onSaveOverride: { overrideMeaning in
                    DictionaryManager.shared.setOverride(
                        word: selected.text,
                        meaning: overrideMeaning,
                        languageCode: documentLanguageCode
                    )
                    let refreshed = DictionaryManager.shared.lookupDetailed(
                        selected.text,
                        languageCode: documentLanguageCode
                    )
                    selection = WordSelection(text: selected.text, lookup: refreshed, isMeaningLoading: false)
                    refreshSentenceInsightsIfNeeded()
                }
            )
        }
    }

    @ViewBuilder
    private func wordModeContent(for proxy: GeometryProxy) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                TokenizedTextView(
                    text: document.body,
                    onWordTap: { word in
                        openWordSheet(for: word)
                    },
                    learningStateProvider: { word in
                        learningState(for: word)
                    }
                )
                .accessibilityLabel("Document words")
            }
            .padding(.horizontal, 24)
            .padding(.top, ReaderLayoutMetrics.wordModeTopPadding)
            .padding(.bottom, scrollBottomPadding)
            .background(
                GeometryReader { contentProxy in
                    Color.clear
                        .preference(
                            key: ReaderScrollOffsetKey.self,
                            value: contentProxy.frame(in: .named("readerScroll")).minY
                        )
                        .preference(
                            key: ReaderContentHeightKey.self,
                            value: contentProxy.size.height
                        )
                }
            )
        }
        .coordinateSpace(name: "readerScroll")
        .onPreferenceChange(ReaderScrollOffsetKey.self) { scrollOffset = $0 }
        .onPreferenceChange(ReaderContentHeightKey.self) { contentHeight = $0 }
        .onAppear {
            viewportHeight = proxy.size.height
        }
        .onChange(of: proxy.size.height) { _, newValue in
            viewportHeight = newValue
        }
    }

    @ViewBuilder
    private func sentenceModeContent(for proxy: GeometryProxy) -> some View {
        SentencePagerView(
            sentences: sentenceReaderModel.sentences,
            sentenceIndex: $sentenceIndex,
            translatedSentence: translatedSentence,
            isTranslatingSentence: isTranslatingSentence,
            visibleWords: sentenceInsights.map(visibleSentenceWords(from:)) ?? [],
            learningStateForWord: { word in
                learningState(for: word)
            },
            learningStateForKey: { key in
                learningState(forNormalizedKey: key)
            },
            onTranslate: { translateCurrentSentence() },
            onWordTap: { word in
                openWordSheet(for: word)
            },
            onAddLevel1: { insight in
                addToVocab(word: insight.word, meaning: insight.meaning, status: .level1)
            },
            onSetStatus: { insight, status in
                addToVocab(word: insight.word, meaning: insight.meaning, status: status)
            },
            onMarkKnown: { insight in
                addToVocab(word: insight.word, meaning: insight.meaning, status: .known)
            },
            onIgnore: { insight in
                ignoreWord(normalizedKey: insight.normalizedKey)
            },
            topInset: ReaderLayoutMetrics.sentenceTopInsetExtra,
            bottomInset: max(proxy.safeAreaInsets.bottom, 10) + ReaderLayoutMetrics.sentenceBottomInsetExtra
        )
    }

    @ViewBuilder
    private func videoModeContent(for proxy: GeometryProxy) -> some View {
        if let videoID = document.sourceVideoID, subtitleCues.isEmpty == false {
            let playerHeight = min(proxy.size.width * 9 / 16, proxy.size.height * 0.38)

            VStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.black.opacity(0.88))

                    YouTubePlayerView(
                        videoID: videoID,
                        requestedSeekTime: requestedVideoSeekTime,
                        onReady: { duration in
                            videoDuration = max(duration, Double(document.sourceDurationSeconds ?? 0))
                        },
                        onPlaybackStateChange: { state in
                            videoPlaybackState = state
                        },
                        onTimeUpdate: { currentTime, duration in
                            videoCurrentTime = currentTime
                            if duration > 0 {
                                videoDuration = duration
                            }
                            requestedVideoSeekTime = nil
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .frame(height: playerHeight)
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 14)

                VideoSubtitlePanel(
                    sourceCues: subtitleCues,
                    translatedCues: translatedSubtitleCues,
                    sourceLanguage: document.languageCode,
                    activeCueIndex: activeSubtitleCueIndex,
                    isLoadingTranslation: isLoadingSubtitleTranslation,
                    translationMessage: subtitleTranslationMessage,
                    playbackState: videoPlaybackState,
                    onRetryTranslation: { loadEnglishSubtitlesIfNeeded(force: true) }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 10)
                .padding(.bottom, max(proxy.safeAreaInsets.bottom, 10))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else {
            ContentUnavailableView {
                Label("Video unavailable", systemImage: "play.slash")
            } description: {
                Text("This lesson does not have timed subtitle cues yet.")
            }
        }
    }

    private func toggleReaderMode() {
        guard !isVideoMode else { return }
        let nextMode: ReaderMode = (readerMode == .word) ? .sentence : .word
        withAnimation(.easeInOut(duration: 0.22)) {
            readerMode = nextMode
        }
        if nextMode == .sentence {
            refreshSentenceInsightsForCurrentSentence()
        } else {
            translationTask?.cancel()
            sentenceMeaningPrefetchTask?.cancel()
            isTranslatingSentence = false
            sentenceInsights = nil
            translatedSentence = nil
        }
    }

    private func toggleVideoMode() {
        guard supportsVideoMode else { return }

        withAnimation(.easeInOut(duration: 0.22)) {
            isVideoMode.toggle()
        }

        if isVideoMode {
            translationTask?.cancel()
            sentenceMeaningPrefetchTask?.cancel()
            isTranslatingSentence = false
            translatedSentence = nil
            videoDuration = max(videoDuration, Double(document.sourceDurationSeconds ?? 0))
            translatedSubtitleCues = SubtitleCueTimeline.compatibleTranslatedCues(
                from: document.translatedSubtitleCues,
                with: subtitleCues
            )
            loadEnglishSubtitlesIfNeeded()
        } else {
            subtitleTranslationTask?.cancel()
            isLoadingSubtitleTranslation = false
            subtitleTranslationMessage = nil
            requestedVideoSeekTime = nil
        }
    }

    private func loadLegacySubtitleCuesIfNeeded() {
        guard hasVideoSource, subtitleCues.isEmpty else { return }
        guard legacySubtitleCueBackfillTask == nil else { return }
        guard let videoID = document.sourceVideoID else { return }

        isLoadingLegacySubtitleCues = true

        legacySubtitleCueBackfillTask = Task {
            do {
                let loadedCues = try await YouTubeImportService.shared.loadSubtitleCuesForExistingVideo(
                    videoID: videoID,
                    language: document.languageCode
                )
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    if !loadedCues.isEmpty {
                        document.subtitleCues = loadedCues
                        document.updatedAt = Date()
                        try? modelContext.save()
                        prefetchEnglishSubtitlesIfNeeded()
                    }

                    isLoadingLegacySubtitleCues = false
                    legacySubtitleCueBackfillTask = nil
                }
            } catch {
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    isLoadingLegacySubtitleCues = false
                    legacySubtitleCueBackfillTask = nil
                }
            }
        }
    }

    private func translateCurrentSentence() {
        guard let selectedSentenceBlock else { return }
        translationTask?.cancel()

        let sentence = selectedSentenceBlock.text
        let expectedIndex = sentenceIndex
        isTranslatingSentence = true

        translationTask = Task {
            let translated = await sentenceTranslator.translate(
                sentence: sentence,
                sourceLanguage: documentLanguageCode,
                targetLanguage: document.languageCode.englishTargetLanguageCode
            )
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard readerMode == .sentence else { return }
                guard sentenceIndex == expectedIndex else { return }
                guard self.selectedSentenceBlock?.text == sentence else { return }

                var transaction = Transaction()
                transaction.animation = nil
                withTransaction(transaction) {
                    translatedSentence = translated
                    isTranslatingSentence = false
                }
            }
        }
    }

    private func refreshSentenceInsightsIfNeeded() {
        guard readerMode == .sentence, let selectedSentenceBlock else { return }
        let built = sentenceInsightsBuilder.build(for: selectedSentenceBlock.text)
        sentenceInsights = built
        enrichSentenceMeaningsIfNeeded(sentence: selectedSentenceBlock.text, insights: built)
        if translatedSentence != nil {
            translateCurrentSentence()
        }
    }

    private func refreshSentenceInsightsForCurrentSentence() {
        clampSentenceIndex()
        guard let selectedSentenceBlock else {
            translationTask?.cancel()
            sentenceMeaningPrefetchTask?.cancel()
            isTranslatingSentence = false
            sentenceInsights = nil
            translatedSentence = nil
            return
        }

        translationTask?.cancel()
        sentenceMeaningPrefetchTask?.cancel()
        isTranslatingSentence = false
        let built = sentenceInsightsBuilder.build(for: selectedSentenceBlock.text)
        sentenceInsights = built
        enrichSentenceMeaningsIfNeeded(sentence: selectedSentenceBlock.text, insights: built)
        translatedSentence = nil
    }

    private func clampSentenceIndex() {
        sentenceIndex = sentenceReaderModel.clampedIndex(sentenceIndex)
    }

    private func seekSentence(to progress: Double) {
        let targetIndex = sentenceReaderModel.index(for: progress)
        guard targetIndex != sentenceIndex else { return }
        sentenceIndex = targetIndex
    }

    private func seekVideo(to progress: Double) {
        let totalDuration = max(videoDuration, Double(document.sourceDurationSeconds ?? 0), 0)
        guard totalDuration > 0 else { return }

        let targetTime = max(0, min(totalDuration, totalDuration * progress))
        videoCurrentTime = targetTime
        requestedVideoSeekTime = targetTime
    }

    private func loadEnglishSubtitlesIfNeeded(force: Bool = false) {
        guard supportsVideoMode else { return }

        if !force {
            if let compatible = SubtitleCueTimeline.compatibleTranslatedCues(
                from: translatedSubtitleCues ?? document.translatedSubtitleCues,
                with: subtitleCues
            ) {
                translatedSubtitleCues = compatible
                subtitleTranslationMessage = nil
                isLoadingSubtitleTranslation = false
                return
            }

            guard !isLoadingSubtitleTranslation else { return }
        }

        subtitleTranslationTask?.cancel()
        isLoadingSubtitleTranslation = true
        subtitleTranslationMessage = nil

        let sourceCues = subtitleCues
        let cachedCues = force ? nil : document.translatedSubtitleCues

        subtitleTranslationTask = Task {
            let result = await subtitleTranslationService.translateIfNeeded(
                sourceCues: sourceCues,
                cachedCues: cachedCues,
                sourceLanguage: documentLanguageCode,
                targetLanguage: document.languageCode.englishTargetLanguageCode
            )
            guard !Task.isCancelled else { return }

            await MainActor.run {
                switch result {
                case .cached(let cues):
                    translatedSubtitleCues = cues
                    subtitleTranslationMessage = nil
                case .translated(let cues):
                    translatedSubtitleCues = cues
                    subtitleTranslationMessage = nil
                    document.translatedSubtitleCues = cues
                    document.updatedAt = Date()
                    try? modelContext.save()
                case .unavailable(let message):
                    subtitleTranslationMessage = message
                    translatedSubtitleCues = SubtitleCueTimeline.compatibleTranslatedCues(
                        from: document.translatedSubtitleCues,
                        with: sourceCues
                    )
                }

                isLoadingSubtitleTranslation = false
            }
        }
    }

    private func prefetchEnglishSubtitlesIfNeeded() {
        guard hasVideoSource else { return }
        guard subtitleCues.isEmpty == false else { return }
        loadEnglishSubtitlesIfNeeded()
    }

    private func learningState(for word: String) -> WordLearningVisualState {
        learningStateResolver.state(for: word, statusByKey: statusByKey, ignoredKeys: ignoredKeys)
    }

    private func learningState(forNormalizedKey key: String) -> WordLearningVisualState {
        learningStateResolver.state(forNormalizedKey: key, statusByKey: statusByKey, ignoredKeys: ignoredKeys)
    }

    private func visibleSentenceWords(from insights: SentenceInsights) -> [SentenceWordInsight] {
        SentencePanelWordFilter.visibleWords(
            from: insights.words,
            statusByKey: statusByKey,
            ignoredKeys: ignoredKeys
        )
    }

    private func openWordSheet(for word: String) {
        wordLookupTask?.cancel()

        let lookup = DictionaryManager.shared.lookupDetailed(word, languageCode: documentLanguageCode)
        let shouldLoadRemoteMeaning = lookup.meaning == nil && DictionaryManager.shared.isCloudFallbackEnabled

        selection = WordSelection(
            text: word,
            lookup: lookup,
            isMeaningLoading: shouldLoadRemoteMeaning
        )

        guard shouldLoadRemoteMeaning else {
            return
        }

        wordLookupTask = Task {
            let refreshed = await DictionaryManager.shared.lookupDetailedWithRemoteFallback(
                word,
                languageCode: documentLanguageCode,
                targetLanguage: document.languageCode.englishTargetLanguageCode
            )
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard selection?.text == word else { return }
                selection = WordSelection(
                    text: word,
                    lookup: refreshed,
                    isMeaningLoading: false
                )
                refreshSentenceInsightsIfNeeded()
            }
        }
    }

    private func enrichSentenceMeaningsIfNeeded(sentence: String, insights: SentenceInsights) {
        guard DictionaryManager.shared.isCloudFallbackEnabled else {
            return
        }

        let missingWords = insights.words
            .filter { $0.meaning == nil }
            .map(\.word)
        guard !missingWords.isEmpty else {
            sentenceMeaningPrefetchTask?.cancel()
            sentenceMeaningPrefetchTask = nil
            return
        }

        sentenceMeaningPrefetchTask?.cancel()
        sentenceMeaningPrefetchTask = Task {
            await DictionaryManager.shared.prefetchRemoteMeanings(
                for: missingWords,
                languageCode: documentLanguageCode,
                targetLanguage: document.languageCode.englishTargetLanguageCode
            )
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard readerMode == .sentence else { return }
                guard selectedSentenceBlock?.text == sentence else { return }
                sentenceInsights = sentenceInsightsBuilder.build(for: sentence)
            }
        }
    }

    private func addToVocab(word: String, meaning: String?, status: VocabStatus) {
        let normalized = normalizer.normalize(word)
        guard !normalized.isEmpty else { return }

        removeIgnored(normalizedKey: normalized)

        let descriptor = FetchDescriptor<VocabEntry>(predicate: #Predicate { entry in
            entry.normalizedKey == normalized && entry.languageCodeRaw == documentLanguageCode
        })

        if let existing = try? modelContext.fetch(descriptor).first {
            existing.status = status
            existing.lastSeenAt = Date()
            existing.encounterCount += 1
            if existing.meaning.isEmpty, let meaning, !meaning.isEmpty {
                existing.meaning = meaning
            }
        } else {
            let entry = VocabEntry(
                word: word,
                normalizedKey: normalized,
                languageCode: document.languageCode,
                meaning: meaning ?? "",
                status: status
            )
            modelContext.insert(entry)
        }

        refreshStatusMap()
        refreshSentenceInsightsIfNeeded()
    }

    private func ignoreWord(normalizedKey: String) {
        ignoredWordsStore.add(normalizedKey: normalizedKey, languageCode: documentLanguageCode)
        ignoredKeys.insert(normalizedKey)
        refreshSentenceInsightsIfNeeded()
    }

    private func removeIgnored(normalizedKey: String) {
        ignoredWordsStore.remove(normalizedKey: normalizedKey, languageCode: documentLanguageCode)
        ignoredKeys.remove(normalizedKey)
    }

    private func refreshSentenceBlocks() {
        cachedSentenceBlocks = SentenceTextView.blocks(from: document.body)
        sentenceIndex = sentenceReaderModel.clampedIndex(sentenceIndex)
    }

    private func refreshStatusMap() {
        let currentLanguageEntries = vocabEntries.filter { $0.languageCode.rawValue == documentLanguageCode }
        statusByKey = Dictionary(uniqueKeysWithValues: currentLanguageEntries.map { ($0.normalizedKey, $0.status) })
    }

    private func refreshIgnoredKeys() {
        ignoredKeys = ignoredWordsStore.allKeys(languageCode: documentLanguageCode)
    }

    private func markDocumentOpened() {
        let now = Date()
        if document.firstOpenedAt == nil {
            document.firstOpenedAt = now
        }
        document.lastOpenedAt = now
        document.updatedAt = now
    }
}

enum ReaderMode {
    case word
    case sentence

    var toggleLabel: String {
        switch self {
        case .word:
            return "Sentence View"
        case .sentence:
            return "Text View"
        }
    }

    var toggleAccessibilityLabel: String {
        switch self {
        case .word:
            return "Switch to sentence view"
        case .sentence:
            return "Switch to text view"
        }
    }

    var toggleSystemImage: String {
        switch self {
        case .word:
            return "text.justify"
        case .sentence:
            return "textformat"
        }
    }
}

private struct WordSelection: Identifiable {
    let id: UUID
    let text: String
    let lookup: DictionaryLookupResult
    let isMeaningLoading: Bool

    init(
        id: UUID = UUID(),
        text: String,
        lookup: DictionaryLookupResult,
        isMeaningLoading: Bool = false
    ) {
        self.id = id
        self.text = text
        self.lookup = lookup
        self.isMeaningLoading = isMeaningLoading
    }
}

private struct ReaderBackground: View {
    @Environment(\.appAppearanceMode) private var appearanceMode

    var body: some View {
        let useMidnightPalette = appearanceMode.usesMidnightPalette
        let top = useMidnightPalette
            ? Color(red: 0.05, green: 0.08, blue: 0.15)
            : Color(red: 0.08, green: 0.11, blue: 0.18)
        let mid = useMidnightPalette
            ? Color(red: 0.03, green: 0.05, blue: 0.10)
            : Color(red: 0.05, green: 0.07, blue: 0.12)
        let bottom = useMidnightPalette
            ? Color(red: 0.015, green: 0.025, blue: 0.065)
            : Color(red: 0.03, green: 0.04, blue: 0.08)

        ZStack {
            LinearGradient(
                colors: [top, mid, bottom],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [Theme.accent.opacity(useMidnightPalette ? 0.14 : 0.2), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 280
            )
            .blendMode(.plusLighter)

            RadialGradient(
                colors: [Theme.accentSecondary.opacity(useMidnightPalette ? 0.1 : 0.16), .clear],
                center: .bottomLeading,
                startRadius: 24,
                endRadius: 260
            )
            .blendMode(.screen)
        }
        .ignoresSafeArea()
    }
}

private struct SentencePagerView: View {
    let sentences: [SentenceBlock]
    @Binding var sentenceIndex: Int
    let translatedSentence: String?
    let isTranslatingSentence: Bool
    let visibleWords: [SentenceWordInsight]
    let learningStateForWord: (String) -> WordLearningVisualState
    let learningStateForKey: (String) -> WordLearningVisualState
    let onTranslate: () -> Void
    let onWordTap: (String) -> Void
    let onAddLevel1: (SentenceWordInsight) -> Void
    let onSetStatus: (SentenceWordInsight, VocabStatus) -> Void
    let onMarkKnown: (SentenceWordInsight) -> Void
    let onIgnore: (SentenceWordInsight) -> Void
    let topInset: CGFloat
    let bottomInset: CGFloat

    var body: some View {
        if sentences.isEmpty {
            ContentUnavailableView {
                Label("No sentences found", systemImage: "text.page")
            } description: {
                Text("Add punctuation so the reader can split sentence pages.")
            }
            .padding(.top, topInset)
            .padding(.bottom, bottomInset)
        } else {
            TabView(selection: $sentenceIndex) {
                ForEach(Array(sentences.enumerated()), id: \.element.id) { index, block in
                    SentenceIntegratedPage(
                        sentence: block.text,
                        translatedSentence: (index == sentenceIndex) ? translatedSentence : nil,
                        isTranslatingSentence: (index == sentenceIndex) ? isTranslatingSentence : false,
                        words: (index == sentenceIndex) ? visibleWords : [],
                        learningStateForWord: learningStateForWord,
                        learningStateForKey: learningStateForKey,
                        onTranslate: onTranslate,
                        onWordTap: onWordTap,
                        onAddLevel1: onAddLevel1,
                        onSetStatus: onSetStatus,
                        onMarkKnown: onMarkKnown,
                        onIgnore: onIgnore
                    )
                    .tag(index)
                    .padding(.horizontal, ReaderLayoutMetrics.sentenceHorizontalPadding)
                    .padding(.top, topInset)
                    .padding(.bottom, bottomInset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }
}

private struct SentenceIntegratedPage: View {
    let sentence: String
    let translatedSentence: String?
    let isTranslatingSentence: Bool
    let words: [SentenceWordInsight]
    let learningStateForWord: (String) -> WordLearningVisualState
    let learningStateForKey: (String) -> WordLearningVisualState
    let onTranslate: () -> Void
    let onWordTap: (String) -> Void
    let onAddLevel1: (SentenceWordInsight) -> Void
    let onSetStatus: (SentenceWordInsight, VocabStatus) -> Void
    let onMarkKnown: (SentenceWordInsight) -> Void
    let onIgnore: (SentenceWordInsight) -> Void
    private let transliterator = Transliterator()
    @State private var baseCanvasContentHeight: CGFloat = 0
    @State private var translationCanvasContentHeight: CGFloat = 0

    private var sentencePronunciation: String {
        transliterator.pronounce(sentence)
    }

    private var hasTranslation: Bool {
        guard let translatedSentence else { return false }
        return !translatedSentence.isEmpty
    }

    var body: some View {
        GeometryReader { proxy in
            let wordsSectionHeight = ReaderLayoutMetrics.sentenceWordsSectionHeight(for: proxy.size.height)
            let topSectionHeight = max(proxy.size.height - wordsSectionHeight, 0)
            let contentCanvasHeight = max(topSectionHeight - 22, 0)
            let dynamicTopPadding = ReaderLayoutMetrics.sentenceTopCanvasStableTopPadding(
                containerHeight: contentCanvasHeight,
                baseContentHeight: baseCanvasContentHeight,
                extraContentHeight: hasTranslation ? translationCanvasContentHeight : 0
            )

            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        VStack(spacing: 12) {
                            SentenceTokenizedHeader(
                                sentence: sentence,
                                learningStateForWord: learningStateForWord,
                                onWordTap: onWordTap
                            )

                            SentencePronunciationView(pronunciation: sentencePronunciation)

                            Button(action: onTranslate) {
                                Group {
                                    if isTranslatingSentence {
                                        HStack(spacing: 8) {
                                            ProgressView()
                                                .tint(Theme.accent)
                                            Text("Translating...")
                                        }
                                    } else {
                                        Label("Translate sentence", systemImage: "character.bubble")
                                    }
                                }
                                .font(Theme.readingEmphasisFont)
                                .foregroundStyle(Theme.accent)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.05), in: Capsule())
                            }
                            .disabled(isTranslatingSentence)
                            .padding(.top, 2)
                        }
                        .measureHeight { height in
                            guard abs(baseCanvasContentHeight - height) > 0.5 else { return }
                            baseCanvasContentHeight = height
                        }

                        if let translatedSentence, !translatedSentence.isEmpty {
                            Text(translatedSentence)
                                .font(Theme.readingFont)
                                .foregroundStyle(Color.white.opacity(0.82))
                                .multilineTextAlignment(.leading)
                                .lineSpacing(4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 12)
                                .measureHeight { height in
                                    guard abs(translationCanvasContentHeight - height) > 0.5 else { return }
                                    translationCanvasContentHeight = height
                                }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 8 + dynamicTopPadding)
                    .padding(.bottom, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: topSectionHeight, alignment: .top)
                }
                .transaction { transaction in
                    transaction.animation = nil
                }
                .frame(height: topSectionHeight, alignment: .top)

                Divider()
                    .overlay(Color.white.opacity(0.2))

                SentenceWordsSection(
                    words: words,
                    learningStateForKey: learningStateForKey,
                    onWordTap: onWordTap,
                    onAddLevel1: onAddLevel1,
                    onSetStatus: onSetStatus,
                    onMarkKnown: onMarkKnown,
                    onIgnore: onIgnore
                )
                .frame(height: wordsSectionHeight)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

private struct SentencePronunciationView: View {
    let pronunciation: String

    var body: some View {
        if !pronunciation.isEmpty {
            Text(pronunciation)
                .font(Theme.readingFont)
                .foregroundStyle(Color.white.opacity(0.66))
                .multilineTextAlignment(.leading)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("Sentence pronunciation \(pronunciation)")
        }
    }
}

private struct SentenceTokenizedHeader: View {
    let sentence: String
    let learningStateForWord: (String) -> WordLearningVisualState
    let onWordTap: (String) -> Void

    private let tokenizer = Tokenizer()

    var body: some View {
        FlowLayout(itemSpacing: 0, lineSpacing: 4) {
            ForEach(tokenizer.tokenize(sentence)) { token in
                if token.isWord {
                    let state = learningStateForWord(token.text)
                    Button {
                        onWordTap(token.text)
                    } label: {
                        Text(token.text)
                            .font(Theme.readingEmphasisFont)
                            .foregroundStyle(Theme.wordHighlightColor(state))
                    }
                    .buttonStyle(TokenTapButtonStyle())
                    .accessibilityLabel("Word \(token.text), status \(state.accessibilityLabel)")
                    .accessibilityHint("Show meaning and add to vocabulary")
                } else {
                    Text(token.text)
                        .font(Theme.readingFont)
                        .foregroundStyle(.white.opacity(0.9))
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ReaderTopBarToggle {
    let label: String
    let systemImage: String
    let accessibilityLabel: String
    let isEnabled: Bool
    let showsProgress: Bool
    let action: () -> Void
}

private struct VideoSubtitlePanel: View {
    let sourceCues: [TimedSubtitleCue]
    let translatedCues: [TranslatedSubtitleCue]?
    let sourceLanguage: SupportedLanguage
    let activeCueIndex: Int?
    let isLoadingTranslation: Bool
    let translationMessage: String?
    let playbackState: YouTubePlayerPlaybackState
    let onRetryTranslation: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Text(playbackLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08), in: Capsule())

                if translatedCues != nil {
                    Text("English subtitles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            LinearGradient(
                                colors: [
                                    Theme.learningHighlight.opacity(0.95),
                                    Theme.learningHighlight.opacity(0.72)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: Capsule()
                        )
                } else {
                    Text("\(sourceLanguage.displayName) only")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.06), in: Capsule())
                }

                Spacer(minLength: 8)
            }

            if isLoadingTranslation {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(Theme.learningHighlight)
                    Text("Generating English subtitles...")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.78))
                }
            } else if let translationStatusText {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: translationStatusSystemImage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(translationStatusColor)

                    Text(translationStatusText)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.76))

                    Spacer(minLength: 8)

                    if showsRetryButton {
                        Button("Retry") {
                            onRetryTranslation()
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.learningHighlight)
                    }
                }
            }

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(sourceCues.enumerated()), id: \.element.id) { index, cue in
                            VideoSubtitleCueRow(
                                sourceCue: cue,
                                translatedCue: translatedCue(at: index),
                                isActive: index == activeCueIndex,
                                distanceFromActive: cueDistance(for: index)
                            )
                            .id(index)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 2)
                }
                .onAppear {
                    if let activeCueIndex {
                        proxy.scrollTo(activeCueIndex, anchor: .center)
                    }
                }
                .onChange(of: activeCueIndex) { _, newValue in
                    guard let newValue else { return }
                    withAnimation(.easeInOut(duration: 0.24)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.18),
                            Color.black.opacity(0.28)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .blendMode(.multiply)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var playbackLabel: String {
        switch playbackState {
        case .playing:
            return "Playing"
        case .paused:
            return "Paused"
        case .buffering:
            return "Buffering"
        case .ended:
            return "Ended"
        case .ready, .cued:
            return "Ready"
        case .idle:
            return "Loading"
        }
    }

    private var translationStatusText: String? {
        guard let translationMessage else { return nil }

        if translatedCues != nil {
            return "Using cached English subtitles."
        }

        return translationMessage
    }

    private var translationStatusSystemImage: String {
        if translatedCues != nil {
            return "arrow.triangle.2.circlepath"
        }

        guard translationMessage != nil else { return "info.circle" }
        return "exclamationmark.triangle"
    }

    private var translationStatusColor: Color {
        if translatedCues != nil {
            return Theme.learningHighlight
        }

        guard translationMessage != nil else { return Theme.learningHighlight }
        return Color.orange.opacity(0.9)
    }

    private var showsRetryButton: Bool {
        translationMessage != nil
    }

    private func translatedCue(at index: Int) -> TranslatedSubtitleCue? {
        guard let translatedCues, translatedCues.indices.contains(index) else {
            return nil
        }
        return translatedCues[index]
    }

    private func cueDistance(for index: Int) -> Int {
        guard let activeCueIndex else { return 4 }
        return abs(index - activeCueIndex)
    }
}

private struct VideoSubtitleCueRow: View {
    let sourceCue: TimedSubtitleCue
    let translatedCue: TranslatedSubtitleCue?
    let isActive: Bool
    let distanceFromActive: Int

    private var translatedText: String? {
        guard let translatedCue else { return nil }
        let trimmed = translatedCue.translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var opacity: Double {
        if isActive { return 1 }
        switch distanceFromActive {
        case 0: return 1
        case 1: return 0.84
        case 2: return 0.62
        case 3: return 0.42
        default: return 0.24
        }
    }

    private var cardFill: some ShapeStyle {
        if isActive {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Theme.learningHighlight.opacity(0.26),
                        Color.white.opacity(0.08)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }

        return AnyShapeStyle(Color.white.opacity(0.03))
    }

    private var cardStrokeColor: Color {
        isActive ? Theme.learningHighlight.opacity(0.42) : Color.white.opacity(0.06)
    }

    private var accentColor: Color {
        isActive ? Theme.learningHighlight : Color.white.opacity(0.22)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Capsule(style: .continuous)
                .fill(accentColor)
                .frame(width: isActive ? 4 : 3, height: translatedText == nil ? 32 : 48)
                .opacity(isActive ? 1 : 0.5)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: translatedText == nil ? 0 : 6) {
                if let translatedText {
                    Text(translatedText)
                        .font(.system(size: isActive ? 25 : 21, weight: isActive ? .semibold : .medium, design: .rounded))
                        .foregroundStyle(.white)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(sourceCue.sourceText)
                        .font(.system(size: isActive ? 16 : 15, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.white.opacity(isActive ? 0.66 : 0.56))
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(sourceCue.sourceText)
                        .font(.system(size: isActive ? 25 : 21, weight: isActive ? .semibold : .medium, design: .rounded))
                        .foregroundStyle(.white)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(cardFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(cardStrokeColor, lineWidth: isActive ? 1.1 : 0.8)
        )
        .shadow(color: isActive ? Theme.learningHighlight.opacity(0.16) : .clear, radius: 10, y: 4)
        .opacity(opacity)
        .scaleEffect(isActive ? 1.0 : 0.975, anchor: .center)
        .animation(.easeInOut(duration: 0.18), value: isActive)
    }
}

private struct ReaderTopBar: View {
    let progress: Double
    let onClose: () -> Void
    let onSeek: ((Double) -> Void)?
    let videoToggle: ReaderTopBarToggle?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .accessibilityLabel("Close reader")

                if let onSeek {
                    Slider(
                        value: Binding(
                            get: { progress },
                            set: { onSeek($0) }
                        ),
                        in: 0...1
                    )
                    .tint(Theme.learningHighlight)
                } else {
                    Slider(value: .constant(progress), in: 0...1)
                        .tint(Theme.learningHighlight)
                        .disabled(true)
                        .accessibilityHidden(true)
                }

                if let videoToggle {
                    Button(action: videoToggle.action) {
                        VStack(spacing: 2) {
                            if videoToggle.showsProgress {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.72)
                                    .frame(height: 16)
                            } else {
                                Image(systemName: videoToggle.systemImage)
                                    .font(.subheadline.weight(.semibold))
                            }
                            Text(videoToggle.label)
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 36)
                        .background(Color.white.opacity(0.08), in: Capsule())
                    }
                    .disabled(!videoToggle.isEnabled)
                    .accessibilityLabel(videoToggle.accessibilityLabel)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, ReaderLayoutMetrics.topBarTopOffset)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Divider()
                .overlay(Color.white.opacity(0.08))
        }
    }
}

private struct ReaderModeDockButton: View {
    let mode: ReaderMode
    let safeBottom: CGFloat
    let onToggleMode: () -> Void

    var body: some View {
        Button(action: onToggleMode) {
            Label(
                mode.toggleLabel,
                systemImage: mode.toggleSystemImage
            )
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 11)
            .padding(.horizontal, 18)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.28), lineWidth: 1)
            )
        }
        .padding(.bottom, max(safeBottom, 10))
        .shadow(color: Color.black.opacity(0.28), radius: 12, y: 4)
        .accessibilityLabel(mode.toggleAccessibilityLabel)
    }
}

private struct SentenceWordsSection: View {
    let words: [SentenceWordInsight]
    let learningStateForKey: (String) -> WordLearningVisualState
    let onWordTap: (String) -> Void
    let onAddLevel1: (SentenceWordInsight) -> Void
    let onSetStatus: (SentenceWordInsight, VocabStatus) -> Void
    let onMarkKnown: (SentenceWordInsight) -> Void
    let onIgnore: (SentenceWordInsight) -> Void

    var body: some View {
        ScrollView {
            if words.isEmpty {
                Text("No new or learning words in this sentence.")
                    .font(Theme.readingFont)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .padding(.top, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(words.enumerated()), id: \.element.id) { index, insight in
                        let state = learningStateForKey(insight.normalizedKey)
                        SentenceWordRow(
                            insight: insight,
                            state: state,
                            onTap: {
                                onWordTap(insight.word)
                            },
                            onAddLevel1: {
                                onAddLevel1(insight)
                            },
                            onSetStatus: { status in
                                onSetStatus(insight, status)
                            },
                            onMarkKnown: {
                                onMarkKnown(insight)
                            },
                            onIgnore: {
                                onIgnore(insight)
                            }
                        )
                        .padding(.vertical, 6)

                        if index < words.count - 1 {
                            Divider()
                                .overlay(Color.white.opacity(0.08))
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 0)
        .padding(.vertical, 8)
    }
}

private struct SentenceWordRow: View {
    let insight: SentenceWordInsight
    let state: WordLearningVisualState
    let onTap: () -> Void
    let onAddLevel1: () -> Void
    let onSetStatus: (VocabStatus) -> Void
    let onMarkKnown: () -> Void
    let onIgnore: () -> Void

    private var dotColor: Color {
        switch state {
        case .new:
            return Theme.newHighlight
        case .learning:
            return Theme.learningHighlight
        case .known, .ignored:
            return .clear
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(dotColor)
                .frame(width: 10, height: 10)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Button(action: onTap) {
                        Text(insight.word)
                            .font(Theme.readingEmphasisFont)
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    if case .learning(let level) = state {
                        VocabStatusPickerMenu(
                            selectedStatus: level,
                            onSelect: onSetStatus
                        ) {
                            HStack(spacing: 4) {
                                Text(level.shortLabel)
                                    .font(.caption.weight(.semibold))
                                Image(systemName: "chevron.down")
                                    .font(.caption2.weight(.bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Theme.statusTint(level).opacity(0.9), in: Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .accessibilityLabel("Set level for \(insight.word)")
                        .accessibilityHint("\(level.displayName). \(level.meaningLabel)")
                    }
                }

                Text(insight.pronunciation)
                    .font(Theme.readingFont)
                    .foregroundStyle(Color.white.opacity(0.65))

                Text(insight.meaning ?? "No meaning yet.")
                    .font(Theme.readingFont)
                    .foregroundStyle((insight.meaning == nil) ? .secondary : Color.white.opacity(0.9))
                    .multilineTextAlignment(.leading)
            }

            Spacer()

            if state == .new {
                HStack(spacing: 12) {
                    Button(action: onAddLevel1) {
                        Image(systemName: "plus.circle")
                            .font(.title3)
                            .foregroundStyle(Theme.newHighlight.opacity(0.96))
                    }
                    .buttonStyle(IconCircleButtonStyle(tint: Theme.newHighlight))
                    .accessibilityLabel("Add word to level 1")

                    Button(action: onIgnore) {
                        Image(systemName: "trash")
                            .font(.title3)
                            .foregroundStyle(.secondary.opacity(0.95))
                    }
                    .buttonStyle(IconCircleButtonStyle(tint: .secondary))
                    .accessibilityLabel("Ignore word")

                    Button(action: onMarkKnown) {
                        Image(systemName: "checkmark")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.88))
                    }
                    .buttonStyle(IconCircleButtonStyle(tint: .white))
                    .accessibilityLabel("Mark word known")
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct ReaderScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ReaderContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 1
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ReaderMeasuredHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private extension View {
    func measureHeight(_ onChange: @escaping (CGFloat) -> Void) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: ReaderMeasuredHeightKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(ReaderMeasuredHeightKey.self) { height in
            guard height > 0 else { return }
            onChange(height)
        }
    }
}

#Preview {
    DocumentReaderView(
        document: Document(
            title: "Sample",
            body: "ಅವನು ತುಂಬಾ ಸಂತೋಷವಾಗಿದೆ. ಕನ್ನಡ ಭಾಷೆ ಸುಂದರವಾಗಿದೆ.\n\nಮನೆಯಲ್ಲಿ ಹೊಸ ಪುಸ್ತಕ ಇದೆ."
        )
    )
    .modelContainer(for: [Document.self, VocabEntry.self], inMemory: true)
}
