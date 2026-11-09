import Testing
import Foundation
import PrestoCVDomain
import PrestoCVWorkflowPorts
import PrestoCVIntegration
import CVDesignCatalog
import CVRendering
import CVRenderingTestSupport
import CVBundledHeadings

// MARK: Doubles

/// Renders like the fake and keeps every HTML it was given, so a test reads the look the export asked for.
private actor RecordingRenderer: PDFRendering {
    private(set) var rendered: [String] = []
    func render(html: String, page: PageSetup) async throws -> RenderedPDF {
        rendered.append(html)
        return try await FakePDFRenderer().render(html: html, page: page)
    }
}

/// An in-memory store whose first design read waits the way the file store's lock wait does: the wait sleeps in a task of
/// its own, so it ignores the caller's cancellation, and then reads or times out. It counts the design reads.
private actor HeldDesignStore: DesignStore {
    struct LockTimeout: Error {}
    private let store = InMemoryDesignStore()
    private let installed: [ValidatedDesign]
    private let timesOut: Bool
    private var held = true
    private(set) var reads = 0
    private let entered: AsyncStream<Void>, enteredSignal: AsyncStream<Void>.Continuation
    private let released: AsyncStream<Void>, releaseSignal: AsyncStream<Void>.Continuation

    init(installed: [ValidatedDesign], timesOut: Bool) {
        self.installed = installed
        self.timesOut = timesOut
        (entered, enteredSignal) = AsyncStream.makeStream(of: Void.self)
        (released, releaseSignal) = AsyncStream.makeStream(of: Void.self)
    }

    /// Lets the held read go on.
    func release() { releaseSignal.yield() }

    /// Waits until a read is held: true, or false after `timeout`.
    func waitUntilEntered(timeout: Duration = .seconds(10)) async -> Bool {
        let stream = entered
        return await withTaskGroup(of: Bool.self) { group in
            group.addTask { for await _ in stream { return true }; return false }
            group.addTask {
                do { try await Task.sleep(for: timeout) } catch { return false }
                return false
            }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }
    }

    func design(id: String) async throws -> ValidatedDesign? {
        reads += 1
        if held {
            held = false
            enteredSignal.yield()
            let released = released
            await Task { for await _ in released { return } }.value
            if timesOut { throw LockTimeout() }
        }
        return installed.first { $0.manifest.id == id }
    }

    func installedDesigns() async throws -> [DesignManifest] { installed.map(\.manifest) }
    @discardableResult func save(_ design: ValidatedDesign) async throws -> ImportSave { try await store.save(design) }
    func saveIfNewer(_ design: ValidatedDesign) async throws -> ConditionalSave { try await store.saveIfNewer(design) }
    func installedOrigins() async throws -> [String: DesignOrigin] { try await store.installedOrigins() }
    func adoptAsBundled(_ design: ValidatedDesign) async throws -> Bool { try await store.adoptAsBundled(design) }
}

/// Two installed designs that differ in stylesheet, default palette and default fonts.
private enum Installed {
    static let defaultID = "professional"
    static let professionalCSS = ".cv-name{color:var(--color-primary)}"
    static let modernCSS = ".cv-entry-title{font-weight:600}"

    static func designs() throws -> [ValidatedDesign] {
        [try DesignStoreContract.design(id: "professional", css: professionalCSS, defaultPalette: .ink, defaultFonts: .system),
         try DesignStoreContract.design(id: "modern", css: modernCSS, defaultPalette: .ocean, defaultFonts: .rounded)]
    }

    static func store() async throws -> InMemoryDesignStore {
        let store = InMemoryDesignStore()
        for design in try designs() { _ = try await store.saveIfNewer(design) }
        return store
    }
}

private func exporter(_ store: any DesignStore, renderer: any PDFRendering) -> DesignResolvingExporter {
    DesignResolvingExporter(store: store, defaultDesign: Installed.defaultID, renderer: renderer, inspector: MinimalPDFInspector(),
                            headings: HeadingsCatalog(source: BundleHeadingTableSource()), policy: .standard)
}

private func cv(_ choice: DesignChoice?) -> CV {
    var cv = Fixtures.fullCV()
    cv.choose(design: choice)
    return cv
}

private func choice(_ design: String, palette: String?, fonts: String?) throws -> DesignChoice {
    try #require(DesignChoice(design: design, palette: palette, fonts: fonts))
}

