import SwiftUI
import SwiftData

struct VocabView: View {
    @Query(sort: \VocabEntry.createdAt, order: .reverse) private var entries: [VocabEntry]
    @State private var searchText = ""

    private var filteredEntries: [VocabEntry] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return entries }
        return entries.filter { entry in
            entry.word.localizedCaseInsensitiveContains(trimmed) ||
            entry.meaning.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private var knownCount: Int {
        entries.filter { $0.status == .known }.count
    }

    private var learningCount: Int {
        entries.filter { $0.status.isLearning }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if !entries.isEmpty {
                            SectionCard("Progress") {
                                HStack(spacing: 10) {
                                    VocabMetricPill(
                                        title: "Total",
                                        value: "\(entries.count)",
                                        tint: Theme.accent
                                    )

                                    VocabMetricPill(
                                        title: "Learning",
                                        value: "\(learningCount)",
                                        tint: Theme.learningHighlight
                                    )

                                    VocabMetricPill(
                                        title: "Known",
                                        value: "\(knownCount)",
                                        tint: Theme.knownHighlight
                                    )
                                }
                            }
                        }

                        if filteredEntries.isEmpty {
                            ContentUnavailableView {
                                Label("No vocabulary yet", systemImage: "text.book.closed")
                            } description: {
                                Text(searchText.isEmpty ? "Save words from the Reader to see them here." : "No matching words found.")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(filteredEntries) { entry in
                                    VocabRow(entry: entry)
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .searchable(text: $searchText, prompt: "Search words or meanings")
            .navigationTitle("Vocab")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct VocabMetricPill: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct VocabRow: View {
    @Bindable var entry: VocabEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.word)
                    .font(.title3.weight(.semibold))

                Spacer()

                Text(entry.status.levelBadgeLabel)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundStyle(.white)
                    .background(Theme.statusTint(entry.status), in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            }

            if !entry.meaning.isEmpty {
                Text(entry.meaning)
                    .font(Theme.readingFont)
                    .foregroundStyle(.secondary)
            } else {
                Text("Meaning not set yet")
                    .font(Theme.readingFont)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Text("Seen \(entry.encounterCount)x")
                    .subtleMetadataPillStyle()
                    .foregroundStyle(.secondary)

                Text("Updated \(entry.lastSeenAt, style: .relative)")
                    .subtleMetadataPillStyle()
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(VocabStatus.progression, id: \.rawValue) { status in
                        StatusLevelChip(
                            status: status,
                            selectedStatus: entry.status,
                            onSelect: { selected in
                                setStatus(selected)
                            }
                        )
                    }
                }
            }
        }
        .cardStyle()
    }

    private func setStatus(_ status: VocabStatus) {
        entry.status = status
        entry.lastSeenAt = Date()
        entry.encounterCount += 1
    }
}

#Preview {
    VocabView()
        .modelContainer(for: [VocabEntry.self], inMemory: true)
}
