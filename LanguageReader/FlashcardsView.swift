import SwiftUI
import SwiftData

struct FlashcardsView: View {
    @Query(sort: \VocabEntry.createdAt) private var entries: [VocabEntry]
    @State private var isRevealed = false
    @State private var currentIndex = 0

    private var availableEntries: [VocabEntry] {
        entries
    }

    private var currentEntry: VocabEntry? {
        let count = availableEntries.count
        guard count > 0 else { return nil }
        let safeIndex = FlashcardNavigator.clampedIndex(currentIndex, count: count)
        return availableEntries[safeIndex]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 24) {
                    if let entry = currentEntry {
                        VStack(spacing: 16) {
                            Text(entry.word)
                                .font(.largeTitle)
                                .bold()
                                .multilineTextAlignment(.center)

                            if isRevealed {
                                Text(entry.meaning.isEmpty ? "No meaning yet." : entry.meaning)
                                    .font(.title3)
                                    .foregroundStyle(entry.meaning.isEmpty ? .secondary : .primary)
                                    .multilineTextAlignment(.center)
                            } else {
                                Text("Tap to reveal")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 260)
                        .cardStyle()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isRevealed.toggle()
                        }
                        .accessibilityLabel("Flashcard")
                        .accessibilityHint("Tap to reveal meaning")

                        HStack(spacing: 16) {
                            Button {
                                mark(entry: entry, status: .learning)
                            } label: {
                                Text("Still Learning")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                mark(entry: entry, status: .known)
                            } label: {
                                Text("Mark Known")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else {
                        ContentUnavailableView {
                            Label("No flashcards yet", systemImage: "rectangle.stack")
                        } description: {
                            Text("Add words in the Reader to start practicing.")
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Flashcards")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private func mark(entry: VocabEntry, status: VocabStatus) {
        entry.status = status
        entry.lastSeenAt = Date()
        entry.encounterCount += 1
        isRevealed = false
        advance()
    }

    private func advance() {
        let count = availableEntries.count
        guard count > 0 else { return }
        currentIndex = FlashcardNavigator.nextIndex(current: currentIndex, count: count)
    }
}

#Preview {
    FlashcardsView()
        .modelContainer(for: [VocabEntry.self], inMemory: true)
}
