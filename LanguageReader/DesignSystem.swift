import SwiftUI

enum Theme {
    static let accent = Color.blue
    static let cardBackground = Color(.systemBackground)
    static let canvas = Color(.systemGroupedBackground)
    static let shadow = Color.black.opacity(0.08)

    static let newHighlight = Color.blue
    static let learningHighlight = Color.green

    static func statusColor(_ status: VocabStatus) -> Color {
        status.isKnown ? .gray : learningHighlight
    }

    static func wordHighlightColor(_ state: WordLearningVisualState) -> Color {
        switch state {
        case .new:
            return newHighlight
        case .learning:
            return learningHighlight
        case .known, .ignored:
            return .primary
        }
    }
}

struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let base = Theme.canvas
        let accent = colorScheme == .dark ? Color.blue.opacity(0.25) : Color.blue.opacity(0.15)
        LinearGradient(
            colors: [base, accent, base],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct SectionCard<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            content
        }
        .padding(16)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Theme.shadow, radius: 8, y: 4)
    }
}

extension View {
    func cardStyle() -> some View {
        self
            .padding(16)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: Theme.shadow, radius: 8, y: 4)
    }
}
