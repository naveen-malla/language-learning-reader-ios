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

    private let normalizer = TextNormalizer()
    private let sentenceInsightsBuilder = SentenceInsightsBuilder()
    private let sentenceTranslator = SentenceGlossTranslator()

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

    private var scrollBottomPadding: CGFloat {
        readerMode == .sentence ? 420 : 120
    }

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
                VStack(spacing: 12) {
                    if readerMode == .sentence, let sentenceInsights {
                        SentenceInsightsPanel(
                            sentence: sentenceInsights.sentence,
                            translatedSentence: translatedSentence,
                            words: visibleSentenceWords(from: sentenceInsights),
                            statusForKey: { key in statusByKey[key] },
                            onTranslate: { translateCurrentSentence() },
                            onWordTap: { word in openWordSheet(for: word) }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    ReaderModeDockButton(
                        mode: readerMode,
                        safeBottom: proxy.safeAreaInsets.bottom,
                        onToggleMode: { toggleReaderMode() }
                    )
                }
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
        }
        .onChange(of: document.body) { _, _ in
            refreshSentenceBlocks()
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
                    addToVocab(word: selected.text, meaning: selected.lookup.meaning)
                    selection = nil
                    refreshSentenceInsightsIfNeeded()
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
                    statusProvider: { word in
                        statusByKey[normalizer.normalize(word)]
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
            statusProvider: { word in
                statusByKey[normalizer.normalize(word)]
            },
            onWordTap: { word in
                openWordSheet(for: word)
            },
            topInset: proxy.safeAreaInsets.top + 72,
            bottomInset: max(proxy.safeAreaInsets.bottom, 12) + 332
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

    private func visibleSentenceWords(from insights: SentenceInsights) -> [SentenceWordInsight] {
        SentencePanelWordFilter.visibleWords(from: insights.words, statusByKey: statusByKey)
    }

    private func openWordSheet(for word: String) {
        let lookup = DictionaryManager.shared.lookupDetailed(word)
        selection = WordSelection(text: word, lookup: lookup)
    }

    private func addToVocab(word: String, meaning: String?) {
        let normalized = normalizer.normalize(word)
        let descriptor = FetchDescriptor<VocabEntry>(predicate: #Predicate { entry in
            entry.normalizedKey == normalized
        })

        if let existing = try? modelContext.fetch(descriptor).first {
            existing.lastSeenAt = Date()
            existing.encounterCount += 1
            if existing.meaning.isEmpty, let meaning, !meaning.isEmpty {
                existing.meaning = meaning
            }
        } else {
            let entry = VocabEntry(
                word: word,
                normalizedKey: normalized,
                meaning: meaning ?? ""
            )
            modelContext.insert(entry)
        }

        refreshStatusMap()
    }

    private func refreshSentenceBlocks() {
        cachedSentenceBlocks = SentenceTextView.blocks(from: document.body)
    }

    private func refreshStatusMap() {
        statusByKey = Dictionary(uniqueKeysWithValues: vocabEntries.map { ($0.normalizedKey, $0.status) })
    }
}

private enum ReaderMode {
    case word
    case sentence
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
    let statusProvider: (String) -> VocabStatus?
    let onWordTap: (String) -> Void
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
                    SentencePageText(
                        sentence: block.text,
                        statusProvider: statusProvider,
                        onWordTap: onWordTap
                    )
                    .tag(index)
                    .padding(.horizontal, 24)
                    .padding(.top, topInset)
                    .padding(.bottom, bottomInset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }
}

private struct SentencePageText: View {
    let sentence: String
    let statusProvider: (String) -> VocabStatus?
    let onWordTap: (String) -> Void

    private let tokenizer = Tokenizer()

    var body: some View {
        FlowLayout(itemSpacing: 0, lineSpacing: 12) {
            ForEach(tokenizer.tokenize(sentence)) { token in
                if token.isWord {
                    let status = statusProvider(token.text) ?? .new
                    Button {
                        onWordTap(token.text)
                    } label: {
                        Text(token.text)
                            .font(.system(size: 24, weight: .regular, design: .rounded))
                            .foregroundStyle(Theme.statusColor(status))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Word \(token.text), status \(status.displayName)")
                    .accessibilityHint("Show meaning and add to vocabulary")
                } else {
                    Text(token.text)
                        .font(.system(size: 24, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .accessibilityHidden(true)
                }
            }
        }
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
                mode == .word ? "Sentences" : "Words",
                systemImage: mode == .word ? "text.justify" : "textformat"
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
        .accessibilityLabel(mode == .word ? "Switch to sentence mode" : "Switch to word mode")
    }
}

private struct SentenceInsightsPanel: View {
    let sentence: String
    let translatedSentence: String?
    let words: [SentenceWordInsight]
    let statusForKey: (String) -> VocabStatus?
    let onTranslate: () -> Void
    let onWordTap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Capsule()
                .fill(Color.white.opacity(0.35))
                .frame(width: 48, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 2)

            Text(sentence)
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .lineSpacing(6)

            Button(action: onTranslate) {
                Label("Translate sentence", systemImage: "character.bubble")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
            }

            if let translatedSentence {
                Text(translatedSentence)
                    .font(.body)
                    .foregroundStyle(Color.white.opacity(0.8))
                    .lineSpacing(4)
            }

            Divider()
                .overlay(Color.white.opacity(0.2))

            if words.isEmpty {
                Text("No new or learning words in this sentence.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(words) { insight in
                            SentenceWordRow(
                                insight: insight,
                                status: statusForKey(insight.normalizedKey),
                                onTap: {
                                    onWordTap(insight.word)
                                }
                            )
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct SentenceWordRow: View {
    let insight: SentenceWordInsight
    let status: VocabStatus?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(Theme.statusColor(status ?? .new))
                    .frame(width: 10, height: 10)
                    .padding(.top, 7)

                VStack(alignment: .leading, spacing: 3) {
                    Text(insight.word)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(insight.pronunciation)
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.65))

                    Text(insight.meaning ?? "No meaning yet.")
                        .font(.body)
                        .foregroundStyle((insight.meaning == nil) ? .secondary : Color.white.opacity(0.9))
                        .multilineTextAlignment(.leading)
                }

                Spacer()
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
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
