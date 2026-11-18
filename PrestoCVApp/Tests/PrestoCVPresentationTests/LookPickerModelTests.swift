import Foundation
import Testing
import PrestoCVDomain
@testable import PrestoCVPresentation
import PrestoCVWorkflowPorts

/// The look picker as the export sheet gives it to the view: the groups of choices, which one is chosen, and what a tap
/// on each item does (#407).
@MainActor
@Suite("Look picker of the export sheet")
struct LookPickerModelTests {

    private typealias Item = LookPickerModel.Item

    private static func sheet(
        design: String? = "modern", palette: String? = "ocean", fonts: String? = "serif"
    ) -> (SheetWorld, ExportSheetViewModel) {
        let world = SheetWorld()
        world.cv = SheetWorld.cv(design: design, palette: palette, fonts: fonts)
        return (world, world.sheet())
    }

    private static func group(_ part: LookPart, of sheet: ExportSheetViewModel) throws -> LookPickerModel.Group {
        try #require(sheet.lookPicker.groups.first { $0.part == part })
    }

    private static func item(_ id: Item.ID, of part: LookPart, in sheet: ExportSheetViewModel) throws -> Item {
        try #require(try group(part, of: sheet).items.first { $0.id == id })
    }

    private static func selected(in sheet: ExportSheetViewModel) -> [[Item.ID]] {
        sheet.lookPicker.groups.map { $0.items.filter(\.isSelected).map(\.id) }
    }

    // MARK: - The groups

    @Test("The picker shows the design first, then the fonts, then the colours")
    func groupsInOrder() {
        let (_, sheet) = Self.sheet()

        #expect(sheet.lookPicker.groups.map(\.part) == [.design, .fonts, .palette])
    }

