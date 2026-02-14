import SwiftUI
import SwiftData

struct DocumentsListView: View {
    @Query(sort: \Document.createdAt, order: .reverse) private var documents: [Document]
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter
    }()

    var body: some View {
        ZStack {
            AppBackground()

            if documents.isEmpty {
                ContentUnavailableView {
                    Label("No documents yet", systemImage: "doc.text")
                } description: {
                    Text("Create a document from the Reader tab.")
                }
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        SectionCard("Saved Documents") {
                            VStack(spacing: 0) {
                                ForEach(Array(documents.enumerated()), id: \.element.id) { index, document in
                                    NavigationLink {
                                        DocumentReaderView(document: document)
                                    } label: {
                                        HStack(alignment: .top, spacing: 10) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(document.title)
                                                    .font(.title3.weight(.semibold))
                                                    .foregroundStyle(.primary)
                                                    .multilineTextAlignment(.leading)

                                                Text(Self.dateFormatter.string(from: document.createdAt))
                                                    .font(.title3.weight(.regular))
                                                    .foregroundStyle(.secondary)

                                                if let preview = documentPreview(for: document), !preview.isEmpty {
                                                    Text(preview)
                                                        .font(.subheadline)
                                                        .foregroundStyle(.secondary)
                                                        .lineLimit(2)
                                                        .padding(.top, 2)
                                                }

                                                Text("\(wordCount(for: document)) words")
                                                    .subtleMetadataPillStyle()
                                                    .foregroundStyle(.secondary)
                                                    .padding(.top, 2)
                                            }

                                            Spacer(minLength: 8)

                                            Image(systemName: "chevron.right")
                                                .font(.headline.weight(.semibold))
                                                .foregroundStyle(.tertiary)
                                                .padding(.top, 8)
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    if index < documents.count - 1 {
                                        Divider()
                                            .overlay(Color.primary.opacity(0.1))
                                            .padding(.vertical, 12)
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("Documents")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func documentPreview(for document: Document) -> String? {
        let trimmed = document.body
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private func wordCount(for document: Document) -> Int {
        document.body.split { $0.isWhitespace || $0.isNewline }.count
    }
}

#Preview {
    NavigationStack {
        DocumentsListView()
            .modelContainer(for: [Document.self], inMemory: true)
    }
}
