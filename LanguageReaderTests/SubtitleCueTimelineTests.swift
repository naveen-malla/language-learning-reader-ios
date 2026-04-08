import XCTest
@testable import LanguageReader

final class SubtitleCueTimelineTests: XCTestCase {
    func testActiveIndexTracksCueBoundariesAndGaps() {
        let cues = [
            TimedSubtitleCue(startTime: 0.5, duration: 1.0, sourceText: "ಒಂದು"),
            TimedSubtitleCue(startTime: 2.0, duration: 1.0, sourceText: "ಎರಡು"),
            TimedSubtitleCue(startTime: 3.5, duration: 1.2, sourceText: "ಮೂರು")
        ]

        XCTAssertEqual(SubtitleCueTimeline.activeIndex(for: cues, at: 0), 0)
        XCTAssertEqual(SubtitleCueTimeline.activeIndex(for: cues, at: 1.0), 0)
        XCTAssertEqual(SubtitleCueTimeline.activeIndex(for: cues, at: 1.8), 0)
        XCTAssertEqual(SubtitleCueTimeline.activeIndex(for: cues, at: 2.0), 1)
        XCTAssertEqual(SubtitleCueTimeline.activeIndex(for: cues, at: 2.4), 1)
        XCTAssertEqual(SubtitleCueTimeline.activeIndex(for: cues, at: 4.9), 2)
        XCTAssertEqual(SubtitleCueTimeline.activeIndex(for: cues, at: 8.0), 2)
    }

    func testActiveIndexSnapsForwardAtCueBoundary() {
        let cues = [
            TimedSubtitleCue(startTime: 0.0, duration: 1.0, sourceText: "ಒಂದು"),
            TimedSubtitleCue(startTime: 1.0, duration: 1.0, sourceText: "ಎರಡು")
        ]

        XCTAssertEqual(SubtitleCueTimeline.activeIndex(for: cues, at: 0.99), 0)
        XCTAssertEqual(SubtitleCueTimeline.activeIndex(for: cues, at: 1.0), 1)
        XCTAssertEqual(SubtitleCueTimeline.activeIndex(for: cues, at: 1.01), 1)
    }

    func testActiveIndexKeepsPreviousCueAcrossShortGaps() {
        let cues = [
            TimedSubtitleCue(startTime: 0.0, duration: 0.7, sourceText: "ಒಂದು"),
            TimedSubtitleCue(startTime: 0.9, duration: 0.8, sourceText: "ಎರಡು")
        ]

        XCTAssertEqual(SubtitleCueTimeline.activeIndex(for: cues, at: 0.7), 0)
        XCTAssertEqual(SubtitleCueTimeline.activeIndex(for: cues, at: 0.8), 0)
        XCTAssertEqual(SubtitleCueTimeline.activeIndex(for: cues, at: 0.9), 1)
    }

    func testCompatibleTranslatedCuesRequiresMatchingTiming() {
        let sourceCues = [
            TimedSubtitleCue(startTime: 0, duration: 1.0, sourceText: "ಒಂದು"),
            TimedSubtitleCue(startTime: 1.4, duration: 1.1, sourceText: "ಎರಡು")
        ]
        let cachedCues = [
            TranslatedSubtitleCue(startTime: 0, duration: 1.0, translatedText: "One"),
            TranslatedSubtitleCue(startTime: 1.4, duration: 1.1, translatedText: "Two")
        ]
        let mismatchedCues = [
            TranslatedSubtitleCue(startTime: 0, duration: 1.0, translatedText: "One"),
            TranslatedSubtitleCue(startTime: 1.8, duration: 1.1, translatedText: "Two")
        ]

        XCTAssertEqual(
            SubtitleCueTimeline.compatibleTranslatedCues(from: cachedCues, with: sourceCues),
            cachedCues
        )
        XCTAssertNil(
            SubtitleCueTimeline.compatibleTranslatedCues(from: mismatchedCues, with: sourceCues)
        )
    }

    func testCompatibleTranslatedCuesAcceptsToleranceBoundary() {
        let sourceCues = [
            TimedSubtitleCue(startTime: 0, duration: 1.0, sourceText: "ಒಂದು"),
            TimedSubtitleCue(startTime: 2.0, duration: 1.0, sourceText: "ಎರಡು")
        ]
        let cachedCues = [
            TranslatedSubtitleCue(startTime: 0.05, duration: 1.05, translatedText: "One"),
            TranslatedSubtitleCue(startTime: 2.05, duration: 1.05, translatedText: "Two")
        ]

        XCTAssertEqual(
            SubtitleCueTimeline.compatibleTranslatedCues(from: cachedCues, with: sourceCues),
            cachedCues
        )
    }

    func testCompatibleTranslatedCuesRejectsCountMismatch() {
        let sourceCues = [
            TimedSubtitleCue(startTime: 0, duration: 1.0, sourceText: "ಒಂದು"),
            TimedSubtitleCue(startTime: 2.0, duration: 1.0, sourceText: "ಎರಡು")
        ]
        let cachedCues = [
            TranslatedSubtitleCue(startTime: 0, duration: 1.0, translatedText: "One")
        ]

        XCTAssertNil(
            SubtitleCueTimeline.compatibleTranslatedCues(from: cachedCues, with: sourceCues)
        )
    }
}
