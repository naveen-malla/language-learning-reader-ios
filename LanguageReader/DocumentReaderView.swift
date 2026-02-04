import SwiftUI

struct DocumentReaderView: View {
    let document: Document

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(document.title)
                    .font(.title2)
                    .bold()

                Text(document.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                Text(document.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
        .navigationTitle("Document")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    DocumentReaderView(
        document: Document(title: "Sample", body: "ನಮಸ್ಕಾರ, ಇದು ಪರೀಕ್ಷಾ ಪಠ್ಯ.")
    )
}
