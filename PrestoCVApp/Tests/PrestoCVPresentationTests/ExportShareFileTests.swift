import Foundation
import Testing
@testable import PrestoCVPresentation

/// The file of a share: written under the PDF's name when the person shares, kept while the system's share sheet reads
/// it, and removed once, when that share ends or goes, whatever the sheet does meanwhile.
@MainActor
@Suite("Export sheet share file")
struct ExportShareFileTests {

    /// A sheet that has made its PDF.
    private func exported(in world: SheetWorld) async -> ExportSheetViewModel {
        let sheet = world.sheet()
        sheet.start()
        await world.passThePause(thenExports: 1)
        await waitUntil("the PDF") { sheet.document != nil }
        return sheet
    }

    /// A sheet that has made its PDF and opened a share of it.
    private func shared(in world: SheetWorld) async throws -> (ExportSheetViewModel, PDFShare) {
        let sheet = await exported(in: world)
        sheet.share()
        await waitUntil("the share") { sheet.openShare != nil }
        return (sheet, try #require(sheet.openShare))
    }

    // MARK: - The file

    @Test("The share's file holds the PDF under the PDF's name, and the share gives it to the share sheet")
    func theFileHoldsThePDFUnderItsName() async throws {
        let world = SheetWorld()
        let (sheet, share) = try await shared(in: world)
        let name = try #require(sheet.suggestedFileName)

        #expect(world.files.names == [name])
        #expect(world.files.pdfs == [ExportingFake.onePage.pdf])
        #expect(share.fileName == name)
        #expect(share.url == world.files.written.first?.url)
    }

    @Test("The file stays while the share sheet reads it")
    func fileStaysWhileAShareReadsIt() async throws {
        let world = SheetWorld()
        let (sheet, _) = try await shared(in: world)
        await settle()

        #expect(world.files.written.count == 1)
        #expect(world.files.removed.isEmpty)
        #expect(sheet.openShare != nil)
    }

    @Test("The file goes when the share ends, and the sheet lets the share go")
    func fileGoesWhenTheShareEnds() async throws {
        let world = SheetWorld()
        let (sheet, share) = try await shared(in: world)

        share.end(.sent)

        #expect(world.files.removed == world.files.written)
        #expect(world.files.left.isEmpty)
        #expect(sheet.openShare == nil)
        #expect(sheet.shareOutcome == .sent)
    }

    @Test("A share that ends twice removes its file once and keeps the first outcome")
    func endTwiceRemovesOnce() async throws {
        let world = SheetWorld()
        let (sheet, share) = try await shared(in: world)

        share.end(.sent)
        share.end(.cancelled)

        #expect(world.files.removed.count == 1)
        #expect(sheet.shareOutcome == .sent)
    }

    @Test("Two shares of one PDF write a file each, and each file goes at the end of its own share")
    func twoSharesOfOnePDF() async throws {
        let world = SheetWorld()
        let (sheet, first) = try await shared(in: world)
        first.end(.cancelled)

        sheet.share()
        await waitUntil("the second share") { sheet.openShare != nil }
        let second = try #require(sheet.openShare)

        #expect(world.files.written.count == 2)
        #expect(first.url != second.url)
        #expect(world.files.left == [world.files.written[1]])
        second.end(.saved)
        #expect(world.files.left.isEmpty)
    }

    // MARK: - The sheet lets go

    @Test("A share the sheet lets go while the share sheet reads it keeps its file until it ends")
    func fileLetGoDuringAShareGoesAtItsEnd() async throws {
        let world = SheetWorld()
        let (sheet, share) = try await shared(in: world)

        sheet.stop()

        #expect(sheet.openShare == nil)
        #expect(world.files.removed.isEmpty, "the share sheet still reads the file")
        share.end(.saved)
        #expect(world.files.left.isEmpty)
        #expect(sheet.shareOutcome == nil, "the PDF of the share is no longer the sheet's")
    }

    @Test("A share nothing holds any more removes its file: nothing is left after the sheet closes")
    func nothingLeftAfterTheSheetCloses() async throws {
        let world = SheetWorld()
        let sheet = await exported(in: world)
        sheet.share()
        await waitUntil("the share") { sheet.openShare != nil }

        sheet.stop()

        await waitUntil("the file to go") { world.files.left.isEmpty }
        #expect(world.files.removed.count == 1)
    }

    @Test("A share outlives its sheet: it does not keep the sheet, and its end still removes the file")
    func shareOutlivesTheSheet() async throws {
        let world = SheetWorld()
        var sheet: ExportSheetViewModel? = await exported(in: world)
        sheet?.share()
        await waitUntil("the share") { sheet?.openShare != nil }
        let share = try #require(sheet?.openShare)
        weak var gone = sheet

        sheet = nil

        #expect(gone == nil, "the share holds its sheet weakly")
        #expect(world.files.removed.isEmpty)
        share.end(.sent)
        #expect(world.files.left.isEmpty)
    }

    @Test("An earlier share that ends leaves the open share alone")
    func anEarlierShareLeavesTheOpenOneAlone() async throws {
        let world = SheetWorld()
        let (sheet, first) = try await shared(in: world)
        sheet.refresh()
        await world.passThePause(thenExports: 2)
        await waitUntil("the new PDF") { sheet.document != nil }
        sheet.share()
        await waitUntil("the second share") { sheet.openShare != nil && sheet.openShare !== first }
        let second = try #require(sheet.openShare)

        first.end(.saved)

        #expect(sheet.openShare === second)
        #expect(sheet.shareOutcome == nil, "the first share was of a PDF no longer on screen")
        #expect(world.files.left == [world.files.written[1]])
    }

    // MARK: - The write

    @Test("Without a PDF, before the export or while it runs, a share writes nothing")
    func noPDFAsksNothing() async {
        let world = SheetWorld()
        let sheet = world.sheet()

        sheet.share()
        sheet.start()
        sheet.share()
        await settle()

        #expect(world.files.asked == 0)
        #expect(sheet.openShare == nil)
    }

    @Test("A second tap while the file is being written writes nothing more")
    func doubleTapWritesOnce() async throws {
        let world = SheetWorld()
        let sheet = await exported(in: world)
        await world.files.gate.close()

        sheet.share()
        await waitUntil("the write held") { await world.files.gate.waiting == 1 }
        sheet.share()
        await settle()
        #expect(world.files.asked == 1)

        await world.files.gate.open()
        await waitUntil("the share") { sheet.openShare != nil }
        sheet.share()
        await settle()
        #expect(world.files.asked == 1, "a share is open")
    }

    @Test("A file whose write ends after the sheet closed is removed at once, and opens no share")
    func writeEndingAfterStopIsRemoved() async throws {
        let world = SheetWorld()
        let sheet = await exported(in: world)
        await world.files.gate.close()
        sheet.share()
        await waitUntil("the write held") { await world.files.gate.waiting == 1 }

        sheet.stop()
        await world.files.gate.open()

        await waitUntil("the file to go") { world.files.removed.count == 1 }
        #expect(world.files.left.isEmpty)
        #expect(sheet.openShare == nil)
    }

    @Test("A file whose write ends after a refresh is removed at once, and the new PDF can be shared")
    func writeEndingAfterARefreshIsRemoved() async throws {
        let world = SheetWorld()
        let sheet = await exported(in: world)
        await world.files.gate.close()
        sheet.share()
        await waitUntil("the write held") { await world.files.gate.waiting == 1 }

        sheet.refresh()
        await world.files.gate.open()
        await waitUntil("the file to go") { world.files.removed.count == 1 }
        #expect(sheet.openShare == nil)

        await world.passThePause(thenExports: 2)
        await waitUntil("the new PDF") { sheet.document != nil }
        sheet.share()
        await waitUntil("the share of the new PDF") { sheet.openShare != nil }
        #expect(world.files.written.count == 2)
    }

    @Test("A file that cannot be written opens no share, and the next tap writes again")
    func failedWriteSharesNothing() async throws {
        let world = SheetWorld()
        let sheet = await exported(in: world)
        world.files.fails(true)

        sheet.share()
        await waitUntil("the write") { world.files.asked == 1 }
        await settle()
        #expect(sheet.openShare == nil)

        world.files.fails(false)
        sheet.share()
        await waitUntil("the share") { sheet.openShare != nil }
        #expect(world.files.asked == 2)
        #expect(world.files.written.count == 1)
    }

    // MARK: - How the share sheet ended

    @Test("The share sheet's end reads as saved, sent or cancelled", arguments: [
        (nil as String?, false, ShareResult.cancelled),
        ("com.apple.DocumentManagerUICore.SaveToFiles", false, .cancelled),
        ("com.apple.DocumentManagerUICore.SaveToFiles", true, .saved),
        ("com.apple.UIKit.activity.Mail", true, .sent),
        (nil, true, .sent),
    ])
    func shareResultOfThePlatform(activity: String?, completed: Bool, result: ShareResult) {
        #expect(ShareResult(activity: activity, completed: completed) == result)
    }
}
