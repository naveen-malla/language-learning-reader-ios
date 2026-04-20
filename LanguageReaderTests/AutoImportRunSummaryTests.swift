import XCTest
@testable import LanguageReader

final class AutoImportRunSummaryTests: XCTestCase {
    func testComputedFlagsRespectTargetAndMinimumSuccessThreshold() {
        let incomplete = makeSummary(mode: .smartPack, targetCount: 5, importedCount: 3)
        XCTAssertTrue(incomplete.isPartial)
        XCTAssertFalse(incomplete.isSuccessful)

        let completedSmallTarget = makeSummary(mode: .smartPack, targetCount: 3, importedCount: 3)
        XCTAssertFalse(completedSmallTarget.isPartial)
        XCTAssertTrue(completedSmallTarget.isSuccessful)

        let completedLargeTarget = makeSummary(mode: .smartPack, targetCount: 6, importedCount: 4)
        XCTAssertTrue(completedLargeTarget.isPartial)
        XCTAssertTrue(completedLargeTarget.isSuccessful)
    }

    func testSmartPackStatusMessagesCoverNoCandidateRepeatAndPartialBranches() {
        let noCandidates = makeSummary(
            mode: .smartPack,
            targetCount: 3,
            attemptedCount: 0,
            importedCount: 0
        )
        XCTAssertEqual(
            noCandidates.statusMessage,
            "Feed refreshed. No importable lessons found in this cycle."
        )

        let nonePassedValidation = makeSummary(
            mode: .smartPack,
            targetCount: 3,
            attemptedCount: 5,
            importedCount: 0
        )
        XCTAssertEqual(
            nonePassedValidation.statusMessage,
            "Checked 5 candidates, but none passed subtitle and duration checks."
        )

        let onlyRepeats = makeSummary(
            mode: .smartPack,
            targetCount: 3,
            attemptedCount: 2,
            importedCount: 2,
            repeatedImportCount: 2
        )
        XCTAssertEqual(
            onlyRepeats.statusMessage,
            "Added 2 lessons from your existing feed while waiting for fresh uploads."
        )

        let mixedWithRepeats = makeSummary(
            mode: .smartPack,
            targetCount: 4,
            attemptedCount: 3,
            importedCount: 3,
            repeatedImportCount: 1
        )
        XCTAssertEqual(
            mixedWithRepeats.statusMessage,
            "Added 3 lessons (1 from existing feed)."
        )

        let partialFreshImport = makeSummary(
            mode: .smartPack,
            targetCount: 5,
            attemptedCount: 2,
            importedCount: 2,
            repeatedImportCount: 0
        )
        XCTAssertEqual(
            partialFreshImport.statusMessage,
            "Added 2 lessons (3 still missing)."
        )

        let successfulFreshImport = makeSummary(
            mode: .smartPack,
            targetCount: 6,
            attemptedCount: 4,
            importedCount: 4,
            repeatedImportCount: 0
        )
        XCTAssertEqual(
            successfulFreshImport.statusMessage,
            "Added 4 fresh lessons to your queue."
        )
    }

    func testAutoTopUpAndManualStatusMessagesCoverCoreBranches() {
        let autoNoCandidates = makeSummary(
            mode: .autoTopUp,
            trigger: .backgroundRefresh,
            targetCount: 2,
            attemptedCount: 0,
            importedCount: 0
        )
        XCTAssertEqual(
            autoNoCandidates.statusMessage,
            "Auto top-up left queue unchanged: no feed candidates available."
        )

        let autoValidationFailure = makeSummary(
            mode: .autoTopUp,
            trigger: .backgroundRefresh,
            targetCount: 2,
            attemptedCount: 4,
            importedCount: 0
        )
        XCTAssertEqual(
            autoValidationFailure.statusMessage,
            "Auto top-up checked 4 items, but none passed subtitle and duration checks."
        )

        let autoWithRepeats = makeSummary(
            mode: .autoTopUp,
            trigger: .backgroundRefresh,
            targetCount: 2,
            attemptedCount: 2,
            importedCount: 2,
            repeatedImportCount: 1
        )
        XCTAssertEqual(
            autoWithRepeats.statusMessage,
            "Auto top-up added 2 lessons (1 from existing feed)."
        )

        let autoFresh = makeSummary(
            mode: .autoTopUp,
            trigger: .backgroundRefresh,
            targetCount: 2,
            attemptedCount: 2,
            importedCount: 2,
            repeatedImportCount: 0
        )
        XCTAssertEqual(autoFresh.statusMessage, "Auto top-up added 2 fresh lessons.")

        let manual = makeSummary(
            mode: .manual,
            trigger: .libraryEntry,
            targetCount: 1,
            attemptedCount: 1,
            importedCount: 1
        )
        XCTAssertEqual(manual.statusMessage, "Imported 1 lessons.")
    }
}

private extension AutoImportRunSummaryTests {
    func makeSummary(
        mode: DocumentImportMode,
        trigger: AutoImportTrigger = .libraryEntry,
        targetCount: Int,
        attemptedCount: Int = 0,
        importedCount: Int,
        repeatedImportCount: Int = 0,
        skippedDuplicates: Int = 0,
        batchID: String? = nil
    ) -> AutoImportRunSummary {
        AutoImportRunSummary(
            mode: mode,
            trigger: trigger,
            targetCount: targetCount,
            attemptedCount: attemptedCount,
            importedCount: importedCount,
            repeatedImportCount: repeatedImportCount,
            skippedDuplicates: skippedDuplicates,
            batchID: batchID,
            firstImportedDocumentID: nil
        )
    }
}
