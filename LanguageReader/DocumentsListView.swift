import SwiftUI
import SwiftData

/// Displays a list of saved documents with navigation to the reader.
struct DocumentsListView: View {
    @Query(sort: \Document.createdAt, order: .reverse) private var documents: [Document]

    var body: some View {
        List {
            if documents.isEmpty {
                ContentUnavailableView {
                    Label("No documents yet", systemImage: "doc.text")
                } description: {
                    Text("Create a document from the Reader tab.")
                }
            } else {
                ForEach(documents) { document in
                    NavigationLink {
                        DocumentReaderView(document: document)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(document.title)
                                .font(.headline)
                                .accessibilityAddTraits(.isHeader)
                            Text(document.createdAt, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityLabel("Document: \(document.title), created \(document.createdAt, style: .date)")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Documents")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        DocumentsListView()
            .modelContainer(for: [Document.self], inMemory: true)
    }
}
