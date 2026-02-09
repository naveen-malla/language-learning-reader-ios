import SwiftUI
import SwiftData
import UIKit

struct ReaderView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var titleText = ""
    @State private var bodyText = ""

    private var canSave: Bool {
        !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                Form {
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
                                .frame(height: 80)
                                .textInputAutocapitalization(.none)
                                .autocorrectionDisabled(true)
                                .accessibilityLabel("Document text")
                        }

                        HStack(spacing: 12) {
                            Button {
                                pasteFromClipboard()
                            } label: {
                                Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                                    .font(.subheadline)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                loadSampleText()
                            } label: {
                                Label("Load Sample", systemImage: "text.badge.plus")
                                    .font(.subheadline)
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .navigationTitle("Reader")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink("Documents") {
                        DocumentsListView()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveDocument()
                    }
                    .disabled(!canSave)
                    .accessibilityLabel("Save document")
                    .accessibilityHint("Saves the pasted text as a new document")
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

    private func pasteFromClipboard() {
        guard let pasted = UIPasteboard.general.string?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !pasted.isEmpty else {
            return
        }

        bodyText = pasted
    }

    private func loadSampleText() {
        guard let sample = SampleDocuments.initial.first else { return }
        titleText = sample.title
        bodyText = sample.body
    }

}

#Preview {
    ReaderView()
        .modelContainer(for: [Document.self], inMemory: true)
}
