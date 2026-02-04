import SwiftUI

struct TokenizedTextView: View {
    let text: String
    let onWordTap: (String) -> Void
    let statusProvider: ((String) -> VocabStatus?)?

    private let tokenizer = Tokenizer()

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
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)

        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                if line.isEmpty {
                    Text(" ")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityHidden(true)
                } else {
                    FlowLayout(itemSpacing: 0, lineSpacing: 6) {
                        ForEach(tokenizer.tokenize(String(line))) { token in
                            if token.isWord {
                                let status = statusProvider?(token.text) ?? .new
                                let color = statusColor(for: status)

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

    private func statusColor(for status: VocabStatus) -> Color {
        switch status {
        case .new:
            return .blue
        case .learning:
            return .yellow
        case .known:
            return .gray
        }
    }
}

#Preview {
    TokenizedTextView(text: "ನಮಸ್ಕಾರ, ಇದು ಪರೀಕ್ಷಾ ಪಠ್ಯ.") { _ in }
        .padding()
}
