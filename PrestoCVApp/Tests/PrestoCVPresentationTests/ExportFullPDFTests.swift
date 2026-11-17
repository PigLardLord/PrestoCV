import Foundation
import Testing
@testable import PrestoCVPresentation

/// The PDF of the export sheet on the whole screen: it shows the PDF the sheet holds, under the name of its file, and
/// never one the sheet no longer holds.
@MainActor
@Suite("Export sheet full PDF")
struct ExportFullPDFTests {

    /// A sheet that has made its PDF.
    private func exported(in world: SheetWorld) async -> ExportSheetViewModel {
        let sheet = world.sheet()
        sheet.start()
        await world.passThePause(thenExports: 1)
        await waitUntil("the PDF") { sheet.document != nil }
        return sheet
    }

    @Test("Without a PDF there is nothing to show on the whole screen, before the export and while it runs")
    func nothingToShowWithoutAPDF() {
        let world = SheetWorld()
        let sheet = world.sheet()

        sheet.showFullPDF()
        #expect(sheet.fullPDF == nil, "before the export")

        sheet.start()
        sheet.showFullPDF()
        #expect(sheet.fullPDF == nil, "while the export waits and runs")
    }

    @Test("The whole screen shows the PDF the sheet holds, under the name of its file")
    func showsThePDFUnderItsFileName() async throws {
        let world = SheetWorld()
        let sheet = await exported(in: world)

        sheet.showFullPDF()

        let full = try #require(sheet.fullPDF)
        #expect(full.document == sheet.document)
        #expect(full.id == sheet.documentID)
        #expect(full.fileName == "Mara Ellison – Curriculum.pdf")
    }

    @Test("Closing the whole screen keeps the sheet's PDF and status")
    func closeKeepsThePDF() async throws {
        let world = SheetWorld()
        let sheet = await exported(in: world)
        let pdf = try #require(sheet.documentID)
        sheet.showFullPDF()

        sheet.closeFullPDF()

        #expect(sheet.fullPDF == nil)
        #expect(sheet.documentID == pdf)
        #expect(sheet.status == .done(pages: 1))
    }

    /// What ends the PDF the whole screen shows.
    enum Ending: String, CaseIterable, CustomTestStringConvertible {
        case refreshed, languageChosen, stopped
        var testDescription: String { rawValue }
    }

    @Test("A new export or the end of the sheet closes the whole screen", arguments: Ending.allCases)
    func aNewExportOrTheEndClosesIt(ending: Ending) async throws {
        let world = SheetWorld()
        let sheet = await exported(in: world)
        sheet.showFullPDF()
        try #require(sheet.fullPDF != nil)

        switch ending {
        case .refreshed: sheet.refresh()
        case .languageChosen: sheet.select(language: SheetWorld.language("de"))
        case .stopped: sheet.stop()
        }

        #expect(sheet.fullPDF == nil, "the whole screen never shows a PDF the sheet no longer holds")
    }
}
