import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Document.updatedAt, order: .reverse) private var documents: [Document]

    @State private var suggestions: [YouTubeSuggestedVideo] = []
    @State private var hasLoadedSuggestions = false
    @State private var isLoadingSuggestions = false
    @State private var importingVideoIDs: Set<String> = []
    @State private var isImportingSmartPack = false
    @State private var lastAutoTopUpLanguageCode: String?
    @State private var smartPackStatusMessage: String?
    @State private var lastDiscoveryRefreshAt: Date?
    @State private var nextDiscoveryRetryAt: Date?
    @State private var libraryFilter: LibraryFilter = .all

    @State private var isShowingTextImport = false
    @State private var isShowingYouTubeImport = false
    @State private var isShowingFileImport = false
    @State private var alertMessage: String?
    @State private var readerDestination: ReaderDestination?
    @AppStorage("library.followed_channels.v1") private var followedChannelsRaw = ""
    @AppStorage(AutoImportSettings.allowRepeatImportsKey) private var allowRepeatImports = AutoImportSettings.defaultAllowRepeatImports
    @AppStorage(StudyLanguageSettingsStore.studyLanguageKey) private var studyLanguageCode = SupportedLanguage.freshInstallDefault.rawValue

    static let dateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    private enum LibraryFilter: String, CaseIterable, Identifiable {
        case all
        case unread
        case opened

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return "All"
            case .unread: return "Unread"
            case .opened: return "Opened"
            }
        }
    }

    private var continueReadingDocuments: [Document] {
        uniqueLibraryDocuments
            .filter(\.isOpened)
            .sorted { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) }
            .prefix(8)
            .map { $0 }
    }

    private var libraryDocuments: [Document] {
        uniqueLibraryDocuments.sorted { $0.updatedAt > $1.updatedAt }
    }

    private var filteredLibraryDocuments: [Document] {
        switch libraryFilter {
        case .all:
            return libraryDocuments
        case .unread:
            return libraryDocuments.filter { $0.isOpened == false }
        case .opened:
            return libraryDocuments.filter(\.isOpened)
        }
    }

    private var queueDocuments: [Document] {
        uniqueLibraryDocuments
            .filter { $0.sourceType == .youtube && $0.isOpened == false }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var totalYouTubeLessons: Int {
        uniqueLibraryDocuments.filter { $0.sourceType == .youtube }.count
    }

    private var openedLessonCount: Int {
        uniqueLibraryDocuments.filter(\.isOpened).count
    }

    private var pullTargetCount: Int {
        AutoImportSettings.smartPackTargetCount
    }

    private var nextQueueDocument: Document? {
        queueDocuments.first
    }

    private var importedVideoIDs: Set<String> {
        Set(uniqueLibraryDocuments.compactMap(\.sourceVideoID))
    }

    private var knownImportedVideoIDs: Set<String> {
        let historical = UserDefaults.standard.stringArray(
            forKey: AutoImportSettings.historicalImportedVideoIDsKey(for: selectedStudyLanguage)
        ) ?? []
        return importedVideoIDs.union(historical)
    }

    private var importedDocumentByVideoID: [String: Document] {
        uniqueLibraryDocuments.reduce(into: [:]) { result, document in
            guard let videoID = document.sourceVideoID else { return }
            if let current = result[videoID], current.updatedAt > document.updatedAt {
                return
            }
            result[videoID] = document
        }
    }

    private var newFeedSuggestions: [YouTubeSuggestedVideo] {
        suggestions.filter { !knownImportedVideoIDs.contains($0.videoID) }
    }

    private var importedFeedSuggestions: [YouTubeSuggestedVideo] {
        suggestions.filter { knownImportedVideoIDs.contains($0.videoID) }
    }

    private var uniqueLibraryDocuments: [Document] {
        var seenVideoIDs: Set<String> = []
        var unique: [Document] = []
        for document in selectedLanguageDocuments.sorted(by: { $0.updatedAt > $1.updatedAt }) {
            guard document.sourceType == .youtube,
                  let sourceVideoID = document.sourceVideoID else {
                unique.append(document)
                continue
            }
            if seenVideoIDs.contains(sourceVideoID) {
                continue
            }
            seenVideoIDs.insert(sourceVideoID)
            unique.append(document)
        }
        return unique
    }

    private var selectedStudyLanguage: SupportedLanguage {
        SupportedLanguage.resolve(studyLanguageCode) ?? .freshInstallDefault
    }

    private var selectedLanguageDocuments: [Document] {
        documents.filter { $0.languageCode == selectedStudyLanguage }
    }

    private var rankingContext: SuggestionRankingContext {
        let followed = Set(
            followedChannelsRaw
                .split(separator: "|")
                .map { SuggestionRanker.normalizeChannel(String($0)) }
                .filter { !$0.isEmpty }
        )

        var categoryHistory: [String: Int] = [:]
        var channelHistory: [String: Int] = [:]

        for document in selectedLanguageDocuments where document.sourceType == .youtube {
            if let category = document.sourceCategory {
                let key = SuggestionRanker.normalizeCategory(category)
                if !key.isEmpty {
                    categoryHistory[key, default: 0] += 1
                }
            }

            if let channel = document.sourceChannel {
                let key = SuggestionRanker.normalizeChannel(channel)
                if !key.isEmpty {
                    channelHistory[key, default: 0] += 1
                }
            }
        }

        return SuggestionRankingContext(
            followedChannels: followed,
            categoryHistory: categoryHistory,
            channelHistory: channelHistory
        )
    }

    private var rankingFingerprint: String {
        let followed = rankingContext.followedChannels.sorted().joined(separator: "|")
        let categories = rankingContext.categoryHistory
            .sorted { $0.key < $1.key }
            .map { "\($0.key):\($0.value)" }
            .joined(separator: "|")
        let channels = rankingContext.channelHistory
            .sorted { $0.key < $1.key }
            .map { "\($0.key):\($0.value)" }
            .joined(separator: "|")
        return [followed, categories, channels].joined(separator: "||")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        heroSection
                        importSection
                        queueSection
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
                ToolbarItem(placement: .topBarLeading) {
                    StudyLanguageToolbarMenu(selection: $studyLanguageCode)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await refreshSuggestions(force: true) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.headline.weight(.semibold))
                    }
                    .disabled(isLoadingSuggestions)
                    .accessibilityLabel("Refresh discovery feed")
                }
            }
            .task(id: selectedStudyLanguage.rawValue) {
                hasLoadedSuggestions = false
                await refreshSuggestions(force: false)
                if lastAutoTopUpLanguageCode != selectedStudyLanguage.rawValue {
                    lastAutoTopUpLanguageCode = selectedStudyLanguage.rawValue
                    await runAutoTopUpIfNeeded()
                }
            }
            .sheet(isPresented: $isShowingTextImport) {
                TextImportSheet(language: selectedStudyLanguage) { title, body in
                    let now = Date()
                    let document = Document(
                        title: title,
                        body: body,
                        languageCode: selectedStudyLanguage,
                        createdAt: now,
                        updatedAt: now,
                        sourceType: .text
                    )
                    modelContext.insert(document)
                }
            }
            .sheet(isPresented: $isShowingYouTubeImport) {
                YouTubeURLImportSheet(language: selectedStudyLanguage) { urlText in
                    try await importYouTubeURL(urlText)
                }
            }
            .fileImporter(
                isPresented: $isShowingFileImport,
                allowedContentTypes: [.plainText, .text],
                allowsMultipleSelection: false
            ) { result in
                handleTextFileImport(result)
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
            .onChange(of: rankingFingerprint) { _, _ in
                suggestions = SuggestionRanker.rank(suggestions, context: rankingContext)
            }
        }
    }

    private var importSection: some View {
        SectionCard("Lesson Intake") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Press once to pull \(pullTargetCount) subtitle-ready \(selectedStudyLanguage.displayName) lessons into your queue.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Pull window: 5 to 20 minutes. Manual import options remain available below.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    runSmartPackImport()
                } label: {
                    HStack(spacing: 8) {
                        if isImportingSmartPack {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isImportingSmartPack ? "Pulling Lessons..." : "Pull \(pullTargetCount) New Lessons")
                            .font(.headline.weight(.semibold))
                        Spacer(minLength: 8)
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.headline.weight(.bold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .foregroundStyle(.white)
                    .background(
                        LinearGradient(
                            colors: [Theme.accent, Theme.accentSecondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isImportingSmartPack)

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

                Button {
                    isShowingFileImport = true
                } label: {
                    Label("Text File", systemImage: "doc.text")
                        .readerUtilityButtonStyle()
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)

                HStack(spacing: 8) {
                    Text("Studying \(selectedStudyLanguage.displayName)")
                        .subtleMetadataPillStyle()
                        .foregroundStyle(.secondary)
                    StudyLanguageBadge(language: selectedStudyLanguage)
                }

                HStack(spacing: 8) {
                    LibraryCountPill(label: "Queue", value: queueDocuments.count)
                    LibraryCountPill(label: "New Feed", value: newFeedSuggestions.count)
                    LibraryCountPill(label: "In Library", value: importedFeedSuggestions.count)
                }

                if let smartPackStatusMessage {
                    Text(smartPackStatusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let lastDiscoveryRefreshAt {
                    Text("Feed refreshed \(LibraryView.dateFormatter.localizedString(for: lastDiscoveryRefreshAt, relativeTo: Date())).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let nextDiscoveryRetryAt, nextDiscoveryRetryAt > Date() {
                    Text("Network backoff active until \(nextDiscoveryRetryAt.formatted(date: .omitted, time: .shortened)).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if allowRepeatImports {
                    Text("Lesson pull can reuse already-known videos when fresh uploads are not available.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var heroSection: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Theme.accent.opacity(0.6),
                            Theme.accentSecondary.opacity(0.52),
                            Color.black.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(Color.white.opacity(0.16))
                .frame(width: 150, height: 150)
                .blur(radius: 10)
                .offset(x: 210, y: -50)

            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 120, height: 120)
                .blur(radius: 10)
                .offset(x: -40, y: 100)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(selectedStudyLanguage.displayName) Learning Console")
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(.white)

                        Text("Fresh subtitle-ready \(selectedStudyLanguage.displayName.lowercased()) lessons, organized for daily momentum.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.92))
                    }
                    Spacer(minLength: 6)
                    Image(systemName: "sparkles.tv.fill")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.95))
                }

                HStack(spacing: 8) {
                    LibraryHeroMetric(label: "Unread", value: queueDocuments.count)
                    LibraryHeroMetric(label: "Opened", value: openedLessonCount)
                    LibraryHeroMetric(label: "Total", value: totalYouTubeLessons)
                    LibraryHeroMetric(label: "Fresh Feed", value: newFeedSuggestions.count)
                }

                if let nextQueueDocument {
                    Text("Up next: \(nextQueueDocument.title)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.95))
                        .lineLimit(1)
                } else {
                    Text("Queue is clear. Pull \(pullTargetCount) lessons to continue.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding(16)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var queueSection: some View {
        SectionCard("Unread Lesson Queue") {
            if queueDocuments.isEmpty {
                Text("Queue is empty right now. Pull \(pullTargetCount) lessons to refill it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    if let firstUnread = queueDocuments.first {
                        Button {
                            readerDestination = ReaderDestination(id: firstUnread.id, document: firstUnread)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "play.circle.fill")
                                Text("Open Next Unread Lesson")
                                Spacer(minLength: 8)
                                Text("\(queueDocuments.count) pending")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.1), in: Capsule())
                            }
                            .readerUtilityButtonStyle()
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(queueDocuments.prefix(8), id: \.id) { document in
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
        SectionCard("Discovery Feed") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Subtitle-ready videos are split into new lessons and already-imported lessons so you can see exactly what is fresh.")
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
                    Text("Feed is temporarily empty. Tap refresh and pull again.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            LibraryCountPill(label: "New", value: newFeedSuggestions.count)
                            LibraryCountPill(label: "Imported", value: importedFeedSuggestions.count)
                            LibraryCountPill(label: "Total", value: suggestions.count)
                        }

                        Text("New to Import")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        if newFeedSuggestions.isEmpty {
                            Text("No unseen lessons in the current feed. Pull again to refresh ranking and refill.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(newFeedSuggestions.prefix(12)) { suggestion in
                                    SuggestedVideoRow(
                                        suggestion: suggestion,
                                        isFollowingChannel: isFollowingChannel(suggestion.channelTitle),
                                        isImporting: importingVideoIDs.contains(suggestion.videoID),
                                        isAlreadyImported: false,
                                        importStateText: nil,
                                        onImport: { importSuggestion(suggestion) },
                                        onOpenImported: nil,
                                        onToggleFollow: { toggleFollowChannel(suggestion.channelTitle) }
                                    )
                                }
                            }
                        }

                        if !importedFeedSuggestions.isEmpty {
                            Divider()

                            Text("Already in Library")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            VStack(spacing: 10) {
                                ForEach(importedFeedSuggestions.prefix(10)) { suggestion in
                                    SuggestedVideoRow(
                                        suggestion: suggestion,
                                        isFollowingChannel: isFollowingChannel(suggestion.channelTitle),
                                        isImporting: false,
                                        isAlreadyImported: true,
                                        importStateText: importStatusText(for: suggestion.videoID),
                                        onImport: nil,
                                        onOpenImported: importedDocumentByVideoID[suggestion.videoID] == nil
                                            ? nil
                                            : { openImportedSuggestion(suggestion.videoID) },
                                        onToggleFollow: { toggleFollowChannel(suggestion.channelTitle) }
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var librarySection: some View {
        SectionCard("My Library") {
            if libraryDocuments.isEmpty {
                Text("No \(selectedStudyLanguage.displayName.lowercased()) lessons yet. Import your first text or YouTube lesson above.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    Picker("Library Filter", selection: $libraryFilter) {
                        ForEach(LibraryFilter.allCases) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)

                    if filteredLibraryDocuments.isEmpty {
                        Text("No lessons in this filter.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(filteredLibraryDocuments, id: \.id) { document in
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
    }

    private func refreshSuggestions(force: Bool) async {
        guard force || !hasLoadedSuggestions else { return }
        isLoadingSuggestions = true
        let loaded = await YouTubeDiscoveryService.shared.loadSuggestions(
            existingVideoIDs: [],
            forceRefresh: force,
            language: selectedStudyLanguage
        )
        suggestions = SuggestionRanker.rank(loaded, context: rankingContext)
        lastDiscoveryRefreshAt = await SuggestionCacheStore.shared.lastRefreshDate(language: selectedStudyLanguage)
        nextDiscoveryRetryAt = await SuggestionCacheStore.shared.nextRetryDate(language: selectedStudyLanguage)
        hasLoadedSuggestions = true
        isLoadingSuggestions = false
    }

    private func runSmartPackImport() {
        guard !isImportingSmartPack else { return }
        isImportingSmartPack = true

        Task {
            let summary = await AutoImportCoordinator.shared.importSmartPack(modelContext: modelContext)
            smartPackStatusMessage = summary.statusMessage

            if let documentID = summary.firstImportedDocumentID,
               let document = fetchDocument(id: documentID) {
                readerDestination = ReaderDestination(id: document.id, document: document)
            }

            await refreshSuggestions(force: true)
            isImportingSmartPack = false
        }
    }

    private func runAutoTopUpIfNeeded() async {
        if let summary = await AutoImportCoordinator.shared.performAutoTopUpIfNeeded(
            modelContext: modelContext,
            trigger: .libraryEntry
        ) {
            smartPackStatusMessage = summary.statusMessage
            await refreshSuggestions(force: true)
        }
    }

    private func openImportedSuggestion(_ videoID: String) {
        guard let document = importedDocumentByVideoID[videoID] else { return }
        readerDestination = ReaderDestination(id: document.id, document: document)
    }

    private func importStatusText(for videoID: String) -> String {
        guard let document = importedDocumentByVideoID[videoID] else {
            return "Seen"
        }
        return document.isOpened ? "Opened" : "Unread"
    }

    private func importSuggestion(_ suggestion: YouTubeSuggestedVideo) {
        guard !importingVideoIDs.contains(suggestion.videoID) else { return }
        importingVideoIDs.insert(suggestion.videoID)

        Task {
            do {
                let imported = try await YouTubeImportService.shared.importVideo(
                    videoID: suggestion.videoID,
                    language: selectedStudyLanguage
                )
                persistImported(
                    content: imported,
                    category: suggestion.category,
                    mode: .manual,
                    autoBatchID: nil,
                    openImmediately: true
                )
            } catch {
                alertMessage = error.localizedDescription
            }
            importingVideoIDs.remove(suggestion.videoID)
        }
    }

    private func importYouTubeURL(_ urlText: String) async throws {
        let imported = try await YouTubeImportService.shared.importFromURL(
            urlText,
            language: selectedStudyLanguage
        )
        persistImported(
            content: imported,
            category: "Custom",
            mode: .manual,
            autoBatchID: nil,
            openImmediately: true
        )
    }

    private func persistImported(
        content: ImportedYouTubeContent,
        category: String,
        mode: DocumentImportMode,
        autoBatchID: String?,
        openImmediately: Bool
    ) {
        let now = Date()
        let document = Document(
            title: content.title,
            body: content.transcript,
            languageCode: content.language,
            createdAt: now,
            updatedAt: now,
            sourceType: .youtube,
            sourceURL: content.watchURL.absoluteString,
            sourceVideoID: content.videoID,
            sourceChannel: content.channelTitle,
            sourceChannelID: content.channelID,
            sourceCategory: category,
            sourceDurationSeconds: content.durationSeconds,
            thumbnailURL: content.thumbnailURL?.absoluteString,
            importMode: mode,
            autoBatchID: autoBatchID
        )
        document.subtitleCues = content.subtitleCues

        modelContext.insert(document)
        markVideoAsHistoricallyImported(content.videoID, language: content.language)
        updateFollowedChannelsFromImport(channelTitle: content.channelTitle)
        suggestions = SuggestionRanker.rank(suggestions, context: rankingContext)

        if openImmediately {
            readerDestination = ReaderDestination(id: document.id, document: document)
        }
    }

    private func fetchDocument(id: UUID) -> Document? {
        let descriptor = FetchDescriptor<Document>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func handleTextFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            alertMessage = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let imported = try loadTextDocument(from: url)
                guard !imported.body.isEmpty else {
                    alertMessage = "Selected file is empty."
                    return
                }
                let now = Date()
                let document = Document(
                    title: imported.title,
                    body: imported.body,
                    languageCode: selectedStudyLanguage,
                    createdAt: now,
                    updatedAt: now,
                    sourceType: .text,
                    sourceURL: url.absoluteString
                )
                modelContext.insert(document)
                readerDestination = ReaderDestination(id: document.id, document: document)
            } catch {
                alertMessage = "Could not import text file."
            }
        }
    }

    private func loadTextDocument(from url: URL) throws -> (title: String, body: String) {
        let access = url.startAccessingSecurityScopedResource()
        defer {
            if access {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let text = try String(contentsOf: url, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let title = url.deletingPathExtension().lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (title: title.isEmpty ? "Imported Text" : title, body: text)
    }

    private func isFollowingChannel(_ channelTitle: String) -> Bool {
        let channelKey = SuggestionRanker.normalizeChannel(channelTitle)
        return rankingContext.followedChannels.contains(channelKey)
    }

    private func toggleFollowChannel(_ channelTitle: String) {
        var channels = rankingContext.followedChannels
        let key = SuggestionRanker.normalizeChannel(channelTitle)
        guard !key.isEmpty else { return }

        if channels.contains(key) {
            channels.remove(key)
        } else {
            channels.insert(key)
        }

        followedChannelsRaw = channels.sorted().joined(separator: "|")
        suggestions = SuggestionRanker.rank(suggestions, context: rankingContext)
    }

    private func updateFollowedChannelsFromImport(channelTitle: String) {
        let channelKey = SuggestionRanker.normalizeChannel(channelTitle)
        guard !channelKey.isEmpty else { return }

        var channels = rankingContext.followedChannels
        channels.insert(channelKey)
        followedChannelsRaw = channels.sorted().joined(separator: "|")
    }

    private func markVideoAsHistoricallyImported(_ videoID: String, language: SupportedLanguage) {
        guard YouTubeVideoIDParser.isValidVideoID(videoID) else { return }

        let defaults = UserDefaults.standard
        var history = Set(
            defaults.stringArray(forKey: AutoImportSettings.historicalImportedVideoIDsKey(for: language)) ?? []
        )
        history.insert(videoID)

        if history.count > AutoImportSettings.maxHistoricalVideoIDs {
            let sorted = Array(history).sorted()
            history = Set(sorted.suffix(AutoImportSettings.maxHistoricalVideoIDs))
        }

        defaults.set(Array(history), forKey: AutoImportSettings.historicalImportedVideoIDsKey(for: language))
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

                StudyLanguageBadge(language: document.languageCode)

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

private struct LibraryCountPill: View {
    let label: String
    let value: Int

    var body: some View {
        Text("\(label): \(value)")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.1), in: Capsule())
    }
}

private struct LibraryHeroMetric: View {
    let label: String
    let value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(value)")
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct SuggestedVideoRow: View {
    let suggestion: YouTubeSuggestedVideo
    let isFollowingChannel: Bool
    let isImporting: Bool
    let isAlreadyImported: Bool
    let importStateText: String?
    let onImport: (() -> Void)?
    let onOpenImported: (() -> Void)?
    let onToggleFollow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
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
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 128, height: 72)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(suggestion.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)

                    Text(suggestion.channelTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(suggestion.category.uppercased())
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.1), in: Capsule())

                        Text(formattedDuration(seconds: suggestion.durationSeconds))
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Theme.accent.opacity(0.16), in: Capsule())

                        Text("Subtitles")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Theme.accentSecondary.opacity(0.15), in: Capsule())

                        if isAlreadyImported {
                            Text(importStateText ?? "Imported")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.1), in: Capsule())
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 8) {
                Button {
                    onToggleFollow()
                } label: {
                    Label(
                        isFollowingChannel ? "Following" : "Follow",
                        systemImage: isFollowingChannel ? "checkmark.circle.fill" : "plus.circle"
                    )
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(
                        (isFollowingChannel ? Theme.accentSecondary.opacity(0.24) : Color.white.opacity(0.08)),
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain)

                Spacer(minLength: 8)

                if isAlreadyImported {
                    if let onOpenImported {
                        Button {
                            onOpenImported()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "book")
                                Text("Open")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .foregroundStyle(.primary)
                            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("Seen in past pulls")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Button {
                        onImport?()
                    } label: {
                        HStack(spacing: 6) {
                            if isImporting {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(isImporting ? "Importing..." : "Import")
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .foregroundStyle(.white)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isImporting)
                }
            }
        }
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

                    StudyLanguageBadge(language: document.languageCode)

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

    let language: SupportedLanguage
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
                                Text("This import will be saved as \(language.displayName).")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

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

    let language: SupportedLanguage
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
                                Text("Paste a YouTube URL. Import requires \(language.displayName) subtitles and an extractable transcript.")
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
