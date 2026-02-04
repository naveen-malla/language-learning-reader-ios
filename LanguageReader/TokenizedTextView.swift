import SwiftUI

struct TokenizedTextView: View {
    let text: String
    let onWordTap: (String) -> Void

    private let tokenizer = Tokenizer()

    var body: some View {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)

        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                if line.isEmpty {
                    Text(" ")
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    FlowLayout(itemSpacing: 0, lineSpacing: 6) {
                        ForEach(tokenizer.tokenize(String(line))) { token in
                            if token.isWord {
                                Button {
                                    onWordTap(token.text)
                                } label: {
                                    Text(token.text)
                                        .foregroundStyle(.primary)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Text(token.text)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

#Preview {
    TokenizedTextView(text: "ನಮಸ್ಕಾರ, ಇದು ಪರೀಕ್ಷಾ ಪಠ್ಯ.") { _ in }
        .padding()
}
