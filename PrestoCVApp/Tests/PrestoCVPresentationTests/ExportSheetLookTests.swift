import Foundation
import Testing
import PrestoCVDomain
@testable import PrestoCVPresentation
import PrestoCVWorkflowPorts

/// The look of the PDF chosen in the sheet: what the sheet shows, what it exports and what goes to the CV (#407).
@MainActor
@Suite("Export sheet look")
struct ExportSheetLookTests {

    private static let modern = EditorLook(design: "modern", palette: "ocean", fonts: "serif")

    private static func modernCV() -> CV { SheetWorld.cv(design: "modern", palette: "ocean", fonts: "serif") }

    // MARK: - What the sheet shows

    @Test("The sheet shows the look the CV keeps, among the designs, palettes and fonts the app offers")
    func showsTheCVsLook() {
        let world = SheetWorld()
        world.cv = Self.modernCV()
        let sheet = world.sheet()

        #expect(sheet.shownLook == Self.modern)
        #expect(sheet.lookChoices.designs.map(\.id) == ["classic", "modern"])
        #expect(sheet.lookChoices.palettes.map(\.id) == ["ocean", "forest"])
        #expect(sheet.lookChoices.fontSchemes.map(\.id) == ["sans", "serif"])
    }

    @Test("A CV that keeps no look shows the app's default one")
    func showsTheDefaultLook() {
        let world = SheetWorld()
        let sheet = world.sheet()

        #expect(sheet.shownLook == EditorLook(design: "classic", palette: "ocean", fonts: "sans"))
    }

    @Test("The look shown follows the CV each export reads")
    func showsTheLookOfTheCVRead() async {
        let world = SheetWorld()
        let sheet = world.sheet()
        world.cv = Self.modernCV()

        sheet.start()
        await world.passThePause(thenExports: 1)
        await settle()

        #expect(sheet.shownLook == Self.modern)
    }

    // MARK: - A choice

    @Test("A palette chosen in the sheet is shown at once, exported after the pause, and goes to the CV")
    func aPaletteIsChosen() async {
        let world = SheetWorld()
        world.cv = Self.modernCV()
        let sheet = world.sheet()
        sheet.start()
        await world.passThePause(thenExports: 1)
        await settle()
        let read = world.snapshotsTaken

        sheet.choose(palette: "forest")

        let forest = EditorLook(design: "modern", palette: "forest", fonts: "serif")
        #expect(sheet.shownLook == forest)
        #expect(world.snapshotsTaken == read, "the choice reads nothing: the export reads the CV after the pause")
        #expect(world.looks == [ChosenLook(look: forest, parts: [.palette])])

        await world.passThePause(thenExports: 2)
        await settle()

        #expect(world.exporter.snapshots.last?.design == DesignChoice(design: "modern", palette: "forest", fonts: "serif"))
        #expect(sheet.shownLook == forest)
    }

    @Test("A look chosen in the sheet stays in the later exports, while the CV the editor shows still holds the old one")
    func aChoiceStays() async {
        let world = SheetWorld()
        world.cv = Self.modernCV()
        let sheet = world.sheet()
        sheet.start()
        await world.passThePause(thenExports: 1)
        sheet.choose(palette: "forest")
        await world.passThePause(thenExports: 2)

        sheet.select(language: SheetWorld.language("en"))
        await world.passThePause(thenExports: 3)
        sheet.refresh()
        await world.passThePause(thenExports: 4)
        await settle()

        let forest = DesignChoice(design: "modern", palette: "forest", fonts: "serif")
        #expect(world.exporter.snapshots.dropFirst().map(\.design) == [forest, forest, forest])
        #expect(sheet.shownLook == EditorLook(design: "modern", palette: "forest", fonts: "serif"))
        #expect(world.looks.count == 1, "only the person's choice goes to the CV")
    }

