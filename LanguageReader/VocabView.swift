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

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
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
                    .padding()
                }
            }
            .searchable(text: $searchText, prompt: "Search words or meanings")
            .navigationTitle("Vocab")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

private struct VocabRow: View {
    @Bindable var entry: VocabEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(entry.word)
                .font(.headline)

            if !entry.meaning.isEmpty {
                Text(entry.meaning)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Meaning not set yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                ForEach(VocabStatus.progression, id: \.rawValue) { status in
                    Button {
                        setStatus(status)
                    } label: {
                        Text(status.shortLabel)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, status.isKnown ? 10 : 12)
                            .padding(.vertical, 6)
                            .foregroundStyle(foregroundColor(for: status))
                            .background(backgroundColor(for: status), in: Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(borderColor(for: status), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Set level \(status.displayName)")
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

    private func foregroundColor(for status: VocabStatus) -> Color {
        if entry.status == status {
            return .white
        }
        return status.isKnown ? .gray : Theme.learningHighlight
    }

    private func backgroundColor(for status: VocabStatus) -> Color {
        guard entry.status == status else { return .clear }
        return status.isKnown ? Color.gray.opacity(0.75) : Theme.learningHighlight.opacity(0.88)
    }

    private func borderColor(for status: VocabStatus) -> Color {
        if entry.status == status {
            return .clear
        }
        return status.isKnown ? Color.gray.opacity(0.6) : Theme.learningHighlight.opacity(0.75)
    }
}

#Preview {
    VocabView()
        .modelContainer(for: [VocabEntry.self], inMemory: true)
}
