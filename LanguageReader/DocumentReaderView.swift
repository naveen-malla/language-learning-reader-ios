import SwiftUI
import SwiftData

struct DocumentReaderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \VocabEntry.createdAt, order: .reverse) private var vocabEntries: [VocabEntry]
    let document: Document

    @State private var selection: WordSelection?
    @State private var readerMode: ReaderMode = .word
    @State private var selectedSentenceID: Int?
    @State private var sentenceInsights: SentenceInsights?
    @State private var translatedSentence: String?
    @State private var scrollOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 1
    @State private var viewportHeight: CGFloat = 1

    private let normalizer = TextNormalizer()
    private let sentenceInsightsBuilder = SentenceInsightsBuilder()
    private let sentenceTranslator = SentenceGlossTranslator()

    private var sentenceBlocks: [SentenceBlock] {
        SentenceTextView.blocks(from: document.body)
    }

    private var selectedSentenceBlock: SentenceBlock? {
        guard let selectedSentenceID else { return nil }
        return sentenceBlocks.first(where: { $0.id == selectedSentenceID })
    }

    private var statusByKey: [String: VocabStatus] {
        Dictionary(uniqueKeysWithValues: vocabEntries.map { ($0.normalizedKey, $0.status) })
    }

    private var progress: Double {
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

                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        if readerMode == .word {
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
                        } else {
                            SentenceTextView(
                                blocks: sentenceBlocks,
                                selectedSentenceID: selectedSentenceID,
                                onSentenceTap: { block in
                                    selectSentence(block)
                                }
                            )
                            .accessibilityLabel("Document sentences")
                        }
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

                ReaderTopBar(
                    progress: progress,
                    safeTop: proxy.safeAreaInsets.top,
                    onClose: { dismiss() }
                )
            }
            .overlay(alignment: .bottom) {
                VStack(spacing: 12) {
                    if readerMode == .sentence, let sentenceInsights {
                        SentenceInsightsPanel(
                            sentence: sentenceInsights.sentence,
                            translatedSentence: translatedSentence,
                            words: sentenceInsights.words,
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
        .onChange(of: readerMode) { _, newMode in
            guard newMode == .sentence else { return }
            ensureSentenceSelectionIfNeeded()
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

    private func toggleReaderMode() {
        withAnimation(.easeInOut(duration: 0.2)) {
            if readerMode == .word {
                readerMode = .sentence
                ensureSentenceSelectionIfNeeded()
            } else {
                readerMode = .word
            }
        }
    }

    private func ensureSentenceSelectionIfNeeded() {
        if let selectedSentenceBlock, !selectedSentenceBlock.isEmpty {
            sentenceInsights = sentenceInsightsBuilder.build(for: selectedSentenceBlock.text)
            return
        }
        guard let firstSentence = sentenceBlocks.first(where: { !$0.isEmpty }) else {
            sentenceInsights = nil
            translatedSentence = nil
            return
        }
        selectSentence(firstSentence)
    }

    private func selectSentence(_ block: SentenceBlock) {
        guard !block.isEmpty else { return }
        selectedSentenceID = block.id
        sentenceInsights = sentenceInsightsBuilder.build(for: block.text)
        translatedSentence = nil
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

private struct ReaderTopBar: View {
    let progress: Double
    let safeTop: CGFloat
    let onClose: () -> Void

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

                Slider(value: .constant(progress), in: 0...1)
                    .tint(.green)
                    .disabled(true)
                    .accessibilityHidden(true)

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
                Text("No word meanings found for this sentence yet.")
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
