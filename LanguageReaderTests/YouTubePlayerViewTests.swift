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
