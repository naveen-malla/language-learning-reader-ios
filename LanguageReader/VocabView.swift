import SwiftUI
import SwiftData

/// Displays and manages the user's vocabulary list with search functionality.
struct VocabView: View {
    @Query(sort: \VocabEntry.createdAt, order: .reverse) private var entries: [VocabEntry]
    @State private var searchText = ""

    /// Filters entries based on search text.
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

/// Displays a single vocabulary entry with word, meaning, and status.
private struct VocabRow: View {
    @Bindable var entry: VocabEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.word)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                if !entry.meaning.isEmpty {
                    Text(entry.meaning)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Meaning not set yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .italic()
                }
            }

            Spacer()

            Button {
                entry.status = entry.status.next
            } label: {
                Text(entry.status.displayName)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .foregroundStyle(Theme.statusColor(entry.status))
                    .background(Theme.statusColor(entry.status).opacity(0.15), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Status \(entry.status.displayName)")
            .accessibilityHint("Tap to cycle through learning statuses")
        }
        .cardStyle()
    }
}

#Preview {
    VocabView()
        .modelContainer(for: [VocabEntry.self], inMemory: true)
}