private func italian() throws -> DocumentLanguage { try #require(DocumentLanguage("it")) }

/// The one HTML the renderer was given.
private func onlyHTML(_ renderer: RecordingRenderer) async throws -> String {
    let rendered = await renderer.rendered
    try #require(rendered.count == 1)
    return rendered[0]
}

@Suite("Exporting a CV in the look it keeps")
struct DesignResolvingExporterTests {
    @Test("a CV exports with the design, palette and fonts it keeps")
    func exportsTheCVsLook() async throws {
        let renderer = RecordingRenderer()
        let look = try choice("modern", palette: NamedPalette.plum.rawValue, fonts: FontScheme.serif.rawValue)

        _ = try await exporter(try await Installed.store(), renderer: renderer).export(cv(look), language: try italian())

        let html = try await onlyHTML(renderer)
        #expect(html.contains(Installed.modernCSS))
        #expect(!html.contains(Installed.professionalCSS))
        #expect(html.contains(NamedPalette.plum.palette.customProperties))
        #expect(html.contains(FontScheme.serif.customProperties))
    }

    @Test("a CV that keeps no look exports with the default design, in its own palette and fonts")
    func noLookGivesTheDefault() async throws {
        let renderer = RecordingRenderer()

        _ = try await exporter(try await Installed.store(), renderer: renderer).export(cv(nil), language: try italian())

        let html = try await onlyHTML(renderer)
        #expect(html.contains(Installed.professionalCSS))
        #expect(html.contains(NamedPalette.ink.palette.customProperties))
        #expect(html.contains(FontScheme.system.customProperties))
    }

    @Test("a palette or fonts the CV does not name, or that the app does not know, give the design's own")
    func missingPartsGiveTheDesigns() async throws {
        let renderer = RecordingRenderer()

        _ = try await exporter(try await Installed.store(), renderer: renderer)
            .export(cv(try choice("modern", palette: "navy", fonts: nil)), language: try italian())

        let html = try await onlyHTML(renderer)
        #expect(html.contains(Installed.modernCSS))
        #expect(html.contains(NamedPalette.ocean.palette.customProperties))
        #expect(html.contains(FontScheme.rounded.customProperties))
    }

    @Test("an unknown design falls back to the default design, and the CV keeps its palette and fonts")
    func unknownDesignFallsBack() async throws {
        let renderer = RecordingRenderer()
        let look = try choice("gone", palette: NamedPalette.plum.rawValue, fonts: FontScheme.serif.rawValue)

        _ = try await exporter(try await Installed.store(), renderer: renderer).export(cv(look), language: try italian())

        let html = try await onlyHTML(renderer)
        #expect(html.contains(Installed.professionalCSS))
        #expect(html.contains(NamedPalette.plum.palette.customProperties))
        #expect(html.contains(FontScheme.serif.customProperties))
    }

    @Test("a chosen palette changes the PDF, and the same look gives the same PDF")
    func paletteChangesThePDF() async throws {
        let store = try await Installed.store()
        let ocean = try choice("modern", palette: NamedPalette.ocean.rawValue, fonts: nil)
        let plum = try choice("modern", palette: NamedPalette.plum.rawValue, fonts: nil)
        let export = exporter(store, renderer: FakePDFRenderer())

        let first = try await export.export(cv(ocean), language: try italian())
        let again = try await export.export(cv(ocean), language: try italian())
        let other = try await export.export(cv(plum), language: try italian())

        #expect(first.pdf == again.pdf)
        #expect(first.pdf != other.pdf)
    }

    @Test("a chosen design changes the PDF")
    func designChangesThePDF() async throws {
        let export = exporter(try await Installed.store(), renderer: FakePDFRenderer())
        let palette = NamedPalette.ink.rawValue, fonts = FontScheme.system.rawValue

        let professional = try await export.export(cv(try choice("professional", palette: palette, fonts: fonts)), language: try italian())
        let modern = try await export.export(cv(try choice("modern", palette: palette, fonts: fonts)), language: try italian())

        #expect(professional.pdf != modern.pdf)
    }

    @Test("a store that fails is renderingFailed, and nothing is rendered")
    func storeFailure() async throws {
        let renderer = RecordingRenderer()

        await #expect(throws: ExportFailure.renderingFailed) {
            try await exporter(UnavailableStore(), renderer: renderer).export(cv(nil), language: try italian())
        }
        #expect(await renderer.rendered.isEmpty)
    }

    @Test("a store without the default design is renderingFailed, even for an unknown design")
    func noDefaultDesign() async throws {
        let renderer = RecordingRenderer()
        let look = try choice("gone", palette: nil, fonts: nil)

        await #expect(throws: ExportFailure.renderingFailed) {
            try await exporter(InMemoryDesignStore(), renderer: renderer).export(cv(look), language: try italian())
        }
        #expect(await renderer.rendered.isEmpty)
    }

    @Test("cancellation while the design is read passes through unchanged")
    func cancellationPassesThrough() async throws {
        let store = SpyDesignStore(installed: try Installed.designs(), cancelling: [.design])

        await #expect(throws: CancellationError.self) {
            try await exporter(store, renderer: FakePDFRenderer()).export(cv(nil), language: try italian())
        }
    }

    @Test("an export cancelled while the store waits for its lock is cancelled, whether the wait then reads or times out; nothing more is read or rendered", arguments: [false, true], [nil, "gone"])
    func cancelledDuringTheStoreWait(timesOut: Bool, design: String?) async throws {
        let store = HeldDesignStore(installed: try Installed.designs(), timesOut: timesOut)
        let renderer = RecordingRenderer()
        let language = try italian()
        let snapshot = cv(try design.map { try choice($0, palette: nil, fonts: nil) })

        let export = Task { try await exporter(store, renderer: renderer).export(snapshot, language: language) }
        try #require(await store.waitUntilEntered())
        export.cancel()
        await store.release()

        await #expect(throws: CancellationError.self) { try await export.value }
        #expect(await store.reads == 1)
        #expect(await renderer.rendered.isEmpty)
    }

    @Test("the export's own failures pass through: a CV without a name is notReady")
    func exportFailuresPassThrough() async throws {
        var unnamed = cv(nil)
        unnamed.setPersonalDetails(PersonalDetails(fullName: "   "))

        await #expect(throws: ExportFailure.notReady) {
            try await exporter(try await Installed.store(), renderer: FakePDFRenderer()).export(unnamed, language: try italian())
        }
    }
}
