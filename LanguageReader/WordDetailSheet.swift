import SwiftUI

struct WordDetailSheet: View {
    let word: String
    let meaning: String?
    let diagnostics: DictionaryLookupResult?
    let onAdd: () -> Void
    let onReportMissing: (() -> Void)?
    let onSaveOverride: ((String) -> Void)?
    private let transliterator = Transliterator()
    @AppStorage("dictionaryDiagnosticsEnabled") private var diagnosticsEnabled = false
    @State private var overrideText: String

    init(
        word: String,
        meaning: String?,
        diagnostics: DictionaryLookupResult?,
        onAdd: @escaping () -> Void,
        onReportMissing: (() -> Void)? = nil,
        onSaveOverride: ((String) -> Void)? = nil
    ) {
        self.word = word
        self.meaning = meaning
        self.diagnostics = diagnostics
        self.onAdd = onAdd
        self.onReportMissing = onReportMissing
        self.onSaveOverride = onSaveOverride
        _overrideText = State(initialValue: meaning ?? "")
    }

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

                if let meaning, !meaning.isEmpty {
                    Text(meaning)
                        .font(.body)
                        .foregroundStyle(.primary)
                } else {
                    Text("No meaning yet.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }

            if diagnosticsEnabled, let diagnostics {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Diagnostics")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    LabeledContent("Lookup", value: diagnostics.path.displayName)
                    if let matchedKey = diagnostics.matchedKey {
                        LabeledContent("Matched Key", value: matchedKey)
                    }
                }
            }

            if diagnosticsEnabled, let onSaveOverride {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Override Meaning")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("Enter override meaning", text: $overrideText)
                        .textInputAutocapitalization(.sentences)

                    Button("Save Override") {
                        let trimmed = overrideText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onSaveOverride(trimmed)
                    }
                    .buttonStyle(.bordered)
                }
            }

            if meaning == nil, let onReportMissing {
                Button("Report missing meaning") {
                    onReportMissing()
                }
                .buttonStyle(.bordered)
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
    WordDetailSheet(
        word: "ನಮಸ್ಕಾರ",
        meaning: "hello",
        diagnostics: nil,
        onAdd: {}
    )
}
