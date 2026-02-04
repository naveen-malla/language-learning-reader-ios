import SwiftUI

/// Central theme and styling configuration for the app.
enum Theme {
    /// Primary accent color used throughout the app.
    static let accent = Color.blue
    
    /// Background color for card elements.
    static let cardBackground = Color(.systemBackground)
    
    /// Background color for the main canvas.
    static let canvas = Color(.systemGroupedBackground)
    
    /// Shadow color for elevated elements.
    static let shadow = Color.black.opacity(0.08)

    /// Returns the color associated with a vocabulary status.
    /// - Parameter status: The vocabulary status.
    /// - Returns: The corresponding color.
    static func statusColor(_ status: VocabStatus) -> Color {
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

/// Background view with a subtle gradient effect.
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

/// A card view with a title and custom content.
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

/// View modifier that applies card styling to any view.
extension View {
    /// Applies standard card styling with padding, background, and shadow.
    func cardStyle() -> some View {
        self
            .padding(16)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: Theme.shadow, radius: 8, y: 4)
    }
}
