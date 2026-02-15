import SwiftData
import SwiftUI
import UIKit

struct FlashcardsView: View {
    @Query(sort: \VocabEntry.createdAt) private var entries: [VocabEntry]

    @AppStorage("flashcards_simple_mode_migrated_v1") private var simpleModeMigrationApplied = false

    @State private var promptQueue: [FlashcardPrompt] = []
    @State private var pendingAnswersByWordID: [UUID: [FlashcardBinaryAnswer]] = [:]
    @State private var requeuedWordIDs: Set<UUID> = []
    @State private var isRevealed = false
    @State private var sessionReviewed = 0
    @State private var sessionCorrect = 0
    @State private var isShowingSessionSettings = false

    private let transliterator = Transliterator()

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

    private var currentPrompt: FlashcardPrompt? {
        promptQueue.first
    }

    private var currentEntry: VocabEntry? {
        guard let prompt = currentPrompt else { return nil }
        return entryByID[prompt.entryID]
    }

    private var accuracyText: String {
        guard sessionReviewed > 0 else { return "-" }
        let value = (Double(sessionCorrect) / Double(sessionReviewed)) * 100
        return "\(Int(round(value)))%"
    }

    private var progressFraction: Double {
        let total = sessionReviewed + promptQueue.count
        guard total > 0 else { return 0 }
        return Double(sessionReviewed) / Double(total)
    }

