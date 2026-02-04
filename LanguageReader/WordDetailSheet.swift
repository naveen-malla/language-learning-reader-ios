import SwiftUI

/// Displays detailed information about a word and allows adding it to vocabulary.
struct WordDetailSheet: View {
    let word: String
    let meaning: String?
    let onAdd: () -> Void
    private let transliterator = Transliterator()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(word)
                .font(.largeTitle)
                .bold()
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 6) {
                Text("Pronunciation")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(transliterator.pronounce(word))
                    .font(.body)
                    .accessibilityLabel("Pronunciation: \(transliterator.pronounce(word))")
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Meaning")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let meaning = meaning, !meaning.isEmpty {
                    Text(meaning)
                        .font(.body)
                        .foregroundStyle(.primary)
                } else {
                    Text("No meaning yet.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                onAdd()
            } label: {
                Text("Add to Vocab")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Add to vocabulary")
            .accessibilityHint("Saves this word to your vocabulary list")

            Spacer()
        }
        .padding()
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    WordDetailSheet(word: "ನಮಸ್ಕಾರ", meaning: "hello") {}
}
