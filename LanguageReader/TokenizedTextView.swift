import SwiftUI

struct TokenizedTextView: View {
    let text: String
    let onWordTap: (String) -> Void
    let learningStateProvider: ((String) -> WordLearningVisualState)?

    private let tokenizer = Tokenizer()
    private let sentenceTokenizer = SentenceTokenizer()
    @State private var cachedBlocks: [TokenizedSentenceBlock] = []

    init(
        text: String,
        onWordTap: @escaping (String) -> Void,
        learningStateProvider: ((String) -> WordLearningVisualState)? = nil
    ) {
        self.text = text
        self.onWordTap = onWordTap
        self.learningStateProvider = learningStateProvider
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(cachedBlocks) { block in
                if block.isEmpty {
                    Text(" ")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityHidden(true)
                } else {
                    FlowLayout(itemSpacing: 0, lineSpacing: 8) {
                        ForEach(block.tokens) { token in
                            if token.isWord {
                                let state = learningStateProvider?(token.text) ?? .new
                                let color = Theme.wordHighlightColor(state)

                                Button {
                                    onWordTap(token.text)
                                } label: {
                                    Text(token.text)
                                        .font(.body)
                                        .foregroundStyle(color)
                                }
                                .buttonStyle(.plain)
                                .contentShape(Rectangle())
                                .accessibilityLabel("Word \(token.text), status \(state.accessibilityLabel)")
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
        .onAppear {
            refreshCachedBlocks()
        }
        .onChange(of: text) { _, _ in
            refreshCachedBlocks()
        }
    }

    private func refreshCachedBlocks() {
        let blocks = sentenceBlocks(from: text)
        cachedBlocks = blocks.map { block in
            TokenizedSentenceBlock(
                id: block.id,
                isEmpty: block.isEmpty,
                tokens: block.isEmpty ? [] : tokenizer.tokenize(block.text)
            )
        }
    }

    private func sentenceBlocks(from text: String) -> [TokenSentenceBlock] {
        let paragraphs = text.split(separator: "\n", omittingEmptySubsequences: false)
        var blocks: [TokenSentenceBlock] = []
        var nextID = 0

        for paragraph in paragraphs {
            let value = String(paragraph)
            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                blocks.append(TokenSentenceBlock(id: nextID, text: "", isEmpty: true))
                nextID += 1
                continue
            }

            let sentences = sentenceTokenizer.sentences(in: value)
            if sentences.isEmpty {
                blocks.append(TokenSentenceBlock(id: nextID, text: value, isEmpty: false))
                nextID += 1
            } else {
                for sentence in sentences {
                    blocks.append(TokenSentenceBlock(id: nextID, text: sentence, isEmpty: false))
                    nextID += 1
                }
            }
        }

        return blocks
    }

}

private struct TokenSentenceBlock: Identifiable {
    let id: Int
    let text: String
    let isEmpty: Bool
}

private struct TokenizedSentenceBlock: Identifiable {
    let id: Int
    let isEmpty: Bool
    let tokens: [Token]
}

#Preview {
    ZStack {
        AppBackground()
        TokenizedTextView(text: "ನಮಸ್ಕಾರ, ಇದು ಪರೀಕ್ಷಾ ಪಠ್ಯ.") { _ in }
            .padding()
    }
}
