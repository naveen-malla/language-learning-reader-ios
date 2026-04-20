import SwiftUI

struct StudyLanguageToolbarMenu: View {
    @Binding var selection: String

    private var selectedLanguage: SupportedLanguage {
        SupportedLanguage.resolve(selection) ?? .freshInstallDefault
    }

    var body: some View {
        Menu {
            Picker("Study Language", selection: $selection) {
                ForEach(SupportedLanguage.allCases) { language in
                    Text(language.displayName).tag(language.rawValue)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.caption.weight(.semibold))
                Text(selectedLanguage.shortLabel)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
        }
        .accessibilityLabel("Study language")
    }
}

struct StudyLanguageBadge: View {
    let language: SupportedLanguage

    var body: some View {
        Text(language.shortLabel)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.1), in: Capsule())
            .accessibilityLabel(language.displayName)
    }
}
