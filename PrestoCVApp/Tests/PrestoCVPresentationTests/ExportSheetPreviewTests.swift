import Foundation
import Testing
import PrestoCVDomain
@testable import PrestoCVPresentation
import PrestoCVWorkflowPorts

/// What the sheet shows above its lines while a new PDF is made: the PDF it held, dimmed, until the new one comes, and
/// nothing when the new export fails (#407).
@MainActor
@Suite("Export sheet keeps the last PDF while a new one is made")
struct ExportSheetPreviewTests {

    private static let forestPDF = ExportOutcome(pdf: Data([4, 5, 6]), pageCount: 2, requiredPages: 2)
    private static let forestDocument = ExportedDocument(pdf: Data([4, 5, 6]), pages: 2)

    /// A sheet with its first PDF on screen, and the next exports held at the gate.
    private static func sheetWithAPDF() async throws -> (SheetWorld, ExportSheetViewModel, ExportID) {
        let world = SheetWorld()
        world.cv = SheetWorld.cv(design: "modern", palette: "ocean", fonts: "serif")
        let sheet = world.sheet()
        sheet.start()
        await world.passThePause(thenExports: 1)
        await waitUntil("the first PDF") { sheet.document != nil }
        let first = try #require(sheet.documentID)
        await world.exporter.gate.close()
        return (world, sheet, first)
    }

    // MARK: - Before the first PDF

    @Test("Before its first PDF the sheet shows none, while the export runs too")
    func nothingBeforeTheFirstPDF() async {
        let world = SheetWorld()
        await world.exporter.gate.close()
        let sheet = world.sheet()

        #expect(sheet.preview == .none)

        sheet.start()
        await world.passThePause(thenExports: 1)
        await world.held(1)

        #expect(sheet.status == .exporting)
        #expect(sheet.preview == .none)
        await world.exporter.gate.open()
    }

    @Test("A PDF made is shown, with the id it opens on the whole screen with")
    func thePDFMadeIsShown() async throws {
        let (_, sheet, first) = try await Self.sheetWithAPDF()

        #expect(sheet.preview == .pdf(ExportingFake.onePageDocument, first))
    }

    // MARK: - While a new PDF is made

    @Test("A look chosen after a PDF keeps that PDF on screen, as replaced, until the new one comes")
    func aChoiceKeepsTheLastPDF() async throws {
        let (world, sheet, first) = try await Self.sheetWithAPDF()

        sheet.choose(palette: "forest")

        #expect(sheet.status == .exporting)
        #expect(sheet.preview == .replaced(ExportingFake.onePageDocument, first))
        #expect(sheet.document == nil, "the PDF replaced is no longer the sheet's PDF")
        #expect(sheet.shareAvailability == .preparing, "a PDF replaced is never shared")

        sheet.showFullPDF()
        #expect(sheet.fullPDF == nil, "a PDF replaced does not open on the whole screen")

        world.exporter.returns(.success(Self.forestPDF))
        await world.passThePause(thenExports: 2)
        await world.exporter.gate.open()
        await waitUntil("the new PDF") { sheet.document != nil }

        let second = try #require(sheet.documentID)
        #expect(second != first)
        #expect(sheet.preview == .pdf(Self.forestDocument, second))
    }

    @Test("A language chosen after a PDF keeps that PDF on screen while the new one is made")
    func aLanguageKeepsTheLastPDF() async throws {
        let (world, sheet, first) = try await Self.sheetWithAPDF()

        sheet.select(language: SheetWorld.language("en"))
        await world.passThePause(thenExports: 2)
        await world.held(1)

        #expect(sheet.preview == .replaced(ExportingFake.onePageDocument, first))
        await world.exporter.gate.open()
    }

    @Test("A new try after a PDF keeps that PDF on screen while the new one is made")
    func aRefreshKeepsTheLastPDF() async throws {
        let (world, sheet, first) = try await Self.sheetWithAPDF()

        sheet.refresh()
        await world.passThePause(thenExports: 2)
        await world.held(1)

        #expect(sheet.preview == .replaced(ExportingFake.onePageDocument, first))
        await world.exporter.gate.open()
    }

    @Test("Two choices in a row keep the PDF that was on screen, not the export the second one stopped")
    func twoChoicesKeepTheFirstPDF() async throws {
        let (world, sheet, first) = try await Self.sheetWithAPDF()

        sheet.choose(palette: "forest")
        await world.passThePause(thenExports: 2)
        await world.held(1)
        sheet.choose(fonts: "sans")

        #expect(sheet.preview == .replaced(ExportingFake.onePageDocument, first))

        await world.passThePause(thenExports: 3)
        #expect(sheet.preview == .replaced(ExportingFake.onePageDocument, first))
        await world.exporter.gate.open()
    }

    @Test("Choosing the look already on screen keeps the PDF shown as the sheet's own")
    func theSameLookKeepsThePDF() async throws {
        let (world, sheet, first) = try await Self.sheetWithAPDF()

        sheet.choose(palette: "ocean")
        world.passThePause()
        await settle()

        #expect(sheet.preview == .pdf(ExportingFake.onePageDocument, first))
        await world.exporter.gate.open()
    }

    // MARK: - When the new PDF does not come

    @Test("A new export that fails shows no PDF: the one replaced is not the look chosen")
    func aFailureShowsNone() async throws {
        let (world, sheet, _) = try await Self.sheetWithAPDF()
        world.exporter.returns(.failure(ExportFailure.renderingFailed))

        sheet.choose(palette: "forest")
        await world.passThePause(thenExports: 2)
        await world.exporter.gate.open()
        await waitUntil("the export to end") { sheet.status != .exporting }

        #expect(sheet.status == .failed)
        #expect(sheet.preview == .none)
    }

    @Test("A CV that lacks what the PDF needs shows no PDF after a PDF replaced")
    func notReadyShowsNone() async throws {
        let (world, sheet, _) = try await Self.sheetWithAPDF()

        world.cv = SheetWorld.cv(fullName: "", design: "modern", palette: "ocean", fonts: "serif")
        sheet.refresh()
        world.passThePause()
        await waitUntil("the export to end") { sheet.status != .exporting }

        #expect(sheet.status == .notReady)
        #expect(sheet.preview == .none)
        await world.exporter.gate.open()
    }

    @Test("A sheet stopped while it replaces a PDF shows none, and a new start shows none until its PDF")
    func stopShowsNone() async throws {
        let (world, sheet, _) = try await Self.sheetWithAPDF()
        sheet.choose(palette: "forest")

        sheet.stop()

        #expect(sheet.preview == .none)

        sheet.start()
        #expect(sheet.preview == .none, "a sheet opened again starts without the PDF of the last time")
        await world.exporter.gate.open()
    }
}
