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
                    Text("Import content from the Library tab.")
                }
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        SectionCard("Saved Documents") {
                            VStack(spacing: 10) {
                                ForEach(documents) { document in
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
                                        .padding(10)
                                        .contentShape(Rectangle())
                                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
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
