import SwiftUI
import SwiftData

struct FlashcardsView: View {
    @Query(sort: \VocabEntry.createdAt) private var entries: [VocabEntry]

    @State private var isRevealed = false
    @State private var sessionQueueIDs: [UUID] = []
    @State private var revisitCounts: [UUID: Int] = [:]
    @State private var sessionReviewed = 0
    @State private var sessionCorrect = 0

    private let scheduler = SM2Scheduler()

    private var entryByID: [UUID: VocabEntry] {
        Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
    }

    private var learningEntries: [VocabEntry] {
        FlashcardDeck.learningEntries(from: entries)
    }

    private var dueEntries: [VocabEntry] {
        FlashcardDeck.dueEntries(from: entries)
    }

    private var nextDueDate: Date? {
        FlashcardDeck.nextDueDate(from: entries)
    }

    private var currentEntry: VocabEntry? {
        guard let id = sessionQueueIDs.first else { return nil }
        return entryByID[id]
    }

    private var accuracyText: String {
        guard sessionReviewed > 0 else { return "-" }
        let value = (Double(sessionCorrect) / Double(sessionReviewed)) * 100
        return "\(Int(round(value)))%"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        SectionCard("Review") {
                            HStack(spacing: 10) {
                                VocabMetricPill(title: "Due", value: "\(dueEntries.count)", tint: Theme.accent)
                                VocabMetricPill(title: "Queue", value: "\(sessionQueueIDs.count)", tint: Theme.learningHighlight)
                                VocabMetricPill(title: "Accuracy", value: accuracyText, tint: Theme.knownHighlight)
                            }
                        }

                        if let entry = currentEntry {
                            cardContent(for: entry)
                        } else if dueEntries.isEmpty {
                            noDueContent
                        } else {
                            startSessionContent
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Flashcards")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private func cardContent(for entry: VocabEntry) -> some View {
        VStack(spacing: 14) {
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
                    HStack {
                        Text(entry.status.levelBadgeLabel)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .foregroundStyle(.white)
                            .background(Theme.statusTint(entry.status), in: Capsule())

                        Spacer()

                        if let dueAt = entry.dueAt {
                            Text("Due \(dueAt, style: .relative)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Due now")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 4)

                    Text(entry.word)
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    Group {
                        if isRevealed {
                            Text(entry.meaning.isEmpty ? "No meaning yet." : entry.meaning)
                                .font(Theme.readingFont)
                                .foregroundStyle(entry.meaning.isEmpty ? .secondary : .primary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                        } else {
                            Label("Reveal meaning", systemImage: "hand.tap")
                                .font(Theme.readingFont)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(minHeight: 44)

                    Spacer(minLength: 4)

                    if isRevealed {
                        reviewButtonRow(for: entry)
                    } else {
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                isRevealed = true
                            }
                        } label: {
                            Text("Reveal")
                                .font(.headline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Theme.accent.opacity(0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
            }
            .frame(minHeight: 340)

            Button {
                markCurrentKnown()
            } label: {
                Label("Mark Known", systemImage: "checkmark.circle")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .animation(.easeInOut(duration: 0.18), value: isRevealed)
    }

    private var startSessionContent: some View {
        SectionCard("Ready") {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(dueEntries.count) words are due now.")
                    .font(Theme.readingEmphasisFont)

                Text("Start a focused review session with spaced repetition scheduling.")
                    .font(Theme.readingFont)
                    .foregroundStyle(.secondary)

                Button {
                    startSession()
                } label: {
                    Label("Start Session", systemImage: "play.fill")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.accent.opacity(0.2), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var noDueContent: some View {
        SectionCard("No Cards Due") {
            VStack(alignment: .leading, spacing: 10) {
                Text("You are caught up.")
                    .font(Theme.readingEmphasisFont)

                if let nextDueDate {
                    Text("Next card is due \(nextDueDate, style: .relative).")
                        .font(Theme.readingFont)
                        .foregroundStyle(.secondary)
                } else if learningEntries.isEmpty {
                    Text("Add words from Reader to start building a review queue.")
                        .font(Theme.readingFont)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No cards are currently scheduled.")
                        .font(Theme.readingFont)
                        .foregroundStyle(.secondary)
                }

                if sessionReviewed > 0 {
                    Text("Session: \(sessionReviewed) reviewed · \(accuracyText) correct")
                        .subtleMetadataPillStyle()
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func reviewButtonRow(for entry: VocabEntry) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                reviewButton(for: .again, entry: entry)
                reviewButton(for: .hard, entry: entry)
                reviewButton(for: .good, entry: entry)
                reviewButton(for: .easy, entry: entry)
            }
        }
    }

    private func reviewButton(for rating: ReviewRating, entry: VocabEntry) -> some View {
        let interval = scheduler.previewInterval(for: entry, rating: rating)
        return Button {
            applyReview(rating)
        } label: {
            VStack(spacing: 2) {
                Text(rating.title)
                    .font(.caption.weight(.semibold))
                Text(FlashcardDeck.intervalLabel(for: interval))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(ratingTint(rating).opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(ratingTint(rating).opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func ratingTint(_ rating: ReviewRating) -> Color {
        switch rating {
        case .again:
            return Color(red: 0.91, green: 0.35, blue: 0.29)
        case .hard:
            return Color(red: 0.94, green: 0.65, blue: 0.24)
        case .good:
            return Color(red: 0.2, green: 0.78, blue: 0.56)
        case .easy:
            return Theme.accent
        }
    }

    private func startSession() {
        sessionQueueIDs = FlashcardDeck.sessionQueueIDs(from: entries)
        revisitCounts = [:]
        sessionReviewed = 0
        sessionCorrect = 0
        isRevealed = false
    }

    private func markCurrentKnown() {
        guard let entry = currentEntry else { return }
        entry.status = .known
        entry.lastSeenAt = Date()
        entry.encounterCount += 1
        advanceQueue(after: nil, for: entry.id)
    }

    private func applyReview(_ rating: ReviewRating) {
        guard let entry = currentEntry else { return }

        let now = Date()
        scheduler.apply(rating: rating, to: entry, now: now)
        entry.encounterCount += 1

        sessionReviewed += 1
        if rating != .again {
            sessionCorrect += 1
        }

        advanceQueue(after: rating, for: entry.id)
    }

    private func advanceQueue(after rating: ReviewRating?, for currentID: UUID) {
        if let first = sessionQueueIDs.first, first == currentID {
            sessionQueueIDs.removeFirst()
        } else if let index = sessionQueueIDs.firstIndex(of: currentID) {
            sessionQueueIDs.remove(at: index)
        }

        if let rating,
           let entry = entryByID[currentID],
           entry.status.isLearning,
           shouldRequeue(currentID: currentID, rating: rating) {
            sessionQueueIDs.append(currentID)
        }

        isRevealed = false
    }

    private func shouldRequeue(currentID: UUID, rating: ReviewRating) -> Bool {
        let revisitCap: Int
        switch rating {
        case .again:
            revisitCap = 2
        case .hard:
            revisitCap = 1
        case .good, .easy:
            return false
        }

        let current = revisitCounts[currentID, default: 0]
        guard current < revisitCap else { return false }
        revisitCounts[currentID] = current + 1
        return true
    }
}

#Preview {
    FlashcardsView()
        .modelContainer(for: [VocabEntry.self], inMemory: true)
}
