import SwiftUI

struct SentenceBlock: Identifiable, Hashable {
    let id: Int
    let text: String
    let isEmpty: Bool
}

struct SentenceTextView: View {
    let blocks: [SentenceBlock]
    let selectedSentenceID: Int?
    let onSentenceTap: (SentenceBlock) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(blocks) { block in
                if block.isEmpty {
                    Color.clear
                        .frame(height: 12)
                        .accessibilityHidden(true)
                } else {
                    let isSelected = block.id == selectedSentenceID
                    Text(block.text)
                        .font(.system(size: 18, weight: .regular, design: .rounded))
                        .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.78))
                        .lineSpacing(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, isSelected ? 12 : 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(isSelected ? Color.white.opacity(0.08) : Color.clear)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .onTapGesture {
                            onSentenceTap(block)
                        }
                        .accessibilityLabel("Sentence \(block.id + 1)")
                        .accessibilityHint("Show sentence details and translation")
                }
            }
        }
    }

    static func blocks(from text: String, tokenizer: SentenceTokenizer = SentenceTokenizer()) -> [SentenceBlock] {
        let paragraphs = text.split(separator: "\n", omittingEmptySubsequences: false)
        var blocks: [SentenceBlock] = []
        blocks.reserveCapacity(paragraphs.count)

        for paragraph in paragraphs {
            let value = String(paragraph)
            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                blocks.append(SentenceBlock(id: blocks.count, text: "", isEmpty: true))
                continue
            }

            let sentences = tokenizer.sentences(in: value)
            if sentences.isEmpty {
                blocks.append(SentenceBlock(id: blocks.count, text: value, isEmpty: false))
            } else {
                for sentence in sentences {
                    blocks.append(SentenceBlock(id: blocks.count, text: sentence, isEmpty: false))
                }
            }
        }

        return blocks
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        SentenceTextView(
            blocks: SentenceTextView.blocks(from: "ನಮಸ್ಕಾರ. ಇದು ಪರೀಕ್ಷೆ.\n\nಮೂರನೇ ವಾಕ್ಯ."),
            selectedSentenceID: 1,
            onSentenceTap: { _ in }
        )
        .padding()
    }
}
