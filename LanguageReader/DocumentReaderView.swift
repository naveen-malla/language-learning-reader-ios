import SwiftUI
import SwiftData

struct DocumentReaderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \VocabEntry.createdAt, order: .reverse) private var vocabEntries: [VocabEntry]
    let document: Document

    @State private var selection: WordSelection?
    @State private var readerMode: ReaderMode = .word
    @State private var scrollOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 1
    @State private var viewportHeight: CGFloat = 1

    private let normalizer = TextNormalizer()
    private var statusByKey: [String: VocabStatus] {
        Dictionary(uniqueKeysWithValues: vocabEntries.map { ($0.normalizedKey, $0.status) })
    }
    private var progress: Double {
        let maxOffset = max(contentHeight - viewportHeight, 1)
        let value = Double(-scrollOffset / maxOffset)
        return min(max(value, 0), 1)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Group {
                            if readerMode == .word {
                        TokenizedTextView(text: document.body, onWordTap: { word in
                            let lookup = DictionaryManager.shared.lookupDetailed(word)
                            selection = WordSelection(text: word, lookup: lookup)
                        }, statusProvider: { word in
                            statusByKey[normalizer.normalize(word)]
                        })
                        .accessibilityLabel("Document text")
                            } else {
                                SentenceTextView(text: document.body)
                                    .accessibilityLabel("Document sentences")
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 80)
                    .padding(.bottom, 32)
                    .background(
                        GeometryReader { contentProxy in
                            Color.clear
                                .preference(key: ReaderScrollOffsetKey.self,
                                            value: contentProxy.frame(in: .named("readerScroll")).minY)
                                .preference(key: ReaderContentHeightKey.self,
                                            value: contentProxy.size.height)
                        }
                    )
                }
                .coordinateSpace(name: "readerScroll")
                .onPreferenceChange(ReaderScrollOffsetKey.self) { scrollOffset = $0 }
                .onPreferenceChange(ReaderContentHeightKey.self) { contentHeight = $0 }
                .onAppear { viewportHeight = proxy.size.height }
                .onChange(of: proxy.size.height) { _, newValue in
                    viewportHeight = newValue
                }

                ReaderTopBar(
                    progress: progress,
                    safeTop: proxy.safeAreaInsets.top,
                    mode: readerMode,
                    onClose: {
                        dismiss()
                    },
                    onToggleMode: {
                        readerMode = readerMode == .word ? .sentence : .word
                    }
                )
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .sheet(item: $selection) { selected in
            WordDetailSheet(
                word: selected.text,
                meaning: selected.lookup.meaning,
                diagnostics: selected.lookup,
                onAdd: {
                    addToVocab(word: selected.text, meaning: selected.lookup.meaning)
                    selection = nil
                },
                onReportMissing: {
                    DictionaryManager.shared.reportMissing(word: selected.text)
                },
                onSaveOverride: { overrideMeaning in
                    DictionaryManager.shared.setOverride(word: selected.text, meaning: overrideMeaning)
                    let refreshed = DictionaryManager.shared.lookupDetailed(selected.text)
                    selection = WordSelection(text: selected.text, lookup: refreshed)
                }
            )
        }
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

private struct ReaderTopBar: View {
    let progress: Double
    let safeTop: CGFloat
    let mode: ReaderMode
    let onClose: () -> Void
    let onToggleMode: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .padding(8)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Close reader")

                Slider(value: .constant(progress), in: 0...1)
                    .tint(.green)
                    .disabled(true)
                    .accessibilityHidden(true)

                Button(action: onToggleMode) {
                    Label(mode == .word ? "Sentences" : "Words",
                          systemImage: mode == .word ? "text.justify" : "textformat")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .accessibilityLabel(mode == .word ? "Switch to sentence view" : "Switch to word view")
                .accessibilityHint("Changes how the document is displayed")
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .padding(.top, safeTop + 6)
        .background(.ultraThinMaterial)
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
        document: Document(title: "Sample", body: "ನಮಸ್ಕಾರ, ಇದು ಪರೀಕ್ಷಾ ಪಠ್ಯ.")
    )
    .modelContainer(for: [Document.self, VocabEntry.self], inMemory: true)
}
