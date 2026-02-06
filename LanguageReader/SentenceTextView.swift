import SwiftUI

struct SentenceTextView: View {
    let text: String

    private let sentenceTokenizer = SentenceTokenizer()

    var body: some View {
        let blocks = sentenceBlocks(from: text)

        VStack(alignment: .leading, spacing: 12) {
            ForEach(blocks) { block in
                if block.isEmpty {
                    Text(" ")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityHidden(true)
                } else {
                    Text(block.text)
                        .font(.body)
                        .foregroundStyle(.primary)
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
        SentenceTextView(text: "ನಮಸ್ಕಾರ, ಇದು ಪರೀಕ್ಷಾ ಪಠ್ಯ.\n\nಇದು ಎರಡನೇ ಪರಿಚ್ಛೇದ.")
            .padding()
    }
}
