import SwiftUI
import SwiftData
import UIKit

struct ReaderView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var titleText = ""
    @State private var bodyText = ""
    private let tokenizer = Tokenizer()
    private let sentenceTokenizer = SentenceTokenizer()

    private var canSave: Bool {
        !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var wordCount: Int {
        tokenizer.tokenize(bodyText).filter(\.isWord).count
    }

    private var sentenceCount: Int {
        sentenceTokenizer.sentences(in: bodyText).count
    }

    private var estimatedReadingMinutes: Int {
        guard wordCount > 0 else { return 0 }
        return max(1, Int(ceil(Double(wordCount) / 170.0)))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionCard("New Document") {
                            VStack(alignment: .leading, spacing: 12) {
                                TextField("Title (optional)", text: $titleText)
                                    .textInputAutocapitalization(.sentences)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Color.primary.opacity(0.06))
                                    )

                                Divider()
                                    .overlay(Color.primary.opacity(0.1))

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
                                        .scrollContentBackground(.hidden)
                                        .textInputAutocapitalization(.none)
                                        .autocorrectionDisabled(true)
                                        .accessibilityLabel("Document text")
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                                Divider()
                                    .overlay(Color.primary.opacity(0.1))

                                HStack(spacing: 10) {
                                    Button {
                                        pasteFromClipboard()
                                    } label: {
                                        Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                                            .readerUtilityButtonStyle()
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.plain)

                                    Button {
                                        loadSampleText()
                                    } label: {
                                        Label("Load Sample", systemImage: "text.badge.plus")
                                            .readerUtilityButtonStyle()
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .accessibilityElement(children: .contain)

                                if wordCount > 0 {
                                    HStack(spacing: 8) {
                                        Text("\(wordCount) words")
                                            .subtleMetadataPillStyle()

                                        Text("\(sentenceCount) sentences")
                                            .subtleMetadataPillStyle()

                                        Text("\(estimatedReadingMinutes) min read")
                                            .subtleMetadataPillStyle()
                                    }
                                }

                                Text("Tip: tap Save when the text field is ready, then open Documents to read in immersive mode.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Reader")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        DocumentsListView()
                    } label: {
                        Text("Documents")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveDocument()
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .foregroundStyle(canSave ? Theme.accent : .secondary)
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
