import XCTest
@testable import LanguageReader

final class SubtitleCueTimelineTests: XCTestCase {
    /// Handles unavailable subtitles and playback positions before the first cue.
    func testActiveIndexHandlesEmptyTimelineAndNegativePlayback() {
        XCTAssertNil(SubtitleCueTimeline.activeIndex(for: [], at: -1))
        XCTAssertNil(SubtitleCueTimeline.activeIndex(for: [], at: 10))
        let cues = [TimedSubtitleCue(startTime: 0, duration: 1, sourceText: "ಒಂದು")]
        XCTAssertEqual(SubtitleCueTimeline.activeIndex(for: cues, at: -1), 0)
    }

    /// Rejects missing caches and extra translations even when shared timing matches.
    func testCompatibleTranslatedCuesRejectsMissingAndOversizedCaches() {
        let sourceCues = [TimedSubtitleCue(startTime: 0, duration: 1, sourceText: "ಒಂದು")]
        let cachedCues = [
            TranslatedSubtitleCue(startTime: 0, duration: 1, translatedText: "One"),
            TranslatedSubtitleCue(startTime: 2, duration: 1, translatedText: "Two")
        ]
        XCTAssertNil(SubtitleCueTimeline.compatibleTranslatedCues(from: nil, with: sourceCues))
        XCTAssertNil(SubtitleCueTimeline.compatibleTranslatedCues(from: [], with: sourceCues))
        XCTAssertNil(SubtitleCueTimeline.compatibleTranslatedCues(from: cachedCues, with: sourceCues))
    }

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

    /// Switches to the newer cue even while the previous cue still overlaps it.
    func testActiveIndexSwitchesAtStartOfOverlappingCue() {
        let cues = [
            TimedSubtitleCue(startTime: 0, duration: 5, sourceText: "ಒಂದು"),
            TimedSubtitleCue(startTime: 2, duration: 1, sourceText: "ಎರಡು")
        ]

        XCTAssertEqual(SubtitleCueTimeline.activeIndex(for: cues, at: 1.99), 0)
        XCTAssertEqual(SubtitleCueTimeline.activeIndex(for: cues, at: 2), 1)
        XCTAssertEqual(SubtitleCueTimeline.activeIndex(for: cues, at: 2.5), 1)
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

    /// Checks duration drift independently of start times, including later cached cues.
    func testCompatibleTranslatedCuesValidatesDurationDriftInBothDirections() {
        let sourceCues = [
            TimedSubtitleCue(startTime: 0, duration: 1.0, sourceText: "ಒಂದು"),
            TimedSubtitleCue(startTime: 2.0, duration: 1.0, sourceText: "ಎರಡು")
        ]

        for (duration, shouldReuse) in [(0.96, true), (1.04, true), (0.94, false), (1.06, false)] {
            let cachedCues = [
                TranslatedSubtitleCue(startTime: 0, duration: 1.0, translatedText: "One"),
                TranslatedSubtitleCue(startTime: 2.0, duration: duration, translatedText: "Two")
            ]
            let result = SubtitleCueTimeline.compatibleTranslatedCues(from: cachedCues, with: sourceCues)

            if shouldReuse {
                XCTAssertEqual(result, cachedCues, "Expected reuse for duration \(duration)")
            } else {
                XCTAssertNil(result, "Expected invalidation for duration \(duration)")
            }
        }
    }

    /// Checks start drift independently of durations, including later cached cues.
    func testCompatibleTranslatedCuesValidatesStartDriftInBothDirections() {
        let sourceCues = [
            TimedSubtitleCue(startTime: 0, duration: 1.0, sourceText: "ಒಂದು"),
            TimedSubtitleCue(startTime: 2.0, duration: 1.0, sourceText: "ಎರಡು")
        ]

        for (start, shouldReuse) in [(1.96, true), (2.04, true), (1.94, false), (2.06, false)] {
            let cachedCues = [
                TranslatedSubtitleCue(startTime: 0, duration: 1.0, translatedText: "One"),
                TranslatedSubtitleCue(startTime: start, duration: 1.0, translatedText: "Two")
            ]
            let result = SubtitleCueTimeline.compatibleTranslatedCues(from: cachedCues, with: sourceCues)

            if shouldReuse {
                XCTAssertEqual(result, cachedCues, "Expected reuse for start \(start)")
            } else {
                XCTAssertNil(result, "Expected invalidation for start \(start)")
            }
        }
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