    @Test("Two parts chosen one after the other make one export with both, and each goes to the CV alone")
    func twoPartsInARow() async {
        let world = SheetWorld()
        world.cv = Self.modernCV()
        let sheet = world.sheet()
        sheet.start()
        await world.passThePause(thenExports: 1)

        sheet.choose(palette: "forest")
        sheet.choose(fonts: "sans")
        await world.passThePause(thenExports: 2)
        await settle()

        #expect(world.exporter.calls == 2)
        #expect(world.exporter.snapshots.last?.design == DesignChoice(design: "modern", palette: "forest", fonts: "sans"))
        #expect(world.looks == [
            ChosenLook(look: EditorLook(design: "modern", palette: "forest", fonts: "serif"), parts: [.palette]),
            ChosenLook(look: EditorLook(design: "modern", palette: "forest", fonts: "sans"), parts: [.fonts])
        ])
    }

    @Test("Only the parts chosen in the sheet replace the CV's: the others follow the CV as the editor shows it")
    func theOtherPartsFollowTheCV() async {
        let world = SheetWorld()
        world.cv = Self.modernCV()
        let sheet = world.sheet()
        sheet.start()
        await world.passThePause(thenExports: 1)

        sheet.choose(fonts: "sans")
        world.cv = SheetWorld.cv(design: "modern", palette: "forest", fonts: "serif")
        await world.passThePause(thenExports: 2)
        await settle()

        #expect(world.exporter.snapshots.last?.design == DesignChoice(design: "modern", palette: "forest", fonts: "sans"))
        #expect(sheet.shownLook == EditorLook(design: "modern", palette: "forest", fonts: "sans"))
    }

    @Test("A part the person did not choose keeps what the CV holds, a palette the app does not offer too")
    func anUnknownPartIsKept() async {
        let world = SheetWorld()
        world.cv = SheetWorld.cv(design: "modern", palette: "sunset", fonts: "serif")
        let sheet = world.sheet()
        sheet.start()
        await world.passThePause(thenExports: 1)

        sheet.choose(fonts: "sans")
        await world.passThePause(thenExports: 2)
        await settle()

        #expect(world.exporter.snapshots.last?.design == DesignChoice(design: "modern", palette: "sunset", fonts: "sans"))
    }

    @Test("A CV that keeps no look is exported with the whole look shown, and the whole look goes to the CV")
    func aCVWithNoLook() async {
        let world = SheetWorld()
        let sheet = world.sheet()
        sheet.start()
        await world.passThePause(thenExports: 1)

        sheet.choose(palette: "forest")
        await world.passThePause(thenExports: 2)
        await settle()

        let whole = EditorLook(design: "classic", palette: "forest", fonts: "sans")
        #expect(world.exporter.snapshots.last?.design == DesignChoice(design: "classic", palette: "forest", fonts: "sans"))
        #expect(world.looks == [ChosenLook(look: whole, parts: [.palette])])
        #expect(sheet.shownLook == whole)
    }

    @Test("A look chosen while the first pause runs makes one export, with it")
    func aChoiceDuringThePause() async {
        let world = SheetWorld()
        world.cv = Self.modernCV()
        let sheet = world.sheet()

        sheet.start()
        sheet.choose(palette: "forest")
        await world.passThePause(thenExports: 1)
        world.passThePause()
        await settle()

        #expect(world.exporter.calls == 1)
        #expect(world.exporter.snapshots.first?.design == DesignChoice(design: "modern", palette: "forest", fonts: "serif"))
    }

    // MARK: - The look of the PDF on screen

    @Test("Choosing the look of the PDF on screen keeps the PDF and its share, and takes the choice to the CV")
    func choosingTheLookOnScreenKeepsThePDF() async throws {
        let world = SheetWorld()
        world.cv = Self.modernCV()
        let sheet = world.sheet()
        sheet.start()
        await world.passThePause(thenExports: 1)
        await waitUntil("the PDF") { sheet.document != nil }
        let pdf = try #require(sheet.documentID)
        sheet.shareEnded(.saved, of: pdf)

        sheet.choose(palette: "ocean")
        world.passThePause()
        await settle()

        #expect(world.exporter.calls == 1, "the PDF on screen already has the ocean palette")
        #expect(sheet.documentID == pdf)
        #expect(sheet.shareOutcome == .saved)
        #expect(sheet.status == .done(pages: 1))
        #expect(world.looks == [ChosenLook(look: Self.modern, parts: [.palette])], "the CV keeps the choice, as any other")
    }

    @Test("Choosing the look of the PDF being made lets that export go on")
    func choosingTheLookBeingMadeLetsTheExportGoOn() async {
        let world = SheetWorld()
        world.cv = Self.modernCV()
        await world.exporter.gate.close()
        let sheet = world.sheet()
        sheet.start()
        await world.passThePause(thenExports: 1)
        await world.held(1)

        sheet.choose(design: "modern")
        world.passThePause()
        await world.exporter.gate.open()
        await waitUntil("the PDF") { sheet.document != nil }
        await settle()

        #expect(world.exporter.calls == 1)
        #expect(world.exporter.cancellations.withLock { $0 } == 0)
        #expect(sheet.status == .done(pages: 1))
        #expect(world.looks == [ChosenLook(look: Self.modern, parts: [.design])])
    }

    // MARK: - A look the app cannot keep

    @Test("A look the app cannot keep changes nothing: no export, nothing shown, nothing sent to the CV")
    func anInvalidLookChangesNothing() async {
        let world = SheetWorld()
        world.cv = Self.modernCV()
        let sheet = world.sheet()
        sheet.start()
        await world.passThePause(thenExports: 1)
        await settle()

        sheet.choose(design: "Not valid!")
        world.passThePause()
        await settle()

        #expect(world.exporter.calls == 1)
        #expect(world.looks.isEmpty)
        #expect(sheet.shownLook == Self.modern)
        #expect(sheet.status == .done(pages: 1))
    }
}