    @Test("Fonts and colours start with the design's own, then offer the app's choices in the app's order")
    func itemsInOrder() {
        let (_, sheet) = Self.sheet()

        #expect(sheet.lookPicker.groups.map { $0.items.map(\.id) } == [
            [.offered("classic"), .offered("modern")],
            [.designsOwn, .offered("sans"), .offered("serif")],
            [.designsOwn, .offered("ocean"), .offered("forest")]
        ])
    }

    @Test("The choices are named by the codes the app gives them, in its order, and drawn with their samples")
    func namesAreTheCodes() {
        let (_, sheet) = Self.sheet()
        let offered = sheet.lookPicker.groups.map { group in
            group.items.compactMap { item -> LookChoice? in
                guard case .offered(let choice) = item.kind else { return nil }
                return choice
            }
        }

        #expect(offered == [sheet.lookChoices.designs, sheet.lookChoices.fontSchemes, sheet.lookChoices.palettes])
    }

    // MARK: - What is chosen

    @Test("The look the CV keeps is chosen in each group, and nothing else")
    func selectedByID() {
        let (_, sheet) = Self.sheet()

        #expect(Self.selected(in: sheet) == [[.offered("modern")], [.offered("serif")], [.offered("ocean")]])
    }

    @Test("A CV that keeps no colour and no fonts has the design's own chosen")
    func noValueSelectsTheDesignsOwn() {
        let (_, sheet) = Self.sheet(palette: nil, fonts: nil)

        #expect(Self.selected(in: sheet) == [[.offered("modern")], [.designsOwn], [.designsOwn]])
    }

    @Test("The design's own is drawn with the palette and fonts of the design shown, as the PDF sets them")
    func designsOwnShowsTheDesignsSample() throws {
        let (_, sheet) = Self.sheet(palette: nil, fonts: nil)

        #expect(try Self.item(.designsOwn, of: .palette, in: sheet).kind == .designsOwn(LookChoice.Sample(LookOptionsFake.forest)))
        #expect(try Self.item(.designsOwn, of: .fonts, in: sheet).kind == .designsOwn(.typeface(.serif)))

        sheet.choose(design: "classic")

        #expect(try Self.item(.designsOwn, of: .palette, in: sheet).kind == .designsOwn(LookChoice.Sample(LookOptionsFake.ocean)))
        #expect(try Self.item(.designsOwn, of: .fonts, in: sheet).kind == .designsOwn(.typeface(.system)))
    }

    // MARK: - A look from an earlier version

    @Test("A colour the app no longer offers is one more item, last and chosen, and only its group says so")
    func anUnknownIDAddsOneKeptItem() throws {
        let (_, sheet) = Self.sheet(palette: "sunset")
        let palettes = try Self.group(.palette, of: sheet)

        #expect(palettes.items.map(\.id) == [.designsOwn, .offered("ocean"), .offered("forest"), .kept])
        #expect(palettes.items.filter(\.isSelected).map(\.id) == [.kept])
        #expect(palettes.items.filter(\.isKept).count == 1)
        #expect(sheet.lookPicker.groups.map(\.keepsAnEarlierLook) == [false, false, true])
    }

    @Test("A design the app no longer offers is kept, and the design's own follows the design the PDF is made with")
    func anUnknownDesignIsKept() throws {
        let (_, sheet) = Self.sheet(design: "retro", palette: nil, fonts: nil)

        #expect(try Self.group(.design, of: sheet).items.map(\.id) == [.offered("classic"), .offered("modern"), .kept])
        #expect(Self.selected(in: sheet) == [[.kept], [.designsOwn], [.designsOwn]])
        #expect(try Self.item(.designsOwn, of: .palette, in: sheet).kind == .designsOwn(LookChoice.Sample(LookOptionsFake.ocean)),
                "the PDF of a design the app does not have is made with the default one, classic")
    }

    @Test("Another choice replaces the kept item: it goes at once, and the choice goes to the CV")
    func theKeptItemGoesAfterAChoice() async throws {
        let (world, sheet) = Self.sheet(palette: "sunset")
        sheet.start()
        await world.passThePause(thenExports: 1)

        sheet.pick(try Self.item(.offered("ocean"), of: .palette, in: sheet))

        #expect(try Self.group(.palette, of: sheet).items.map(\.id) == [.designsOwn, .offered("ocean"), .offered("forest")])
        #expect(Self.selected(in: sheet)[2] == [.offered("ocean")])
        #expect(world.looks == [ChosenLook(look: EditorLook(design: "modern", palette: "ocean", fonts: "serif"), parts: [.palette])])
    }

    // MARK: - A tap

    @Test("A tap on a choice of each group chooses that part of the look")
    func aTapChoosesThePart() async throws {
        let (world, sheet) = Self.sheet()
        sheet.start()
        await world.passThePause(thenExports: 1)

        sheet.pick(try Self.item(.offered("classic"), of: .design, in: sheet))
        sheet.pick(try Self.item(.offered("sans"), of: .fonts, in: sheet))
        sheet.pick(try Self.item(.offered("forest"), of: .palette, in: sheet))

        #expect(world.looks == [
            ChosenLook(look: EditorLook(design: "classic", palette: "ocean", fonts: "serif"), parts: [.design]),
            ChosenLook(look: EditorLook(design: "classic", palette: "ocean", fonts: "sans"), parts: [.fonts]),
            ChosenLook(look: EditorLook(design: "classic", palette: "forest", fonts: "sans"), parts: [.palette])
        ])
        #expect(Self.selected(in: sheet) == [[.offered("classic")], [.offered("sans")], [.offered("forest")]])
    }

    @Test("A tap on the design's own leaves the colour or the fonts to the design")
    func aTapOnTheDesignsOwnSendsNone() async throws {
        let (world, sheet) = Self.sheet()
        sheet.start()
        await world.passThePause(thenExports: 1)

        sheet.pick(try Self.item(.designsOwn, of: .palette, in: sheet))
        sheet.pick(try Self.item(.designsOwn, of: .fonts, in: sheet))

        #expect(world.looks == [
            ChosenLook(look: EditorLook(design: "modern", palette: nil, fonts: "serif"), parts: [.palette]),
            ChosenLook(look: EditorLook(design: "modern", palette: nil, fonts: nil), parts: [.fonts])
        ])
        #expect(Self.selected(in: sheet) == [[.offered("modern")], [.designsOwn], [.designsOwn]])
    }

    @Test("A tap on the kept item does nothing: it is already the look of the PDF")
    func aTapOnTheKeptItemDoesNothing() async throws {
        let (world, sheet) = Self.sheet(palette: "sunset")
        sheet.start()
        await world.passThePause(thenExports: 1)
        await settle()

        sheet.pick(try Self.item(.kept, of: .palette, in: sheet))
        world.passThePause()
        await settle()

        #expect(world.looks.isEmpty)
        #expect(world.exporter.calls == 1)
        #expect(sheet.shownLook == EditorLook(design: "modern", palette: "sunset", fonts: "serif"))
    }
}
