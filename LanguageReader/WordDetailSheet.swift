import SwiftUI

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

            VStack(alignment: .leading, spacing: 6) {
                Text("Pronunciation")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(transliterator.pronounce(word))
                    .font(.body)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Meaning")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(meaning?.isEmpty == false ? meaning! : "No meaning yet.")
                    .font(.body)
                    .foregroundStyle(meaning?.isEmpty == false ? .primary : .secondary)
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
