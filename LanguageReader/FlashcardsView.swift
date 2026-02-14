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

    private var knownCount: Int {
        availableEntries.filter { $0.status == .known }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 18) {
                        if !availableEntries.isEmpty {
                            SectionCard("Session") {
                                HStack(spacing: 10) {
                                    VocabMetricPill(
                                        title: "Deck",
                                        value: "\(availableEntries.count)",
                                        tint: Theme.accent
                                    )

                                    VocabMetricPill(
                                        title: "Known",
                                        value: "\(knownCount)",
                                        tint: Theme.knownHighlight
                                    )

                                    VocabMetricPill(
                                        title: "Index",
                                        value: "\(min(currentIndex + 1, max(availableEntries.count, 1)))",
                                        tint: Theme.learningHighlight
                                    )
                                }
                            }
                        }

                        if let entry = currentEntry {
                            ZStack {
                                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Theme.cardBackground,
                                                Theme.cardBackground.opacity(0.98),
                                                Theme.accent.opacity(0.08)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                                            .stroke(Theme.surfaceStroke, lineWidth: 1)
                                    )

                                VStack(spacing: 16) {
                                    Text(entry.word)
                                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                                        .multilineTextAlignment(.center)

                                    Text(entry.status.levelBadgeLabel)
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .foregroundStyle(.white)
                                        .background(Theme.statusTint(entry.status), in: Capsule())

                                    ZStack {
                                        if isRevealed {
                                            Text(entry.meaning.isEmpty ? "No meaning yet." : entry.meaning)
                                                .font(Theme.readingFont)
                                                .foregroundStyle(entry.meaning.isEmpty ? .secondary : .primary)
                                                .multilineTextAlignment(.center)
                                                .lineSpacing(3)
                                                .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.96)), removal: .opacity))
                                        } else {
                                            Label("Tap to reveal", systemImage: "hand.tap")
                                                .font(Theme.readingFont)
                                                .foregroundStyle(.secondary)
                                                .transition(.asymmetric(insertion: .opacity, removal: .opacity.combined(with: .scale(scale: 0.96))))
                                        }
                                    }
                                    .frame(minHeight: 42)
                                    .animation(.easeInOut(duration: 0.2), value: isRevealed)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 28)
                            }
                            .frame(maxWidth: .infinity, minHeight: 300)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isRevealed.toggle()
                                }
                            }
                            .accessibilityLabel("Flashcard")
                            .accessibilityHint("Tap to reveal meaning")

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(VocabStatus.progression, id: \.rawValue) { status in
                                        StatusLevelChip(
                                            status: status,
                                            selectedStatus: entry.status,
                                            onSelect: { selected in
                                                setLevel(entry: entry, status: selected)
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal, 2)
                            }
                        } else {
                            ContentUnavailableView {
                                Label("No flashcards yet", systemImage: "rectangle.stack")
                            } description: {
                                Text("Add words in the Reader to start practicing.")
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, 40)
                        }
                    }
                    .padding(16)
                }
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
}

#Preview {
    FlashcardsView()
        .modelContainer(for: [VocabEntry.self], inMemory: true)
}
