import SwiftUI

struct TokenizedTextView: View {
    let text: String
    let onWordTap: (String) -> Void
    let statusProvider: ((String) -> VocabStatus?)?

    private let tokenizer = Tokenizer()
    private let sentenceTokenizer = SentenceTokenizer()

    init(
        text: String,
        onWordTap: @escaping (String) -> Void,
        statusProvider: ((String) -> VocabStatus?)? = nil
    ) {
        self.text = text
        self.onWordTap = onWordTap
        self.statusProvider = statusProvider
    }

    var body: some View {
        let blocks = sentenceBlocks(from: text)

        VStack(alignment: .leading, spacing: 12) {
            ForEach(blocks) { block in
                if block.isEmpty {
                    Text(" ")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityHidden(true)
                } else {
                    FlowLayout(itemSpacing: 0, lineSpacing: 8) {
                        ForEach(tokenizer.tokenize(block.text)) { token in
                            if token.isWord {
                                let status = statusProvider?(token.text) ?? .new
                                let color = Theme.statusColor(status)

                                Button {
                                    onWordTap(token.text)
                                } label: {
                                    Text(token.text)
                                        .font(.body)
                                        .foregroundStyle(color)
                                }
                                .buttonStyle(.plain)
                                .contentShape(Rectangle())
                                .accessibilityLabel("Word \(token.text), status \(status.displayName)")
                                .accessibilityHint("Show meaning and add to vocabulary")
                            } else {
                                Text(token.text)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func sentenceBlocks(from text: String) -> [SentenceBlock] {
        let paragraphs = text.split(separator: "\n", omittingEmptySubsequences: false)
        var blocks: [SentenceBlock] = []

        for paragraph in paragraphs {
            let value = String(paragraph)
            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                blocks.append(SentenceBlock(text: "", isEmpty: true))
                continue
            }

            let sentences = sentenceTokenizer.sentences(in: value)
            if sentences.isEmpty {
                blocks.append(SentenceBlock(text: value, isEmpty: false))
            } else {
                blocks.append(contentsOf: sentences.map { SentenceBlock(text: $0, isEmpty: false) })
            }
        }

        return blocks
    }

}

private struct SentenceBlock: Identifiable {
    let id = UUID()
    let text: String
    let isEmpty: Bool
}

#Preview {
    ZStack {
        AppBackground()
        TokenizedTextView(text: "ನಮಸ್ಕಾರ, ಇದು ಪರೀಕ್ಷಾ ಪಠ್ಯ.") { _ in }
            .padding()
    }
}
