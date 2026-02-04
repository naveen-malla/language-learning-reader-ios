import SwiftUI
import SwiftData

struct DocumentReaderView: View {
    @Environment(\.modelContext) private var modelContext
    let document: Document

    @State private var selection: WordSelection?

    private let normalizer = TextNormalizer()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(document.title)
                    .font(.title2)
                    .bold()

                Text(document.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                TokenizedTextView(text: document.body) { word in
                    selection = WordSelection(text: word)
                }
            }
            .padding()
        }
        .navigationTitle("Document")
        .navigationBarTitleDisplayMode(.inline)
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

#Preview {
    DocumentReaderView(
        document: Document(title: "Sample", body: "ನಮಸ್ಕಾರ, ಇದು ಪರೀಕ್ಷಾ ಪಠ್ಯ.")
    )
    .modelContainer(for: [Document.self, VocabEntry.self], inMemory: true)
}
