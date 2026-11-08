import Testing
import Foundation
import CVDocumentModel
import CVDesignCatalog
import CVRendering
import CVRenderingTestSupport

/// Renders like the fake renderer, records every HTML it was given, and can be told to lose content or to truncate for
/// the HTML of one font scheme.
actor RecordingRenderer: PDFRendering {
    enum Fault { case none, truncates(FontScheme), losesText(FontScheme) }
    private(set) var rendered: [String] = []
    let fault: Fault

    init(_ fault: Fault = .none) { self.fault = fault }

    func render(html: String, page: PageSetup) async throws -> RenderedPDF {
        rendered.append(html)
        switch fault {
        case .truncates(let scheme) where html.contains(scheme.customProperties):
            let pdf = try await FakePDFRenderer().render(html: html, page: page)
            return RenderedPDF(data: pdf.data, pageCount: pdf.pageCount, requiredPages: pdf.pageCount + 1)
        case .losesText(let scheme) where html.contains(scheme.customProperties):
            return try await FakePDFRenderer().render(html: html.replacingOccurrences(of: "Mathematics", with: ""), page: page)
        default:
            return try await FakePDFRenderer().render(html: html, page: page)
        }
    }
}

@Suite("the rendering gate proves a design under the palette and every font scheme it can be used with (#125)")
struct FixtureRenderingGateTests {
    private func gate(_ renderer: RecordingRenderer) throws -> FixtureRenderingGate {
        FixtureRenderingGate(renderer: renderer, inspector: MinimalPDFInspector(), fixture: fixture,
                             headings: try headingsCatalog.headings(for: "it"))
    }

    @Test("the design's own palette and default fonts are rendered first, then every other font scheme", arguments: FontScheme.allCases)
    func firstRenderIsTheDesigns(defaultFonts: FontScheme) async throws {
        let renderer = RecordingRenderer()
        let design = try DesignStoreContract.design(id: "clean", defaultPalette: .plum, defaultFonts: defaultFonts)
        try await gate(renderer).verify(design)
        let rendered = await renderer.rendered
        let first = try #require(rendered.first)
        #expect(first.contains(NamedPalette.plum.palette.customProperties + defaultFonts.customProperties))
        #expect(!first.contains(palette.customProperties))
    }

    @Test("a design is rendered once under each font scheme, always with its own palette")
    func oneRenderPerFontScheme() async throws {
        let renderer = RecordingRenderer()
        try await gate(renderer).verify(DesignStoreContract.design(id: "clean", defaultPalette: .plum, defaultFonts: .serif))
        let rendered = await renderer.rendered
        let expected = [FontScheme.serif, .system, .rounded].map { NamedPalette.plum.palette.customProperties + $0.customProperties }
        #expect(rendered.count == FontScheme.allCases.count)
        for (html, properties) in zip(rendered, expected) { #expect(html.contains(properties)) }
    }

    @Test("a design that truncates only under one font scheme does not pass", arguments: FontScheme.allCases)
    func truncatesUnderOneScheme(scheme: FontScheme) async throws {
        let design = try DesignStoreContract.design(id: "clean", defaultFonts: .system)
        await #expect(throws: FixtureRenderingGate.Rejection.truncated) { try await gate(RecordingRenderer(.truncates(scheme))).verify(design) }
    }

    @Test("a design that loses text only under one font scheme does not pass", arguments: FontScheme.allCases)
    func losesTextUnderOneScheme(scheme: FontScheme) async throws {
        let design = try DesignStoreContract.design(id: "clean", defaultFonts: .system)
        let error = await #expect(throws: FixtureRenderingGate.Rejection.self) { try await gate(RecordingRenderer(.losesText(scheme))).verify(design) }
        guard case .missing? = error else { Issue.record("expected missing text, got \(String(describing: error))"); return }
    }

    @Test("the gate stops at the first font scheme that fails")
    func stopsAtFirstFailure() async throws {
        let renderer = RecordingRenderer(.truncates(.serif))
        let design = try DesignStoreContract.design(id: "clean", defaultFonts: .serif)
        await #expect(throws: FixtureRenderingGate.Rejection.truncated) { try await gate(renderer).verify(design) }
        #expect(await renderer.rendered.count == 1)
    }

    @Test("a design that renders completely under every font scheme passes")
    func passes() async throws {
        try await gate(RecordingRenderer()).verify(DesignStoreContract.design(id: "clean", defaultPalette: .ocean, defaultFonts: .rounded))
    }
}
