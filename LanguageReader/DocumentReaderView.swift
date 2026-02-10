import SwiftUI
import SwiftData

struct DocumentReaderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \VocabEntry.createdAt, order: .reverse) private var vocabEntries: [VocabEntry]
    let document: Document

    @State private var selection: WordSelection?
    @State private var readerMode: ReaderMode = .word
    @State private var sentenceIndex = 0
    @State private var sentenceInsights: SentenceInsights?
    @State private var translatedSentence: String?
    @State private var scrollOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 1
    @State private var viewportHeight: CGFloat = 1
    @State private var statusByKey: [String: VocabStatus] = [:]
    @State private var cachedSentenceBlocks: [SentenceBlock] = []
    @State private var ignoredKeys: Set<String> = []

    private let normalizer = TextNormalizer()
    private let sentenceInsightsBuilder = SentenceInsightsBuilder()
    private let sentenceTranslator = SentenceGlossTranslator()
    private let learningStateResolver = WordLearningStateResolver()
    private let ignoredWordsStore = IgnoredWordsStore()

    private var sentenceReaderModel: SentenceReaderModel {
        SentenceReaderModel(blocks: cachedSentenceBlocks)
    }

    private var selectedSentenceBlock: SentenceBlock? {
        sentenceReaderModel.sentence(at: sentenceIndex)
    }

    private var progress: Double {
        if readerMode == .sentence {
            return sentenceReaderModel.progress(for: sentenceIndex)
        }

        let maxOffset = max(contentHeight - viewportHeight, 1)
        let value = Double(-scrollOffset / maxOffset)
        return min(max(value, 0), 1)
    }

    private var scrollBottomPadding: CGFloat { 120 }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                ReaderBackground()

                Group {
                    if readerMode == .word {
                        wordModeContent(for: proxy)
                    } else {
                        sentenceModeContent(for: proxy)
                    }
                }
                .transition(.slide.combined(with: .opacity))
                .animation(.easeInOut(duration: 0.22), value: readerMode)

                ReaderTopBar(
                    progress: progress,
                    safeTop: proxy.safeAreaInsets.top,
                    onClose: { dismiss() },
                    onSeek: readerMode == .sentence ? { seekSentence(to: $0) } : nil
                )
            }
            .overlay(alignment: .bottom) {
                ReaderModeDockButton(
                    mode: readerMode,
                    safeBottom: proxy.safeAreaInsets.bottom,
                    onToggleMode: { toggleReaderMode() }
                )
                .padding(.horizontal, 16)
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            refreshSentenceBlocks()
            refreshStatusMap()
            refreshIgnoredKeys()
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
        .sheet(item: $selection) { selected in
            WordDetailSheet(
                word: selected.text,
                meaning: selected.lookup.meaning,
                diagnostics: selected.lookup,
                onAdd: {
                    addToVocab(word: selected.text, meaning: selected.lookup.meaning, status: .level1)
                    selection = nil
                },
                onReportMissing: {
                    DictionaryManager.shared.reportMissing(word: selected.text)
                },
                onSaveOverride: { overrideMeaning in
                    DictionaryManager.shared.setOverride(word: selected.text, meaning: overrideMeaning)
                    let refreshed = DictionaryManager.shared.lookupDetailed(selected.text)
                    selection = WordSelection(text: selected.text, lookup: refreshed)
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
            .padding(.top, 102)
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
            onMarkKnown: { insight in
                addToVocab(word: insight.word, meaning: insight.meaning, status: .known)
            },
            onIgnore: { insight in
                ignoreWord(normalizedKey: insight.normalizedKey)
            },
            topInset: proxy.safeAreaInsets.top + 72,
            bottomInset: max(proxy.safeAreaInsets.bottom, 12) + 72
        )
    }

    private func toggleReaderMode() {
        let nextMode: ReaderMode = (readerMode == .word) ? .sentence : .word
        withAnimation(.easeInOut(duration: 0.22)) {
            readerMode = nextMode
        }
        if nextMode == .sentence {
            refreshSentenceInsightsForCurrentSentence()
        } else {
            sentenceInsights = nil
            translatedSentence = nil
        }
    }

    private func translateCurrentSentence() {
        guard let selectedSentenceBlock else { return }
        translatedSentence = sentenceTranslator.gloss(selectedSentenceBlock.text).text
    }

    private func refreshSentenceInsightsIfNeeded() {
        guard readerMode == .sentence, let selectedSentenceBlock else { return }
        sentenceInsights = sentenceInsightsBuilder.build(for: selectedSentenceBlock.text)
        if translatedSentence != nil {
            translatedSentence = sentenceTranslator.gloss(selectedSentenceBlock.text).text
        }
    }

    private func refreshSentenceInsightsForCurrentSentence() {
        clampSentenceIndex()
        guard let selectedSentenceBlock else {
            sentenceInsights = nil
            translatedSentence = nil
            return
        }

        sentenceInsights = sentenceInsightsBuilder.build(for: selectedSentenceBlock.text)
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
        let lookup = DictionaryManager.shared.lookupDetailed(word)
        selection = WordSelection(text: word, lookup: lookup)
    }

    private func addToVocab(word: String, meaning: String?, status: VocabStatus) {
        let normalized = normalizer.normalize(word)
        guard !normalized.isEmpty else { return }

        removeIgnored(normalizedKey: normalized)

        let descriptor = FetchDescriptor<VocabEntry>(predicate: #Predicate { entry in
            entry.normalizedKey == normalized
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
                meaning: meaning ?? "",
                status: status
            )
            modelContext.insert(entry)
        }

        refreshStatusMap()
        refreshSentenceInsightsIfNeeded()
    }

    private func ignoreWord(normalizedKey: String) {
        ignoredWordsStore.add(normalizedKey: normalizedKey)
        ignoredKeys.insert(normalizedKey)
        refreshSentenceInsightsIfNeeded()
    }

    private func removeIgnored(normalizedKey: String) {
        ignoredWordsStore.remove(normalizedKey: normalizedKey)
        ignoredKeys.remove(normalizedKey)
    }

    private func refreshSentenceBlocks() {
        cachedSentenceBlocks = SentenceTextView.blocks(from: document.body)
    }

    private func refreshStatusMap() {
        statusByKey = Dictionary(uniqueKeysWithValues: vocabEntries.map { ($0.normalizedKey, $0.status) })
    }

    private func refreshIgnoredKeys() {
        ignoredKeys = ignoredWordsStore.allKeys()
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
    let id = UUID()
    let text: String
    let lookup: DictionaryLookupResult
}

private struct ReaderBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.06, blue: 0.08),
                Color(red: 0.02, green: 0.02, blue: 0.03),
                Color.black
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

