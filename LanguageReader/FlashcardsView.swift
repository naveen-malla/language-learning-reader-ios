import SwiftUI
import SwiftData
import UIKit

struct FlashcardsView: View {
    @Query(sort: \VocabEntry.createdAt) private var entries: [VocabEntry]

    @State private var isRevealed = false
    @State private var sessionQueueIDs: [UUID] = []
    @State private var revisitCounts: [UUID: Int] = [:]
    @State private var sessionReviewed = 0
    @State private var sessionCorrect = 0

    private let scheduler = SpacedRepetitionEngine(algorithm: .fsrs)

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

    private var progressFraction: Double {
        let total = sessionReviewed + sessionQueueIDs.count
        guard total > 0 else { return 0 }
        return Double(sessionReviewed) / Double(total)
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
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        } else if sessionReviewed > 0 {
                            sessionSummaryContent
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
            .animation(.spring(response: 0.35, dampingFraction: 0.88), value: sessionQueueIDs.first)
        }
    }

    private func cardContent(for entry: VocabEntry) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                ProgressView(value: progressFraction)
                    .progressViewStyle(.linear)
                Text("\(sessionReviewed) done")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)

            ZStack {
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Theme.cardBackground,
                                Theme.cardBackground.opacity(0.98),
                                Theme.accent.opacity(0.07)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                            .stroke(Theme.surfaceStroke, lineWidth: 1)
                    )

                Circle()
                    .fill(Theme.accent.opacity(0.12))
                    .frame(width: 160, height: 160)
                    .offset(x: 130, y: -140)
                    .blur(radius: 1)

                Circle()
                    .fill(Theme.accentSecondary.opacity(0.12))
                    .frame(width: 190, height: 190)
                    .offset(x: -140, y: 140)
                    .blur(radius: 1)

                VStack(spacing: 16) {
                    HStack {
                        Text(entry.status.levelBadgeLabel)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .foregroundStyle(.white)
                            .background(Theme.statusTint(entry.status), in: Capsule())

                        Spacer()

                        Text("FSRS")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .foregroundStyle(.secondary)
                            .background(Color.primary.opacity(0.08), in: Capsule())
                    }

                    flashcardFace(for: entry)
                        .frame(maxWidth: .infinity, minHeight: 190)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            toggleReveal()
                        }

                    if isRevealed {
                        reviewButtonRow(for: entry)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        Button {
                            toggleReveal()
                        } label: {
                            Text("Reveal")
                                .font(.headline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Theme.accent.opacity(0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

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
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
            }
            .frame(minHeight: 390)
        }
        .animation(.easeInOut(duration: 0.2), value: isRevealed)
    }

    private func flashcardFace(for entry: VocabEntry) -> some View {
        ZStack {
            VStack(spacing: 10) {
                Text(entry.word)
                    .font(.system(size: 38, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)

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
            .opacity(isRevealed ? 0 : 1)

            VStack(spacing: 12) {
                Text(entry.word)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(entry.meaning.isEmpty ? "No meaning yet." : entry.meaning)
                    .font(Theme.readingFont)
                    .foregroundStyle(entry.meaning.isEmpty ? .secondary : .primary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            .opacity(isRevealed ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
        .rotation3DEffect(
            .degrees(isRevealed ? 180 : 0),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.55
        )
    }

    private var startSessionContent: some View {
        SectionCard("Ready") {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(dueEntries.count) words are due now.")
                    .font(Theme.readingEmphasisFont)

                Text("Start a focused review session with adaptive spaced repetition scheduling.")
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

    private var sessionSummaryContent: some View {
        SectionCard("Session Complete") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Reviewed \(sessionReviewed) words")
                    .font(Theme.readingEmphasisFont)

                HStack(spacing: 8) {
                    Text("Accuracy \(accuracyText)")
                        .subtleMetadataPillStyle()
                    Text("Remaining due \(dueEntries.count)")
                        .subtleMetadataPillStyle()
                }
                .foregroundStyle(.secondary)

                if dueEntries.isEmpty {
                    Text("No cards are currently due.")
                        .font(Theme.readingFont)
                        .foregroundStyle(.secondary)
                }

                Button {
                    startSession()
                } label: {
                    Label(dueEntries.isEmpty ? "Start New Session" : "Review Remaining", systemImage: "arrow.clockwise")
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
            }
        }
    }

    private func reviewButtonRow(for entry: VocabEntry) -> some View {
        HStack(spacing: 8) {
            reviewButton(for: .again, entry: entry)
            reviewButton(for: .hard, entry: entry)
            reviewButton(for: .good, entry: entry)
            reviewButton(for: .easy, entry: entry)
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
            .padding(.vertical, 9)
            .background(
                LinearGradient(
                    colors: [
                        ratingTint(rating).opacity(0.23),
                        ratingTint(rating).opacity(0.14)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
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
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    private func toggleReveal() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isRevealed.toggle()
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func markCurrentKnown() {
        guard let entry = currentEntry else { return }
        entry.status = .known
        entry.lastSeenAt = Date()
        entry.encounterCount += 1
        UINotificationFeedbackGenerator().notificationOccurred(.success)
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

        haptic(for: rating)
        advanceQueue(after: rating, for: entry.id)
    }

    private func haptic(for rating: ReviewRating) {
        switch rating {
        case .again:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .hard:
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        case .good:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .easy:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
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
