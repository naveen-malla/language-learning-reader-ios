import SwiftUI

struct SettingsView: View {
    private let dictionaryManager = DictionaryManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionCard("Dictionary") {
                            LabeledContent("Source", value: dictionaryManager.sourceDescription)

                            Text("Alar Kannada–English dictionary (ODbL)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Text("The app prefers a local SQLite file in Documents. If none is present, it uses the bundled dictionary.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        SectionCard("Translation API") {
                            Text("Optional API key support will appear here.")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
