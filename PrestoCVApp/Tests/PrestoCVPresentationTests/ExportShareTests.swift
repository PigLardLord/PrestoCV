import Foundation
import Testing
@testable import PrestoCVPresentation

/// The end of the system's share sheet, as the sheet confirms it.
@MainActor
@Suite("Export sheet share")
struct ExportShareTests {

    /// A sheet that has made its PDF.
    private func exported(in world: SheetWorld) async -> ExportSheetViewModel {
        let sheet = world.sheet()
        sheet.start()
        await world.passThePause(thenExports: 1)
        await waitUntil("the PDF") { sheet.document != nil }
        return sheet
    }

    @Test("A PDF saved or sent is confirmed as such", arguments: [(ShareResult.saved, ShareOutcome.saved), (.sent, .sent)])
    func savedAndSentAreConfirmed(result: ShareResult, outcome: ShareOutcome) async throws {
        let world = SheetWorld()
        let sheet = await exported(in: world)
        let pdf = try #require(sheet.documentID)

        sheet.shareEnded(result, of: pdf)

        #expect(sheet.shareOutcome == outcome)
    }

    @Test("A cancelled share changes nothing: no outcome, the same PDF and status")
    func cancelledShareChangesNothing() async throws {
        let world = SheetWorld()
        let sheet = await exported(in: world)
        let pdf = try #require(sheet.documentID)

        sheet.shareEnded(.cancelled, of: pdf)

        #expect(sheet.shareOutcome == nil)
        #expect(sheet.documentID == pdf)
        #expect(sheet.status == .done(pages: 1))
    }

    @Test("A share that went through to print, copy or another app confirms nothing and marks no failure")
    func otherShareConfirmsNothing() async throws {
        let world = SheetWorld()
        let sheet = await exported(in: world)

        sheet.shareEnded(.other, of: try #require(sheet.documentID))

        #expect(sheet.shareOutcome == nil)
        #expect(sheet.shareFailure == nil)
    }

    @Test("A share that failed is marked as failed, with no outcome")
    func failedShareIsMarked() async throws {
        let world = SheetWorld()
        let sheet = await exported(in: world)

        sheet.shareEnded(.failed, of: try #require(sheet.documentID))

        #expect(sheet.shareFailure != nil)
        #expect(sheet.shareOutcome == nil)
    }

    @Test("Each failure is a new value, so that the second one in a row is told too")
    func eachFailureIsNew() async throws {
        let world = SheetWorld()
        let sheet = await exported(in: world)
        let pdf = try #require(sheet.documentID)

        sheet.shareEnded(.failed, of: pdf)
        let first = sheet.shareFailure
        sheet.shareEnded(.failed, of: pdf)

        #expect(first != nil)
        #expect(sheet.shareFailure != nil)
        #expect(sheet.shareFailure != first)
    }

    @Test("A share that went through after a failed one clears the failure")
    func successClearsTheFailure() async throws {
        let world = SheetWorld()
        let sheet = await exported(in: world)
        let pdf = try #require(sheet.documentID)
        sheet.shareEnded(.failed, of: pdf)

        sheet.shareEnded(.saved, of: pdf)

        #expect(sheet.shareFailure == nil)
        #expect(sheet.shareOutcome == .saved)
    }

    @Test("A failed share of an earlier export marks nothing for the PDF made after it")
    func failureOfAnEarlierExportIsIgnored() async throws {
        let world = SheetWorld()
        let sheet = await exported(in: world)
        let first = try #require(sheet.documentID)

        sheet.refresh()
        await world.passThePause(thenExports: 2)
        await waitUntil("the second PDF") { sheet.document != nil }
        sheet.shareEnded(.failed, of: first)

        #expect(sheet.shareFailure == nil)
    }

    @Test("The next export clears the failure of the last share")
    func nextExportClearsTheFailure() async throws {
        let world = SheetWorld()
        let sheet = await exported(in: world)
        sheet.shareEnded(.failed, of: try #require(sheet.documentID))

        sheet.start()

        #expect(sheet.shareFailure == nil, "a failure is about the PDF it was shared from")
    }

    @Test("The next export clears the outcome of the last share")
    func nextExportResetsTheOutcome() async throws {
        let world = SheetWorld()
        let sheet = await exported(in: world)
        sheet.shareEnded(.saved, of: try #require(sheet.documentID))

        sheet.start()

        #expect(sheet.shareOutcome == nil, "an outcome is about the PDF it was shared from")
    }

    @Test("A share of an earlier export is not confirmed for a later export with the same bytes")
    func shareOfAnEarlierExportWithTheSameBytes() async throws {
        let world = SheetWorld()
        let sheet = await exported(in: world)
        let first = try #require(sheet.documentID)
        let firstDocument = try #require(sheet.document)

        sheet.refresh()
        await world.passThePause(thenExports: 2)
        await waitUntil("the second PDF") { sheet.document != nil }
        sheet.shareEnded(.saved, of: first)

        #expect(sheet.document == firstDocument, "the two PDFs hold the same bytes and pages")
        #expect(sheet.documentID != first)
        #expect(sheet.shareOutcome == nil)
        sheet.shareEnded(.saved, of: try #require(sheet.documentID))
        #expect(sheet.shareOutcome == .saved)
    }
}
