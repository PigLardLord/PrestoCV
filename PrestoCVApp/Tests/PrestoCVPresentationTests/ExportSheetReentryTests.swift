import Foundation
import Testing
@testable import PrestoCVPresentation

/// The sheet calls out synchronously (the callback that takes a language to the CV, the snapshot closure), and the code
/// called can call back into the sheet. After a call-out the sheet writes nothing and starts nothing for an intent that
/// is no longer the latest.
@MainActor
@Suite("Export sheet re-entry")
struct ExportSheetReentryTests {

    /// The sheet under test, which the callbacks reach.
    private final class Box { var sheet: ExportSheetViewModel? }

    @Test("A callback that stops the sheet leaves it idle, and no export reaches the port")
    func stopFromTheLanguageCallback() async {
        let world = SheetWorld()
        let box = Box()
        let sheet = world.sheet(whenChosen: { _ in box.sheet?.stop() })
        box.sheet = sheet

        sheet.select(language: SheetWorld.language("de"))
        world.passThePause()
        await settle()

        #expect(world.exporter.calls == 0)
        #expect(sheet.status == .idle)
        #expect(sheet.document == nil)
    }

    @Test("A callback that selects again leaves the newest language the only export")
    func selectFromTheLanguageCallback() async {
        let world = SheetWorld()
        let box = Box()
        var again = true
        let sheet = world.sheet(whenChosen: { _ in
            guard again else { return }
            again = false
            box.sheet?.select(language: SheetWorld.language("en"))
        })
        box.sheet = sheet

        sheet.select(language: SheetWorld.language("de"))
        world.passThePause()
        await waitUntil("the PDF") { sheet.document != nil }
        await settle()

        #expect(world.exporter.languages.map(\.tag) == ["en"])
        #expect(sheet.selectedLanguage == SheetWorld.language("en"))
        #expect(sheet.status == .done(pages: 1))
    }

    @Test("A snapshot that stops the sheet leaves it idle: no export, nothing published")
    func stopFromTheSnapshot() async {
        let world = SheetWorld()
        let box = Box()
        let sheet = world.sheet(whenRead: { box.sheet?.stop() })
        box.sheet = sheet

        sheet.start()
        world.passThePause()
        await settle()

        #expect(world.snapshotsTaken == 1)
        #expect(world.exporter.calls == 0)
        #expect(sheet.status == .idle)
        #expect(sheet.document == nil)
        #expect(sheet.suggestedFileName == nil)
        #expect(sheet.missing == .unknown)
    }
}
