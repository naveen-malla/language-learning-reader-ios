import SwiftUI

enum AppAppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark
    case midnight

    static let storageKey = "appearance.mode"
    static let defaultValue: AppAppearanceMode = .dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        case .midnight:
            return "Midnight"
        }
    }

    var subtitle: String {
        switch self {
        case .system:
            return "Follow iPhone setting"
        case .light:
            return "Bright glass surfaces"
        case .dark:
            return "Soft navy dark mode"
        case .midnight:
            return "Deep contrast night mode"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark, .midnight:
            return .dark
        }
    }

    var usesMidnightPalette: Bool {
        self == .midnight
    }
}

private struct AppAppearanceModeEnvironmentKey: EnvironmentKey {
    static let defaultValue = AppAppearanceMode.defaultValue
}

extension EnvironmentValues {
    var appAppearanceMode: AppAppearanceMode {
        get { self[AppAppearanceModeEnvironmentKey.self] }
        set { self[AppAppearanceModeEnvironmentKey.self] = newValue }
    }
}

enum Theme {
    static let accent = Color(red: 0.13, green: 0.45, blue: 0.9)
    static let accentSecondary = Color(red: 0.12, green: 0.68, blue: 0.63)
    static let cardBackground = Color(uiColor: .systemBackground)
    static let canvas = Color(uiColor: .systemGroupedBackground)
    static let shadow = Color.black.opacity(0.14)
    static let cornerRadius: CGFloat = 18
    static let surfaceStroke = Color.primary.opacity(0.08)
    static let readingTextSize: CGFloat = 17

    static let newHighlight = Color(red: 0.28, green: 0.64, blue: 1.0)
    static let learningHighlight = Color(red: 0.2, green: 0.78, blue: 0.56)
    static let knownHighlight = Color(uiColor: .systemGray2)
    static let glassTint = Color.white.opacity(0.18)
    static let glassShadow = Color.black.opacity(0.24)

    static var readingFont: Font {
        .system(size: readingTextSize, weight: .regular, design: .rounded)
    }

    static var readingEmphasisFont: Font {
        .system(size: readingTextSize, weight: .semibold, design: .rounded)
    }

    static func statusColor(_ status: VocabStatus) -> Color {
        statusTint(status)
    }

    static func statusTint(_ status: VocabStatus) -> Color {
        switch status {
        case .level1:
            return Color(red: 0.19, green: 0.72, blue: 1.0)
        case .level2:
            return Color(red: 0.2, green: 0.78, blue: 0.56)
        case .level3:
            return Color(red: 0.95, green: 0.68, blue: 0.24)
        case .level4:
            return Color(red: 0.94, green: 0.47, blue: 0.34)
        case .known:
            return knownHighlight
        }
    }

    static func statusChipBackground(_ status: VocabStatus, isSelected: Bool) -> Color {
        if isSelected {
            return statusTint(status).opacity(status.isKnown ? 0.25 : 0.92)
        }
        return statusTint(status).opacity(status.isKnown ? 0.08 : 0.14)
    }

    static func statusChipForeground(_ status: VocabStatus, isSelected: Bool) -> Color {
        if isSelected {
            return status.isKnown ? .primary : .white
        }
        return status.isKnown ? .secondary : statusTint(status)
    }

