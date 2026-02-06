import SwiftUI
import SwiftData

struct DocumentReaderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \VocabEntry.createdAt, order: .reverse) private var vocabEntries: [VocabEntry]
    let document: Document

    @State private var selection: WordSelection?
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
                        TokenizedTextView(text: document.body, onWordTap: { word in
                            selection = WordSelection(text: word)
                        }, statusProvider: { word in
                            statusByKey[normalizer.normalize(word)]
                        })
                        .accessibilityLabel("Document text")
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

                ReaderTopBar(progress: progress, safeTop: proxy.safeAreaInsets.top) {
                    dismiss()
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $selection) { selected in
            let meaning = lookupMeaning(for: selected.text)
            WordDetailSheet(word: selected.text, meaning: meaning) {
                addToVocab(word: selected.text, meaning: meaning)
                selection = nil
            }
        }
    }

    private func lookupMeaning(for word: String) -> String? {
        DictionaryManager.shared.lookup(word)
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

private struct WordSelection: Identifiable {
    let id = UUID()
    let text: String
}

private struct ReaderTopBar: View {
    let progress: Double
    let safeTop: CGFloat
    let onClose: () -> Void

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
