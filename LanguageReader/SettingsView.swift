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

                            Text("Install a full dictionary file to improve coverage. The app will use a local SQLite file if present.")
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
                .tabBarSafeArea()
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
