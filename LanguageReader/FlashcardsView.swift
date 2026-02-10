import SwiftUI
import SwiftData

struct FlashcardsView: View {
    @Query(sort: \VocabEntry.createdAt) private var entries: [VocabEntry]
    @State private var isRevealed = false
    @State private var currentIndex = 0

    private var availableEntries: [VocabEntry] {
        FlashcardDeck.reviewEntries(from: entries)
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

                            Text(entry.status.levelBadgeLabel)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .foregroundStyle(.white)
                                .background(Theme.learningHighlight.opacity(0.85), in: Capsule())

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

                        HStack(spacing: 8) {
                            ForEach(VocabStatus.progression, id: \.rawValue) { status in
                                Button {
                                    setLevel(entry: entry, status: status)
                                } label: {
                                    Text(status.shortLabel)
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, status.isKnown ? 10 : 12)
                                        .padding(.vertical, 8)
                                        .foregroundStyle(foregroundColor(for: status, current: entry.status))
                                        .background(backgroundColor(for: status, current: entry.status), in: Capsule())
                                        .overlay(
                                            Capsule()
                                                .stroke(borderColor(for: status, current: entry.status), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Set level \(status.displayName)")
                            }
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

    private func setLevel(entry: VocabEntry, status: VocabStatus) {
        entry.status = status
        entry.lastSeenAt = Date()
        entry.encounterCount += 1
        isRevealed = false
        advance()
    }

    private func advance() {
        let count = availableEntries.count
        guard count > 0 else {
            currentIndex = 0
            return
        }
        currentIndex = FlashcardNavigator.nextIndex(current: currentIndex, count: count)
    }

    private func foregroundColor(for status: VocabStatus, current: VocabStatus) -> Color {
        if status == current {
            return .white
        }
        return status.isKnown ? .gray : Theme.learningHighlight
    }

    private func backgroundColor(for status: VocabStatus, current: VocabStatus) -> Color {
        if status == current {
            return status.isKnown ? Color.gray.opacity(0.75) : Theme.learningHighlight.opacity(0.85)
        }
        return status.isKnown ? Color.gray.opacity(0.12) : Theme.learningHighlight.opacity(0.12)
    }

    private func borderColor(for status: VocabStatus, current: VocabStatus) -> Color {
        if status == current {
            return .clear
        }
        return status.isKnown ? Color.gray.opacity(0.7) : Theme.learningHighlight.opacity(0.75)
    }
}

#Preview {
    FlashcardsView()
        .modelContainer(for: [VocabEntry.self], inMemory: true)
}
