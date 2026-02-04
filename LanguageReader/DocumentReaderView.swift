import SwiftUI
import SwiftData

/// View for reading a document with interactive word lookup.
struct DocumentReaderView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \VocabEntry.createdAt, order: .reverse) private var vocabEntries: [VocabEntry]
    let document: Document

    @State private var selection: WordSelection?

    private let normalizer = TextNormalizer()
    
    /// Maps normalized word keys to their vocabulary status for quick lookup.
    private var statusByKey: [String: VocabStatus] {
        Dictionary(uniqueKeysWithValues: vocabEntries.map { ($0.normalizedKey, $0.status) })
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(document.title)
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)

                    Text(document.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TokenizedTextView(text: document.body, onWordTap: { word in
                        selection = WordSelection(text: word)
                    }, statusProvider: { word in
                        statusByKey[normalizer.normalize(word)]
                    })
                    .cardStyle()
                    .accessibilityLabel("Document text")
                }
                .padding()
            }
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

    /// Looks up the meaning of a word in the dictionary.
    /// - Parameter word: The word to look up.
    /// - Returns: The meaning if found, nil otherwise.
    private func lookupMeaning(for word: String) -> String? {
        DictionaryManager.shared.lookup(word)
    }

    /// Adds or updates a word in the vocabulary.
    /// If the word exists, increments encounter count and updates timestamp.
    /// If the word is new, creates a new entry.
    /// - Parameters:
    ///   - word: The word to add.
    ///   - meaning: The word's meaning (optional).
    private func addToVocab(word: String, meaning: String?) {
        let normalized = normalizer.normalize(word)
        let descriptor = FetchDescriptor<VocabEntry>(predicate: #Predicate { entry in
            entry.normalizedKey == normalized
        })

        do {
            if let existing = try modelContext.fetch(descriptor).first {
                existing.lastSeenAt = Date()
                existing.encounterCount += 1
                // Only update meaning if existing is empty and new meaning is non-empty
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
            try modelContext.save()
        } catch {
            // Log error but don't crash - vocabulary update is not critical
            print("Error saving vocabulary entry: \(error.localizedDescription)")
        }
    }

}

/// Represents a selected word for displaying in a detail sheet.
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