private struct SentencePagerView: View {
    let sentences: [SentenceBlock]
    @Binding var sentenceIndex: Int
    let translatedSentence: String?
    let visibleWords: [SentenceWordInsight]
    let learningStateForWord: (String) -> WordLearningVisualState
    let learningStateForKey: (String) -> WordLearningVisualState
    let onTranslate: () -> Void
    let onWordTap: (String) -> Void
    let onAddLevel1: (SentenceWordInsight) -> Void
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
                        words: (index == sentenceIndex) ? visibleWords : [],
                        learningStateForWord: learningStateForWord,
                        learningStateForKey: learningStateForKey,
                        onTranslate: onTranslate,
                        onWordTap: onWordTap,
                        onAddLevel1: onAddLevel1,
                        onMarkKnown: onMarkKnown,
                        onIgnore: onIgnore
                    )
                    .tag(index)
                    .padding(.horizontal, 24)
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
    let words: [SentenceWordInsight]
    let learningStateForWord: (String) -> WordLearningVisualState
    let learningStateForKey: (String) -> WordLearningVisualState
    let onTranslate: () -> Void
    let onWordTap: (String) -> Void
    let onAddLevel1: (SentenceWordInsight) -> Void
    let onMarkKnown: (SentenceWordInsight) -> Void
    let onIgnore: (SentenceWordInsight) -> Void

    var body: some View {
        GeometryReader { proxy in
            let wordsSectionHeight = max(220, min(360, proxy.size.height * 0.42))

            VStack(spacing: 0) {
                VStack(spacing: 14) {
                    SentenceTokenizedHeader(
                        sentence: sentence,
                        learningStateForWord: learningStateForWord,
                        onWordTap: onWordTap
                    )

                    Button(action: onTranslate) {
                        Label("Translate sentence", systemImage: "character.bubble")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.blue)
                    }

                    if let translatedSentence {
                        ScrollView {
                            Text(translatedSentence)
                                .font(.body)
                                .foregroundStyle(Color.white.opacity(0.82))
                                .multilineTextAlignment(.leading)
                                .lineSpacing(4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(minHeight: 74, maxHeight: 120)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: max(proxy.size.height - wordsSectionHeight, 0), alignment: .center)

                Divider()
                    .overlay(Color.white.opacity(0.2))

                SentenceWordsSection(
                    words: words,
                    learningStateForKey: learningStateForKey,
                    onWordTap: onWordTap,
                    onAddLevel1: onAddLevel1,
                    onMarkKnown: onMarkKnown,
                    onIgnore: onIgnore
                )
                .frame(height: wordsSectionHeight)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

private struct SentenceTokenizedHeader: View {
    let sentence: String
    let learningStateForWord: (String) -> WordLearningVisualState
    let onWordTap: (String) -> Void

    private let tokenizer = Tokenizer()

    var body: some View {
        FlowLayout(itemSpacing: 0, lineSpacing: 10) {
            ForEach(tokenizer.tokenize(sentence)) { token in
                if token.isWord {
                    let state = learningStateForWord(token.text)
                    Button {
                        onWordTap(token.text)
                    } label: {
                        Text(token.text)
                            .font(.system(size: 30, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.wordHighlightColor(state))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Word \(token.text), status \(state.accessibilityLabel)")
                    .accessibilityHint("Show meaning and add to vocabulary")
                } else {
                    Text(token.text)
                        .font(.system(size: 30, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ReaderTopBar: View {
    let progress: Double
    let safeTop: CGFloat
    let onClose: () -> Void
    let onSeek: ((Double) -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
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
                    .tint(.green)
                } else {
                    Slider(value: .constant(progress), in: 0...1)
                        .tint(.green)
                        .disabled(true)
                        .accessibilityHidden(true)
                }

                Image(systemName: "ellipsis")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 36, height: 36)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .padding(.top, safeTop + 4)
        .background(Color.black.opacity(0.48))
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
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .padding(.bottom, max(safeBottom, 10))
        .accessibilityLabel(mode.toggleAccessibilityLabel)
    }
}

private struct SentenceWordsSection: View {
    let words: [SentenceWordInsight]
    let learningStateForKey: (String) -> WordLearningVisualState
    let onWordTap: (String) -> Void
    let onAddLevel1: (SentenceWordInsight) -> Void
    let onMarkKnown: (SentenceWordInsight) -> Void
    let onIgnore: (SentenceWordInsight) -> Void

    var body: some View {
        ScrollView {
            if words.isEmpty {
                Text("No new or learning words in this sentence.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)
            } else {
                VStack(spacing: 8) {
                    ForEach(words) { insight in
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
                            onMarkKnown: {
                                onMarkKnown(insight)
                            },
                            onIgnore: {
                                onIgnore(insight)
                            }
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 10)
    }
}

private struct SentenceWordRow: View {
    let insight: SentenceWordInsight
    let state: WordLearningVisualState
    let onTap: () -> Void
    let onAddLevel1: () -> Void
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
                .padding(.top, 7)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Button(action: onTap) {
                        Text(insight.word)
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    if let badge = state.levelBadge {
                        Text(badge)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Theme.learningHighlight.opacity(0.85), in: Capsule())
                    }
                }

                Text(insight.pronunciation)
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.65))

                Text(insight.meaning ?? "No meaning yet.")
                    .font(.body)
                    .foregroundStyle((insight.meaning == nil) ? .secondary : Color.white.opacity(0.9))
                    .multilineTextAlignment(.leading)
            }

            Spacer()

            if state == .new {
                HStack(spacing: 12) {
                    Button(action: onAddLevel1) {
                        Image(systemName: "plus.circle")
                            .font(.title3)
                            .foregroundStyle(Theme.newHighlight)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add word to level 1")

                    Button(action: onIgnore) {
                        Image(systemName: "trash")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Ignore word")

                    Button(action: onMarkKnown) {
                        Image(systemName: "checkmark")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .buttonStyle(.plain)
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

#Preview {
    DocumentReaderView(
        document: Document(
            title: "Sample",
            body: "ಅವನು ತುಂಬಾ ಸಂತೋಷವಾಗಿದೆ. ಕನ್ನಡ ಭಾಷೆ ಸುಂದರವಾಗಿದೆ.\n\nಮನೆಯಲ್ಲಿ ಹೊಸ ಪುಸ್ತಕ ಇದೆ."
        )
    )
    .modelContainer(for: [Document.self, VocabEntry.self], inMemory: true)
}
