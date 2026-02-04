import SwiftUI
import SwiftData

/// Flashcard review interface for practicing vocabulary.
struct FlashcardsView: View {
    @Query(sort: \VocabEntry.createdAt) private var entries: [VocabEntry]
    @State private var isRevealed = false
    @State private var currentIndex = 0

    /// Returns all available vocabulary entries for review.
    private var availableEntries: [VocabEntry] {
        entries
    }

    /// Returns the current flashcard entry, safely clamped to valid index.
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
                                .accessibilityLabel("Flashcard word: \(entry.word)")

                            if isRevealed {
                                Text(entry.meaning.isEmpty ? "No meaning yet." : entry.meaning)
                                    .font(.title3)
                                    .foregroundStyle(entry.meaning.isEmpty ? .secondary : .primary)
                                    .multilineTextAlignment(.center)
                                    .accessibilityLabel("Meaning: \(entry.meaning.isEmpty ? "not available" : entry.meaning)")
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
                        .accessibilityHint("Tap to \(isRevealed ? "hide" : "reveal") meaning")

                        HStack(spacing: 16) {
                            Button {
                                mark(entry: entry, status: .learning)
                            } label: {
                                Text("Still Learning")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Mark as still learning")
                            .accessibilityHint("Updates status and shows next card")

                            Button {
                                mark(entry: entry, status: .known)
                            } label: {
                                Text("Mark Known")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityLabel("Mark as known")
                            .accessibilityHint("Updates status and shows next card")
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

    /// Marks the current entry with a status and advances to the next card.
    /// - Parameters:
    ///   - entry: The vocabulary entry to mark.
    ///   - status: The new status to assign.
    private func mark(entry: VocabEntry, status: VocabStatus) {
        entry.status = status
        entry.lastSeenAt = Date()
        entry.encounterCount += 1
        isRevealed = false
        advance()
    }

    /// Advances to the next flashcard in the sequence.
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
