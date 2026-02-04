import SwiftUI

struct WordDetailSheet: View {
    let word: String
    let meaning: String?
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(word)
                .font(.largeTitle)
                .bold()

            VStack(alignment: .leading, spacing: 6) {
                Text("Meaning")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(meaning?.isEmpty == false ? meaning! : "No meaning yet.")
                    .font(.body)
            }

            Button {
                onAdd()
            } label: {
                Text("Add to Vocab")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    WordDetailSheet(word: "ನಮಸ್ಕಾರ", meaning: "hello") {}
}
