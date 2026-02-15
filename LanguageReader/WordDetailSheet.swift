import SwiftUI

struct WordDetailSheet: View {
    let word: String
    let meaning: String?
    let diagnostics: DictionaryLookupResult?
    let isMeaningLoading: Bool
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
        isMeaningLoading: Bool = false,
        onAdd: @escaping () -> Void,
        onReportMissing: (() -> Void)? = nil,
        onSaveOverride: ((String) -> Void)? = nil
    ) {
        self.word = word
        self.meaning = meaning
        self.diagnostics = diagnostics
        self.isMeaningLoading = isMeaningLoading
        self.onAdd = onAdd
        self.onReportMissing = onReportMissing
        self.onSaveOverride = onSaveOverride
        _overrideText = State(initialValue: meaning ?? "")
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(word)
                        .font(.title2.weight(.semibold))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Pronunciation")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(transliterator.pronounce(word))
                            .font(Theme.readingFont)
                    }
                    .cardStyle()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Meaning")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if isMeaningLoading {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Fetching meaning from cloud...")
                                    .font(Theme.readingFont)
                                    .foregroundStyle(.secondary)
                            }
                        } else if let meaning, !meaning.isEmpty {
                            Text(meaning)
                                .font(Theme.readingFont)
                                .foregroundStyle(.primary)
                        } else {
                            Text("No meaning yet.")
                                .font(Theme.readingFont)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .cardStyle()

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
                        .cardStyle()
                    }

                    if diagnosticsEnabled, let onSaveOverride {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Override Meaning")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            TextField("Enter override meaning", text: $overrideText)
                                .textInputAutocapitalization(.sentences)
                                .glassInputFieldStyle()

                            Button("Save Override") {
                                let trimmed = overrideText.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty else { return }
                                onSaveOverride(trimmed)
                            }
                            .buttonStyle(.bordered)
                        }
                        .cardStyle()
                    }

                    if !isMeaningLoading, meaning == nil, let onReportMissing {
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
                    .disabled(isMeaningLoading)
                    .accessibilityLabel("Add to vocabulary")
                    .accessibilityHint("Saves this word to your vocabulary list")
                }
                .padding(16)
            }
        }
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
