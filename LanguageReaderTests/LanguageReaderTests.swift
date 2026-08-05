import XCTest
@testable import LanguageReader

final class LanguageReaderTests: XCTestCase {
    func testCanonicalLanguageCodeNormalizesRegionalTags() {
        XCTAssertEqual(LanguageTextHeuristics.canonicalLanguageCode(" DE_de "), "de")
        XCTAssertEqual(LanguageTextHeuristics.canonicalLanguageCode("kn-IN"), "kn")
    }

    func testReadableEnglishRejectsSourceScriptAndGermanEchoes() {
        XCTAssertFalse(LanguageTextHeuristics.isReadableEnglishTranslation(
            "house ಮನೆ", source: "ಮನೆ", sourceLanguage: "kn-IN"
        ))
        XCTAssertFalse(LanguageTextHeuristics.isReadableEnglishTranslation(
            "das ist gut", source: "das Haus", sourceLanguage: "de-DE"
        ))
    }

    func testReadableEnglishAcceptsTranslatedOutput() {
        XCTAssertTrue(LanguageTextHeuristics.isReadableEnglishTranslation(
            "This is a house", source: "ಮನೆ", sourceLanguage: "kn"
        ))
        XCTAssertTrue(LanguageTextHeuristics.isReadableEnglishTranslation(
            "die ist the house is good", source: "das Haus", sourceLanguage: "de"
        ))
    }

    func testDocumentInitialization() {
        let date = Date()
        let document = Document(title: "Title", body: "Body", createdAt: date, updatedAt: date)

        XCTAssertEqual(document.title, "Title")
        XCTAssertEqual(document.body, "Body")
        XCTAssertEqual(document.languageCode, StudyLanguageSettingsStore().studyLanguage)
        XCTAssertEqual(document.createdAt, date)
        XCTAssertEqual(document.updatedAt, date)
    }

    func testVocabEntryDefaults() {
        let entry = VocabEntry(word: "Hello", normalizedKey: "hello", meaning: "hi")

        XCTAssertEqual(entry.word, "Hello")
        XCTAssertEqual(entry.normalizedKey, "hello")
        XCTAssertEqual(entry.languageCode, StudyLanguageSettingsStore().studyLanguage)
        XCTAssertEqual(
            entry.scopedKey,
            VocabEntry.makeScopedKey(
                languageCode: StudyLanguageSettingsStore().studyLanguage.rawValue,
                normalizedKey: "hello"
            )
        )
        XCTAssertEqual(entry.meaning, "hi")
        XCTAssertEqual(entry.status, .level1)
        XCTAssertEqual(entry.encounterCount, 1)
        XCTAssertNil(entry.dueAt)
        XCTAssertEqual(entry.srsIntervalDays ?? -1, 0)
        XCTAssertEqual(entry.srsEaseFactor ?? -1, 2.5)
        XCTAssertEqual(entry.srsRepetition ?? -1, 0)
        XCTAssertEqual(entry.srsLapseCount ?? -1, 0)
        XCTAssertEqual(entry.isSuspended, false)
        XCTAssertNil(entry.srsStability)
        XCTAssertNil(entry.srsDifficulty)
        XCTAssertNil(entry.srsAlgorithm)
    }

    func testVocabEntryCustomInitialization() {
        let createdAt = Date(timeIntervalSince1970: 100)
        let lastSeenAt = Date(timeIntervalSince1970: 200)
        let entry = VocabEntry(
            word: "ಮನೆ",
            normalizedKey: "ಮನೆ",
            meaning: "house",
            status: .level2,
            createdAt: createdAt,
            lastSeenAt: lastSeenAt,
            encounterCount: 7,
            dueAt: Date(timeIntervalSince1970: 300),
            srsIntervalDays: 6,
            srsEaseFactor: 2.2,
            srsRepetition: 3,
            srsLapseCount: 1,
            isSuspended: true,
            srsStability: 4.5,
            srsDifficulty: 6.2,
            srsAlgorithm: "fsrs"
        )

        XCTAssertEqual(entry.status, .level2)
        XCTAssertEqual(entry.languageCode, StudyLanguageSettingsStore().studyLanguage)
        XCTAssertEqual(entry.createdAt, createdAt)
        XCTAssertEqual(entry.lastSeenAt, lastSeenAt)
        XCTAssertEqual(entry.encounterCount, 7)
        XCTAssertEqual(entry.dueAt, Date(timeIntervalSince1970: 300))
        XCTAssertEqual(entry.srsIntervalDays ?? -1, 6)
        XCTAssertEqual(entry.srsEaseFactor ?? -1, 2.2)
        XCTAssertEqual(entry.srsRepetition ?? -1, 3)
        XCTAssertEqual(entry.srsLapseCount ?? -1, 1)
        XCTAssertEqual(entry.isSuspended, true)
        XCTAssertEqual(entry.srsStability, 4.5)
        XCTAssertEqual(entry.srsDifficulty, 6.2)
        XCTAssertEqual(entry.srsAlgorithm, "fsrs")
    }

    func testYouTubeSeekGateQueuesLatestSeekUntilReady() {
        var gate = YouTubePlayerSeekGate()

        XCTAssertNil(gate.queueOrEmitSeek(2.0))
        XCTAssertNil(gate.queueOrEmitSeek(7.25))

        XCTAssertEqual(gate.markReadyAndFlushPendingSeek(), 7.25)
        XCTAssertNil(gate.markReadyAndFlushPendingSeek())
    }

    func testYouTubeSeekGateUsesFlushedPendingSeekAsDeduplicationBaseline() {
        var gate = YouTubePlayerSeekGate()

        XCTAssertNil(gate.queueOrEmitSeek(12.0))
        XCTAssertEqual(gate.markReadyAndFlushPendingSeek(), 12.0)
        XCTAssertNil(gate.queueOrEmitSeek(12.1))
        XCTAssertEqual(gate.queueOrEmitSeek(12.3), 12.3)
    }

    func testYouTubeSeekGateDeduplicatesNearDuplicateSeeks() {
        var gate = YouTubePlayerSeekGate()
        XCTAssertNil(gate.markReadyAndFlushPendingSeek())

        XCTAssertEqual(gate.queueOrEmitSeek(10.0), 10.0)
        XCTAssertNil(gate.queueOrEmitSeek(10.1))
        XCTAssertEqual(gate.queueOrEmitSeek(10.3), 10.3)
    }

    func testYouTubeSeekGateClampsAndResetsForNewVideo() {
        var gate = YouTubePlayerSeekGate()

        XCTAssertNil(gate.queueOrEmitSeek(-3.0))
        XCTAssertEqual(gate.markReadyAndFlushPendingSeek(), 0.0)
        XCTAssertNil(gate.queueOrEmitSeek(0.05))

        gate.resetForNewVideo()
        XCTAssertNil(gate.queueOrEmitSeek(0.05))
        XCTAssertEqual(gate.markReadyAndFlushPendingSeek(), 0.05)
    }
}