    private var hasActiveSession: Bool {
        !promptQueue.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                noirBackground

                VStack(spacing: 14) {
                    sessionTopBar
                    sessionMetrics

                    if let prompt = currentPrompt, let entry = currentEntry {
                        activeSessionContent(prompt: prompt, entry: entry)
                            .frame(maxHeight: .infinity, alignment: .top)
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    } else if sessionReviewed > 0 {
                        completedSessionContent
                            .frame(maxHeight: .infinity, alignment: .top)
                    } else if dueEntries.isEmpty {
                        noDueContent
                            .frame(maxHeight: .infinity, alignment: .top)
                    } else {
                        readyContent
                            .frame(maxHeight: .infinity, alignment: .top)
                    }
                }
                .padding(16)
            }
            .toolbar(.hidden, for: .navigationBar)
            .animation(.easeInOut(duration: 0.24), value: currentPrompt?.id)
            .sheet(isPresented: $isShowingSessionSettings) {
                sessionSettingsSheet
            }
            .onAppear {
                runSimpleModeMigrationIfNeeded()
            }
            .onChange(of: entries.count) { _, _ in
                runSimpleModeMigrationIfNeeded()
            }
        }
    }

    private var sessionTopBar: some View {
        HStack(spacing: 12) {
            Button {
                closeSession()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.08), in: Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .opacity(hasActiveSession ? 1 : 0.45)
            .disabled(!hasActiveSession)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 4)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Theme.accent, Theme.accentSecondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 4)
                    .scaleEffect(x: max(0.03, progressFraction), y: 1, anchor: .leading)
            }

            Button {
                isShowingSessionSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.08), in: Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var sessionMetrics: some View {
        HStack(spacing: 8) {
            metricPill(title: "Due", value: "\(dueEntries.count)")
            metricPill(title: "Queue", value: "\(promptQueue.count)")
            metricPill(title: "Accuracy", value: accuracyText)
        }
    }

    private func metricPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
    }

    private func activeSessionContent(prompt: FlashcardPrompt, entry: VocabEntry) -> some View {
        VStack(spacing: 14) {
            flashcardBody(prompt: prompt, entry: entry)

            if isRevealed {
                HStack(spacing: 10) {
                    answerButton(title: "Wrong", tint: Color(red: 0.89, green: 0.35, blue: 0.35), icon: "xmark") {
                        submitAnswer(.wrong)
                    }

                    answerButton(title: "Correct", tint: Color(red: 0.12, green: 0.72, blue: 0.44), icon: "checkmark") {
                        submitAnswer(.correct)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                Button {
                    flipCard()
                } label: {
                    Label("Flip", systemImage: "arrow.triangle.2.circlepath")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Theme.accent.opacity(0.85), Theme.accentSecondary.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }

            HStack(spacing: 10) {
                secondaryDockButton(title: "Mark Known", icon: "checkmark.circle") {
                    markCurrentKnown()
                }

                secondaryDockButton(title: "Skip", icon: "forward.fill") {
                    skipCurrentPrompt()
                }
            }
        }
    }

    private func answerButton(title: String, tint: Color, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(tint.opacity(0.22), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(tint.opacity(0.75), lineWidth: 1)
                )
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private func secondaryDockButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.92))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private func flashcardBody(prompt: FlashcardPrompt, entry: VocabEntry) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .background(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Color.black.opacity(0.26))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.35),
                                    Color.white.opacity(0.08),
                                    Theme.accent.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.35), radius: 24, y: 14)

            VStack(spacing: 20) {
                HStack {
                    Text(entry.status.levelBadgeLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.statusTint(entry.status).opacity(0.65), in: Capsule())

                    Spacer()

                    Text(prompt.direction == .wordToMeaning ? "Word -> Meaning" : "Meaning -> Word")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.72))
                }

                cardContent(prompt: prompt, entry: entry)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(22)
        }
        .frame(minHeight: 430)
        .contentShape(Rectangle())
        .rotation3DEffect(
            .degrees(isRevealed ? 180 : 0),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.58
        )
        .onTapGesture {
            if !isRevealed {
                flipCard()
            }
        }
    }

    private func cardContent(prompt: FlashcardPrompt, entry: VocabEntry) -> some View {
        ZStack {
            if isRevealed {
                revealedContent(prompt: prompt, entry: entry)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                    .transition(.opacity)
            } else {
                frontContent(prompt: prompt, entry: entry)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.24), value: isRevealed)
    }

    private func frontContent(prompt: FlashcardPrompt, entry: VocabEntry) -> some View {
        VStack(spacing: 12) {
            switch prompt.direction {
            case .wordToMeaning:
                Text(entry.word)
                    .font(.system(size: 42, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)

                if let transliteration = transliteration(for: entry.word) {
                    Text(transliteration)
                        .font(.system(size: 21, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(red: 0.66, green: 0.83, blue: 0.92))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }

            case .meaningToWord:
                Text(entry.meaning.isEmpty ? "No meaning available yet." : entry.meaning)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func revealedContent(prompt: FlashcardPrompt, entry: VocabEntry) -> some View {
        VStack(spacing: 12) {
            switch prompt.direction {
            case .wordToMeaning:
                Text(entry.meaning.isEmpty ? "No meaning available yet." : entry.meaning)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

            case .meaningToWord:
                Text(entry.word)
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                if let transliteration = transliteration(for: entry.word) {
                    Text(transliteration)
                        .font(.system(size: 21, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(red: 0.66, green: 0.83, blue: 0.92))
                        .multilineTextAlignment(.center)
                }

                if !entry.meaning.isEmpty {
                    Text(entry.meaning)
                        .font(.system(size: 18, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var readyContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Ready to Review")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Text("\(dueEntries.count) due words will be tested in both directions with simple right/wrong feedback.")
                .font(.body.weight(.medium))
                .foregroundStyle(Color.white.opacity(0.8))
                .lineSpacing(3)

            Button {
                startSession()
            } label: {
                Label("Start Session", systemImage: "play.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Theme.accent.opacity(0.85), Theme.accentSecondary.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
            }
            .buttonStyle(PressScaleButtonStyle())
        }
        .padding(20)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }

    private var completedSessionContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Session Complete")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Text("Reviewed \(sessionReviewed) cards · Accuracy \(accuracyText)")
                .font(.body.weight(.medium))
                .foregroundStyle(Color.white.opacity(0.8))

            if dueEntries.isEmpty {
                Text("No cards are due right now.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.68))
            } else {
                Text("\(dueEntries.count) cards are still due.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.68))
            }

            Button {
                startSession()
            } label: {
                Label("Start Another Session", systemImage: "arrow.clockwise")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Theme.accent.opacity(0.85), Theme.accentSecondary.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
            }
            .buttonStyle(PressScaleButtonStyle())
        }
        .padding(20)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }

    private var noDueContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("No Cards Due")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            if learningEntries.isEmpty {
                Text("Add words from the reader to start building your flashcard queue.")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.8))
            } else if let nextDueDate {
                Text("Next card is due \(nextDueDate, style: .relative).")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.8))
            } else {
                Text("You are fully caught up.")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.8))
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }

    private var sessionSettingsSheet: some View {
        NavigationStack {
            Form {
                Section("Flashcards") {
                    HStack {
                        Text("Mode")
                        Spacer()
                        Text("Simple")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Directions")
                        Spacer()
                        Text("Both")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Progression")
                        Spacer()
                        Text("2 perfect rounds")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Session Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isShowingSessionSettings = false
                    }
                }
            }
        }
    }

    private var noirBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.043, green: 0.063, blue: 0.125),
                    Color(red: 0.071, green: 0.094, blue: 0.149),
                    Color(red: 0.039, green: 0.051, blue: 0.078)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Theme.accent.opacity(0.18), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 320
            )
            .blendMode(.screen)

            RadialGradient(
                colors: [Theme.accentSecondary.opacity(0.16), .clear],
                center: .bottomLeading,
                startRadius: 20,
                endRadius: 280
            )
            .blendMode(.screen)
        }
        .ignoresSafeArea()
    }

    private func startSession() {
        promptQueue = FlashcardDeck.sessionPrompts(from: entries)
        pendingAnswersByWordID = [:]
        requeuedWordIDs = []
        sessionReviewed = 0
        sessionCorrect = 0
        isRevealed = false
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    private func closeSession() {
        promptQueue = []
        pendingAnswersByWordID = [:]
        requeuedWordIDs = []
        sessionReviewed = 0
        sessionCorrect = 0
        isRevealed = false
    }

    private func flipCard() {
        withAnimation(.easeInOut(duration: 0.24)) {
            isRevealed = true
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func submitAnswer(_ answer: FlashcardBinaryAnswer) {
        guard let prompt = currentPrompt, let entry = currentEntry else { return }

        promptQueue.removeFirst()
        sessionReviewed += 1
        if answer == .correct {
            sessionCorrect += 1
        }
        entry.encounterCount += 1

        var roundAnswers = pendingAnswersByWordID[prompt.entryID, default: []]
        roundAnswers.append(answer)

        if roundAnswers.count == 2 {
            let now = Date()
            let currentStreak = max(0, entry.srsRepetition ?? 0)
            let outcome = FlashcardRoundEvaluator.evaluate(
                status: entry.status,
                consecutiveSuccessRounds: currentStreak,
                answers: roundAnswers
            )

            entry.status = outcome.status
            entry.srsRepetition = outcome.nextConsecutiveSuccessRounds
            entry.lastSeenAt = now
            entry.dueAt = SimpleLevelScheduler.nextDueDate(for: outcome.status, now: now)
            entry.srsIntervalDays = SimpleLevelScheduler.intervalDays(for: outcome.status).map(Double.init)
            entry.srsAlgorithm = nil

            pendingAnswersByWordID[prompt.entryID] = nil

            if outcome.shouldRequeue,
               outcome.status.isLearning,
               requeuedWordIDs.contains(prompt.entryID) == false {
                promptQueue.append(contentsOf: FlashcardDeck.prompts(for: prompt.entryID))
                requeuedWordIDs.insert(prompt.entryID)
            }
        } else {
            pendingAnswersByWordID[prompt.entryID] = roundAnswers
        }

        isRevealed = false
        haptic(for: answer)
    }

    private func haptic(for answer: FlashcardBinaryAnswer) {
        switch answer {
        case .wrong:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .correct:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private func markCurrentKnown() {
        guard let entry = currentEntry else { return }

        let now = Date()
        entry.status = .known
        entry.srsRepetition = 0
        entry.lastSeenAt = now
        entry.dueAt = nil
        entry.srsIntervalDays = nil
        entry.srsAlgorithm = nil
        entry.encounterCount += 1

        pendingAnswersByWordID[entry.id] = nil
        requeuedWordIDs.remove(entry.id)
        promptQueue.removeAll { $0.entryID == entry.id }
        isRevealed = false

        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func skipCurrentPrompt() {
        guard let prompt = currentPrompt else { return }
        promptQueue.removeFirst()
        promptQueue.append(prompt)
        isRevealed = false
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    private func runSimpleModeMigrationIfNeeded() {
        guard simpleModeMigrationApplied == false else { return }
        guard entries.isEmpty == false else { return }

        for entry in FlashcardDeck.learningEntries(from: entries) {
            let baseDate = max(entry.lastSeenAt, entry.createdAt)
            entry.srsRepetition = 0
            entry.dueAt = SimpleLevelScheduler.dueDate(for: entry.status, baseDate: baseDate)
            entry.srsIntervalDays = SimpleLevelScheduler.intervalDays(for: entry.status).map(Double.init)
            entry.srsAlgorithm = nil
        }

        simpleModeMigrationApplied = true
    }

    private func transliteration(for word: String) -> String? {
        let value = transliterator.pronounce(word).trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.isEmpty == false else { return nil }
        guard value.caseInsensitiveCompare(word) != .orderedSame else { return nil }
        return value
    }
}

private struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

#Preview {
    FlashcardsView()
        .modelContainer(for: [VocabEntry.self], inMemory: true)
}
