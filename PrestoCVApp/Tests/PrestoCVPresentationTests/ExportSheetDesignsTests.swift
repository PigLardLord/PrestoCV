import Testing
import PrestoCVDomain
@testable import PrestoCVPresentation
import PrestoCVWorkflowPorts

/// The export sheet while the bundled designs are checked behind the open app (#566): the designs that pass join the
/// picker, an export that waits for its design is told as preparing, and with no design to print "Try again" checks
/// them again.
@MainActor
@Suite("Export sheet while the designs are checked")
struct ExportSheetDesignsTests {

    private static let all = LookOptionsFake().options()

    /// The fake's options with `designs` alone, and the own looks of those alone: a design not checked yet has none.
    private static func options(_ designs: [String], _ status: LookOptionsStatus) -> LookOptions {
        LookOptions(
            designs: all.designs.filter { designs.contains($0.id) }, palettes: all.palettes,
            fontSchemes: all.fontSchemes, defaultDesign: all.defaultDesign,
            ownLooks: all.ownLooks.filter { designs.contains($0.key) }, status: status
        )
    }

    private static func world(_ options: DrivenLookOptions) -> SheetWorld {
        let world = SheetWorld()
        world.lookOptions = options
        return world
    }

    @Test("A design that passes while the sheet is open joins the picker in the options' order; the picker says more can join until the check ends")
    func designsJoin() async {
        let options = DrivenLookOptions(Self.options(["classic"], .checking))
        let sheet = Self.world(options).sheet()
        let watch = Task { await sheet.watchDesigns() }
        defer { watch.cancel() }

        #expect(sheet.lookPicker.groups.map(\.checksMore) == [true, false, false])
        await waitUntil("the sheet watches the designs") { options.watching == 1 }
        options.tell(Self.options(["classic", "modern"], .ready))
        await waitUntil("modern joins") { sheet.lookChoices.designs.count == 2 }

        #expect(sheet.lookChoices.designs.map(\.id) == ["classic", "modern"])
        #expect(sheet.lookPicker.groups.map(\.checksMore) == [false, false, false])
    }

    @Test("The look of a CV that keeps none takes the default design's own palette and fonts once the check finds them; a look chosen in the sheet stays")
    func theDefaultLookFollowsTheCheck() async {
        let options = DrivenLookOptions(Self.options([], .checking))
        let sheet = Self.world(options).sheet()
        let watch = Task { await sheet.watchDesigns() }
        defer { watch.cancel() }

        #expect(sheet.shownLook == EditorLook(design: "classic", palette: nil, fonts: nil))
        await waitUntil("the sheet watches the designs") { options.watching == 1 }
        options.tell(Self.options(["classic"], .checking))
        await waitUntil("the default design's own look") { sheet.shownLook.palette != nil }
        #expect(sheet.shownLook == EditorLook(design: "classic", palette: "ocean", fonts: "sans"))

        sheet.choose(palette: "forest")
        options.tell(Self.options(["classic", "modern"], .ready))
        await waitUntil("modern joins") { sheet.lookChoices.designs.count == 2 }
        #expect(sheet.shownLook == EditorLook(design: "classic", palette: "forest", fonts: "sans"))
    }

    @Test("An export whose design is still being checked is told as preparing, each time anew; one whose design is offered is not")
    func aWaitIsTold() async {
        let options = DrivenLookOptions(Self.options(["classic"], .checking))
        let world = Self.world(options)
        world.cv = SheetWorld.cv(design: "modern")
        let sheet = world.sheet()
        await world.exporter.gate.close()

        sheet.start()
        await world.passThePause(thenExports: 1)
        let first = sheet.waitToAnnounce
        #expect(first != nil)
        await world.exporter.gate.open()
        await waitUntil("the export ends") { sheet.status != .exporting }
        #expect(sheet.waitToAnnounce == nil)

        world.cv = SheetWorld.cv(design: "classic")
        sheet.refresh()
        await world.passThePause(thenExports: 2)
        await waitUntil("the export ends") { sheet.status != .exporting }
        #expect(sheet.waitToAnnounce == nil, "classic passed: nothing to wait for")

        await world.exporter.gate.close()
        world.cv = SheetWorld.cv(design: "modern")
        sheet.refresh()
        await world.passThePause(thenExports: 3)
        #expect(sheet.waitToAnnounce != nil)
        #expect(sheet.waitToAnnounce != first, "a second wait is a new value")
        await world.exporter.gate.open()
    }

    @Test("With no design to print the sheet says so and tells VoiceOver; Try again checks the designs again and exports")
    func tryAgain() async {
        let options = DrivenLookOptions(Self.options([], .unavailable))
        let world = Self.world(options)
        world.exporter.returns(.failure(ExportFailure.designsUnavailable))
        let sheet = world.sheet()

        sheet.retryDesigns()
        #expect(options.retries == 0, "nothing to try again before the export says so")
        sheet.start()
        await world.passThePause(thenExports: 1)
        await waitUntil("the export ends") { sheet.status != .exporting }
        #expect(sheet.status == .designsUnavailable)
        #expect(sheet.statusToAnnounce == .designsUnavailable)

        world.exporter.returns(.success(ExportingFake.onePage))
        sheet.retryDesigns()
        #expect(options.retries == 1)
        #expect(sheet.status == .exporting)
        await world.passThePause(thenExports: 2)
        await waitUntil("the PDF") { sheet.status == .done(pages: 1) }
    }
}
