import SwiftUI
import SwiftData

struct ReaderView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Document.createdAt, order: .reverse) private var documents: [Document]

    @State private var titleText = ""
    @State private var bodyText = ""

    private var canSave: Bool {
        !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Reader")
                            .font(.largeTitle.bold())

                        SectionCard("New Document") {
                            TextField("Title (optional)", text: $titleText)
                                .textInputAutocapitalization(.sentences)

                            ZStack(alignment: .topLeading) {
                                if bodyText.isEmpty {
                                    Text("Paste or type your text here")
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 8)
                                        .padding(.leading, 4)
                                        .accessibilityHidden(true)
                                }

                                TextEditor(text: $bodyText)
                                    .frame(minHeight: 180)
                                    .textInputAutocapitalization(.none)
                                    .autocorrectionDisabled(true)
                                    .accessibilityLabel("Document text")
                            }
                            .padding(8)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

                            Button {
                                saveDocument()
                            } label: {
                                Text("Save Document")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!canSave)
                            .accessibilityLabel("Save document")
                            .accessibilityHint("Saves the pasted text as a new document")
                        }

                        SectionCard("Documents") {
                            if documents.isEmpty {
                                Text("No saved documents yet.")
                                    .foregroundStyle(.secondary)
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(documents) { document in
                                        NavigationLink {
                                            DocumentReaderView(document: document)
                                        } label: {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(document.title)
                                                        .font(.headline)
                                                        .foregroundStyle(.primary)
                                                    Text(document.createdAt, style: .date)
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .foregroundStyle(.tertiary)
                                            }
                                            .padding(12)
                                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private func saveDocument() {
        let trimmedBody = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty else { return }

        let trimmedTitle = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = trimmedTitle.isEmpty ? defaultTitle() : trimmedTitle

        let document = Document(title: finalTitle, body: trimmedBody)
        modelContext.insert(document)

        titleText = ""
        bodyText = ""
    }

    private func defaultTitle() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
}

#Preview {
    ReaderView()
        .modelContainer(for: [Document.self], inMemory: true)
}
