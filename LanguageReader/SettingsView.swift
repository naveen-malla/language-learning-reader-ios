import SwiftUI

struct SettingsView: View {
    private let dictionaryManager = DictionaryManager.shared

    var body: some View {
        NavigationStack {
            List {
                Section("Dictionary") {
                    LabeledContent("Source", value: dictionaryManager.sourceDescription)

                    Text("Alar Kannada–English dictionary (ODbL)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text("Install a full dictionary file to improve coverage. The app will use a local SQLite file if present.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Translation API") {
                    Text("Optional API key support will appear here.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
