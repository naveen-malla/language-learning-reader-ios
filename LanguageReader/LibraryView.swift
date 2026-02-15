import SwiftUI
import SwiftData
import UIKit

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Document.updatedAt, order: .reverse) private var documents: [Document]

    @State private var suggestions: [YouTubeSuggestedVideo] = []
    @State private var hasLoadedSuggestions = false
    @State private var isLoadingSuggestions = false
    @State private var importingVideoIDs: Set<String> = []

    @State private var isShowingTextImport = false
    @State private var isShowingYouTubeImport = false
    @State private var alertMessage: String?
    @State private var readerDestination: ReaderDestination?

    static let dateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    private var continueReadingDocuments: [Document] {
        documents
            .filter(\.isOpened)
            .sorted { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) }
            .prefix(8)
            .map { $0 }
    }

    private var libraryDocuments: [Document] {
        documents.sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 14) {
                        importSection
                        continueSection
                        suggestionsSection
                        librarySection
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await refreshSuggestions(force: true) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.headline.weight(.semibold))
                    }
                    .disabled(isLoadingSuggestions)
                    .accessibilityLabel("Refresh suggestions")
                }
            }
            .task {
                await refreshSuggestions(force: false)
            }
            .sheet(isPresented: $isShowingTextImport) {
                TextImportSheet { title, body in
                    let now = Date()
                    let document = Document(
                        title: title,
                        body: body,
                        createdAt: now,
                        updatedAt: now,
                        sourceType: .text
                    )
                    modelContext.insert(document)
                }
            }
            .sheet(isPresented: $isShowingYouTubeImport) {
                YouTubeURLImportSheet { urlText in
                    try await importYouTubeURL(urlText)
                }
            }
            .fullScreenCover(item: $readerDestination) { route in
                NavigationStack {
                    DocumentReaderView(document: route.document)
                }
            }
            .alert("Import Error", isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    private var importSection: some View {
        SectionCard("Import Content") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Import text or YouTube transcripts without leaving the app.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Button {
                        isShowingTextImport = true
                    } label: {
                        Label("Paste Text", systemImage: "doc.on.clipboard")
                            .readerUtilityButtonStyle()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)

                    Button {
                        isShowingYouTubeImport = true
                    } label: {
                        Label("YouTube URL", systemImage: "play.rectangle")
                            .readerUtilityButtonStyle()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var continueSection: some View {
        if continueReadingDocuments.isEmpty {
            SectionCard("Continue Reading") {
                Text("Imported lessons will show up here after you open them once.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else {
            SectionCard("Continue Reading") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(continueReadingDocuments, id: \.id) { document in
                            NavigationLink {
                                DocumentReaderView(document: document)
                            } label: {
                                ContinueReadingCard(document: document)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var suggestionsSection: some View {
        SectionCard("Suggested for Beginners") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Kannada-only subtitle-verified picks across basics, grammar, and short stories.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if isLoadingSuggestions && suggestions.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Checking subtitle availability...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                } else if suggestions.isEmpty {
                    Text("No subtitle-verified suggestions available right now. Tap refresh.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(suggestions) { suggestion in
                                SuggestedVideoCard(
                                    suggestion: suggestion,
                                    isImporting: importingVideoIDs.contains(suggestion.videoID),
                                    onImport: { importSuggestion(suggestion) }
                                )
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    private var librarySection: some View {
        SectionCard("My Library") {
            if libraryDocuments.isEmpty {
                Text("No lessons yet. Import your first text or YouTube lesson above.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(libraryDocuments, id: \.id) { document in
                        NavigationLink {
                            DocumentReaderView(document: document)
                        } label: {
                            LibraryDocumentRow(document: document)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func refreshSuggestions(force: Bool) async {
        guard force || !hasLoadedSuggestions else { return }
        isLoadingSuggestions = true
        let loaded = await YouTubeImportService.shared.loadBeginnerSuggestions()
        suggestions = loaded
        hasLoadedSuggestions = true
        isLoadingSuggestions = false
    }

    private func importSuggestion(_ suggestion: YouTubeSuggestedVideo) {
        guard !importingVideoIDs.contains(suggestion.videoID) else { return }
        importingVideoIDs.insert(suggestion.videoID)

        Task {
            do {
                let imported = try await YouTubeImportService.shared.importVideo(videoID: suggestion.videoID)
                persistImported(content: imported, category: suggestion.category, openImmediately: true)
            } catch {
                alertMessage = error.localizedDescription
            }
            importingVideoIDs.remove(suggestion.videoID)
        }
    }

    private func importYouTubeURL(_ urlText: String) async throws {
        let imported = try await YouTubeImportService.shared.importFromURL(urlText)
        persistImported(content: imported, category: "Custom", openImmediately: true)
    }

    private func persistImported(content: ImportedYouTubeContent, category: String, openImmediately: Bool) {
        let now = Date()
        let document = Document(
            title: content.title,
            body: content.transcript,
            createdAt: now,
            updatedAt: now,
            sourceType: .youtube,
            sourceURL: content.watchURL.absoluteString,
            sourceVideoID: content.videoID,
            sourceChannel: content.channelTitle,
            sourceCategory: category,
            sourceDurationSeconds: content.durationSeconds,
            thumbnailURL: content.thumbnailURL?.absoluteString
        )

        modelContext.insert(document)

        if openImmediately {
            readerDestination = ReaderDestination(id: document.id, document: document)
        }
    }

    private struct ReaderDestination: Identifiable {
        let id: UUID
        let document: Document
    }
}

private struct ContinueReadingCard: View {
    let document: Document

    private var sourceLabel: String {
        switch document.sourceType {
        case .youtube:
            return "YouTube"
        case .sample:
            return "Sample"
        case .text:
            return "Text"
        }
    }

    private var relativeOpenTime: String {
        guard let lastOpenedAt = document.lastOpenedAt else {
            return "Not opened"
        }
        return LibraryView.dateFormatter.localizedString(for: lastOpenedAt, relativeTo: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LibraryThumbnailView(document: document)
                .frame(width: 210, height: 118)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(document.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)

            HStack(spacing: 8) {
                Text(sourceLabel)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.12), in: Capsule())

                Text(relativeOpenTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 210, alignment: .leading)
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct SuggestedVideoCard: View {
    let suggestion: YouTubeSuggestedVideo
    let isImporting: Bool
    let onImport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AsyncImage(url: suggestion.thumbnailURL) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Image(systemName: "play.rectangle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 236, height: 132)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(suggestion.category.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(suggestion.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)

            Text(suggestion.channelTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 8) {
                Text(formattedDuration(seconds: suggestion.durationSeconds))
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.accent.opacity(0.16), in: Capsule())

                Text("Kannada subtitles")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.accentSecondary.opacity(0.15), in: Capsule())
            }

            Button {
                onImport()
            } label: {
                HStack(spacing: 6) {
                    if isImporting {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(isImporting ? "Importing..." : "Import")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(.white)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isImporting)
        }
        .frame(width: 236, alignment: .leading)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }

    private func formattedDuration(seconds: Int) -> String {
        guard seconds > 0 else { return "0:00" }
        let minutes = seconds / 60
        let remainder = seconds % 60
        return "\(minutes):\(String(format: "%02d", remainder))"
    }
}

private struct LibraryDocumentRow: View {
    let document: Document

    private var previewText: String {
        document.body
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var sourceLabel: String {
        switch document.sourceType {
        case .youtube:
            return "YouTube"
        case .sample:
            return "Sample"
        case .text:
            return "Text"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            LibraryThumbnailView(document: document)
                .frame(width: 92, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                if let sourceChannel = document.sourceChannel, !sourceChannel.isEmpty {
                    Text(sourceChannel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if !previewText.isEmpty {
                    Text(previewText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    Text(sourceLabel)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.11), in: Capsule())

                    if let seconds = document.sourceDurationSeconds {
                        Text(formattedDuration(seconds: seconds))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if document.isOpened == false {
                        Text("New")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                    }
                }
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.top, 8)
        }
        .padding(10)
        .contentShape(Rectangle())
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
    }

    private func formattedDuration(seconds: Int) -> String {
        guard seconds > 0 else { return "0:00" }
        let minutes = seconds / 60
        let remainder = seconds % 60
        return "\(minutes):\(String(format: "%02d", remainder))"
    }
}

private struct LibraryThumbnailView: View {
    let document: Document

    var body: some View {
        Group {
            if let thumbnailURL = document.thumbnailURL, let url = URL(string: thumbnailURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        thumbnailFallback
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        thumbnailFallback
                    @unknown default:
                        thumbnailFallback
                    }
                }
            } else {
                thumbnailFallback
            }
        }
    }

    private var thumbnailFallback: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.accent.opacity(0.5), Theme.accentSecondary.opacity(0.45)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: document.sourceType == .youtube ? "play.rectangle.fill" : "doc.text.fill")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.92))
        }
    }
}

private struct TextImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var titleText = ""
    @State private var bodyText = ""

    let onSave: (String, String) -> Void

    private var canSave: Bool {
        !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 14) {
                        SectionCard("Import Text") {
                            VStack(alignment: .leading, spacing: 12) {
                                TextField("Title (optional)", text: $titleText)
                                    .glassInputFieldStyle()

                                TextEditor(text: $bodyText)
                                    .frame(minHeight: 220)
                                    .scrollContentBackground(.hidden)
                                    .padding(8)
                                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                                    )

                                Button {
                                    pasteFromClipboard()
                                } label: {
                                    Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                                        .readerUtilityButtonStyle()
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Paste Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        saveAndDismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func saveAndDismiss() {
        let body = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }

        let title = titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? defaultTitle()
            : titleText.trimmingCharacters(in: .whitespacesAndNewlines)

        onSave(title, body)
        dismiss()
    }

    private func defaultTitle() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Imported \(formatter.string(from: Date()))"
    }

    private func pasteFromClipboard() {
        guard let text = UIPasteboard.general.string else { return }
        bodyText = text
    }
}

private struct YouTubeURLImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var urlText = ""
    @State private var isImporting = false
    @State private var errorMessage: String?

    let onImport: (String) async throws -> Void

    private var canImport: Bool {
        !urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isImporting
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 14) {
                        SectionCard("Import YouTube Transcript") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Paste a YouTube URL. Import works only when Kannada subtitles are available.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                TextField("https://www.youtube.com/watch?v=...", text: $urlText)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)
                                    .glassInputFieldStyle()

                                if let errorMessage, !errorMessage.isEmpty {
                                    Text(errorMessage)
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }

                                if isImporting {
                                    HStack(spacing: 8) {
                                        ProgressView()
                                        Text("Importing transcript...")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("YouTube URL")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isImporting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        submitImport()
                    }
                    .disabled(!canImport)
                }
            }
        }
    }

    private func submitImport() {
        let input = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

        isImporting = true
        errorMessage = nil

        Task {
            do {
                try await onImport(input)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isImporting = false
        }
    }
}

#Preview {
    LibraryView()
        .modelContainer(for: [Document.self, VocabEntry.self], inMemory: true)
}
