import XCTest
@testable import LanguageReader

final class YouTubePlayerViewTests: XCTestCase {
    func testSeekGateQueuesLatestSeekUntilReady() {
        var gate = YouTubePlayerSeekGate()

        XCTAssertNil(gate.queueOrEmitSeek(2.0))
        XCTAssertNil(gate.queueOrEmitSeek(7.25))

        XCTAssertEqual(gate.markReadyAndFlushPendingSeek(), 7.25)
        XCTAssertNil(gate.markReadyAndFlushPendingSeek())
    }

    func testSeekGateUsesFlushedPendingSeekAsDeduplicationBaseline() {
        var gate = YouTubePlayerSeekGate()

        XCTAssertNil(gate.queueOrEmitSeek(12.0))
        XCTAssertEqual(gate.markReadyAndFlushPendingSeek(), 12.0)
        XCTAssertNil(gate.queueOrEmitSeek(12.1))
        XCTAssertEqual(gate.queueOrEmitSeek(12.3), 12.3)
    }

    func testSeekGateDeduplicatesNearDuplicateSeeksWhenReady() {
        var gate = YouTubePlayerSeekGate()
        XCTAssertNil(gate.markReadyAndFlushPendingSeek())

        XCTAssertEqual(gate.queueOrEmitSeek(10.0), 10.0)
        XCTAssertNil(gate.queueOrEmitSeek(10.1))
        XCTAssertEqual(gate.queueOrEmitSeek(10.3), 10.3)
    }

    /// Verifies backward seeks use the same distance threshold as forward seeks.
    func testSeekGateAllowsBackwardSeeksBeyondThreshold() {
        var gate = YouTubePlayerSeekGate()
        XCTAssertNil(gate.markReadyAndFlushPendingSeek())
        XCTAssertEqual(gate.queueOrEmitSeek(10.0), 10.0)
        XCTAssertNil(gate.queueOrEmitSeek(9.9))
        XCTAssertEqual(gate.queueOrEmitSeek(9.5), 9.5)
    }

    /// Verifies ignored requests do not move the last emitted seek baseline.
    func testSeekGatePreservesBaselineAfterSuppressedSeek() {
        var gate = YouTubePlayerSeekGate()
        XCTAssertNil(gate.markReadyAndFlushPendingSeek())
        XCTAssertEqual(gate.queueOrEmitSeek(10.0), 10.0)
        XCTAssertNil(gate.queueOrEmitSeek(10.15))
        XCTAssertEqual(gate.queueOrEmitSeek(10.25), 10.25)
    }

    /// Verifies a seek exactly at the deduplication threshold is emitted.
    func testSeekGateAllowsSeekAtThreshold() {
        var gate = YouTubePlayerSeekGate()
        XCTAssertNil(gate.markReadyAndFlushPendingSeek())
        XCTAssertEqual(gate.queueOrEmitSeek(0.0), 0.0)
        XCTAssertEqual(gate.queueOrEmitSeek(0.2), 0.2)
    }

    func testSeekGateClampsAndResetsForNewVideo() {
        var gate = YouTubePlayerSeekGate()

        XCTAssertNil(gate.queueOrEmitSeek(-3.0))
        XCTAssertEqual(gate.markReadyAndFlushPendingSeek(), 0.0)
        XCTAssertNil(gate.queueOrEmitSeek(0.05))

        gate.resetForNewVideo()
        XCTAssertNil(gate.queueOrEmitSeek(0.05))
        XCTAssertEqual(gate.markReadyAndFlushPendingSeek(), 0.05)
    }

    func testSeekGateResetDropsPendingSeekBeforeReadyFlush() {
        var gate = YouTubePlayerSeekGate()

        XCTAssertNil(gate.queueOrEmitSeek(42.0))
        gate.resetForNewVideo()

        XCTAssertNil(gate.markReadyAndFlushPendingSeek())
        XCTAssertTrue(gate.isPlayerReady)
        XCTAssertNil(gate.pendingSeekTime)
        XCTAssertNil(gate.lastSeekTime)
    }

    func testSeekGateClampsNegativeSeekWhenAlreadyReady() {
        var gate = YouTubePlayerSeekGate()
        XCTAssertNil(gate.markReadyAndFlushPendingSeek())

        XCTAssertEqual(gate.queueOrEmitSeek(-7.0), 0.0)
        XCTAssertNil(gate.queueOrEmitSeek(0.1))
        XCTAssertEqual(gate.queueOrEmitSeek(0.25), 0.25)
    }
}
