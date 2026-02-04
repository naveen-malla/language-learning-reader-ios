import SwiftUI

struct FlashcardsView: View {
    var body: some View {
        NavigationStack {
            Text("Flashcards coming next")
                .foregroundStyle(.secondary)
                .navigationTitle("Flashcards")
        }
    }
}

#Preview {
    FlashcardsView()
}