    static func statusChipBorder(_ status: VocabStatus, isSelected: Bool) -> Color {
        if isSelected {
            return .clear
        }
        return statusTint(status).opacity(status.isKnown ? 0.34 : 0.6)
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
    @Environment(\.appAppearanceMode) private var appearanceMode

    var body: some View {
        let useMidnightPalette = colorScheme == .dark && appearanceMode.usesMidnightPalette
        let top = colorScheme == .dark
            ? (useMidnightPalette
               ? Color(red: 0.06, green: 0.09, blue: 0.15)
               : Color(red: 0.10, green: 0.14, blue: 0.20))
            : Color(red: 0.92, green: 0.95, blue: 1.0)
        let mid = colorScheme == .dark
            ? (useMidnightPalette
               ? Color(red: 0.04, green: 0.06, blue: 0.11)
               : Color(red: 0.07, green: 0.10, blue: 0.15))
            : Color(red: 0.86, green: 0.92, blue: 0.98)
        let bottom = colorScheme == .dark
            ? (useMidnightPalette
               ? Color(red: 0.02, green: 0.03, blue: 0.08)
               : Color(red: 0.05, green: 0.07, blue: 0.11))
            : Color(red: 0.95, green: 0.97, blue: 1.0)
        let glow = colorScheme == .dark
            ? Theme.accent.opacity(useMidnightPalette ? 0.22 : 0.28)
            : Theme.accent.opacity(0.18)

        ZStack {
            LinearGradient(colors: [top, mid, bottom], startPoint: .topLeading, endPoint: .bottomTrailing)

            RadialGradient(
                colors: [glow, .clear],
                center: .topTrailing,
                startRadius: 30,
                endRadius: 340
            )
            .blendMode(.plusLighter)

            RadialGradient(
                colors: [
                    Theme.accentSecondary.opacity(
                        colorScheme == .dark
                            ? (useMidnightPalette ? 0.14 : 0.18)
                            : 0.12
                    ),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 20,
                endRadius: 300
            )
            .blendMode(.screen)
        }
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
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
            content
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .fill(Theme.accent.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Theme.glassTint, Theme.surfaceStroke, Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Theme.glassShadow, radius: 14, y: 8)
    }
}

struct StatusLevelChip: View {
    let status: VocabStatus
    let selectedStatus: VocabStatus
    let onSelect: (VocabStatus) -> Void

    private var isSelected: Bool {
        selectedStatus == status
    }

    var body: some View {
        Button {
            onSelect(status)
        } label: {
            Text(status.shortLabel)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, status.isKnown ? 10 : 12)
                .padding(.vertical, 7)
                .foregroundStyle(Theme.statusChipForeground(status, isSelected: isSelected))
                .background(Theme.statusChipBackground(status, isSelected: isSelected), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Theme.statusChipBorder(status, isSelected: isSelected), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Set level \(status.displayName)")
        .accessibilityHint(status.meaningLabel)
    }
}

struct VocabStatusPickerMenu<Label: View>: View {
    let selectedStatus: VocabStatus
    let onSelect: (VocabStatus) -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Menu {
            ForEach(VocabStatus.progression, id: \.rawValue) { status in
                Button {
                    onSelect(status)
                } label: {
                    VocabStatusPickerOptionLabel(
                        status: status,
                        isSelected: status == selectedStatus
                    )
                }
                .accessibilityLabel("\(status.displayName). \(status.meaningLabel)")
            }
        } label: {
            label()
        }
    }
}

private struct VocabStatusPickerOptionLabel: View {
    let status: VocabStatus
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(status.shortLabel)
                .font(.subheadline.weight(.semibold))
                .frame(minWidth: 48, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(status.displayName)
                    .font(.subheadline.weight(.semibold))
                Text(status.meaningLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 10)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
            }
        }
    }
}

struct TokenTapButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 1)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.1 : 0.0001))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct IconCircleButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 30, height: 30)
            .background(tint.opacity(configuration.isPressed ? 0.2 : 0.1), in: Circle())
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

extension View {
    func cardStyle() -> some View {
        self
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .fill(Theme.accent.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Theme.glassTint, Theme.surfaceStroke, Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Theme.glassShadow, radius: 14, y: 8)
    }

    func readerUtilityButtonStyle() -> some View {
        self
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
    }

    func subtleMetadataPillStyle() -> some View {
        self
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(.thinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
    }

    func glassInputFieldStyle() -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
    }

    func glassToolbarPillStyle() -> some View {
        self
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
    }
}
