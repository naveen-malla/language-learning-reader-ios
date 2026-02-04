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
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("Title (optional)", text: $titleText)
                                .textInputAutocapitalization(.sentences)

                            TextEditor(text: $bodyText)
                                .frame(minHeight: 160)
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
                        }
                    } label: {
                        Text("New Document")
                    }

                    if documents.isEmpty {
                        Text("No saved documents yet.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 8)
                    } else {
                        Text("Documents")
                            .font(.headline)

                        VStack(spacing: 8) {
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
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.plain)

                                Divider()
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding()
            }
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
