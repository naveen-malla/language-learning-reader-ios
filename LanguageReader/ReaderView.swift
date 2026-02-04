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
            List {
                Section("New Document") {
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
                            .frame(minHeight: 160)
                            .textInputAutocapitalization(.none)
                            .autocorrectionDisabled(true)
                            .accessibilityLabel("Document text")
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.quaternary, lineWidth: 1)
                    )

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

                Section("Documents") {
                    if documents.isEmpty {
                        Text("No saved documents yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(documents) { document in
                            NavigationLink {
                                DocumentReaderView(document: document)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(document.title)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(document.createdAt, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 6)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Reader")
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
