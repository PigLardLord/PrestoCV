#if os(macOS)   // macOS only (R11)
import Testing
import Foundation
import AppKit
import PDFKit
import WebKit
import CVRendering
import CVRenderingMacOS
import CVRenderingWebKitSupport
import CVRenderingPDFKitInspector
import CVRenderingTestSupport
import CVRenderingNativeTestSupport

@MainActor
@Suite("#77 · the macOS renderer, checked with PDFKit", .serialized, .timeLimit(.minutes(3)))
struct MacPDFRendererTests {
    func renderer() async throws -> MacPDFRenderer { MacPDFRenderer(rules: try await SecureWebViewConfiguration.compileRules()) }

    @Test("passes the renderer contract: every field, the real page count, truncation and cancellation")
    func contract() async throws {
        let document = try ContractFixture.rendered()
        try await PDFRenderingContract.verify(try await renderer(), inspector: PDFKitInspector(), html: document.html, expectedText: document.textNodes)
    }

    @Test("pages have the page size, and a long document keeps its first pages and says how many it needed")
    func pages() async throws {
        let document = try ContractFixture.rendered()
        let long = document.html.replacingOccurrences(of: "</main>", with: String(repeating: "<p>Line of a long document.</p>", count: 300) + "</main>")
        let pdf = try await renderer().render(html: long, page: PageSetup(widthPoints: 595, heightPoints: 842, maxPages: 2))
        let read = try #require(PDFDocument(data: pdf.data))
        #expect(pdf.pageCount == 2 && read.pageCount == 2 && pdf.requiredPages > 2 && pdf.truncated)
        let bounds = try #require(read.page(at: 0)).bounds(for: .mediaBox)
        #expect(bounds.width == 595 && bounds.height == 842)
        #expect(read.page(at: 0)?.string?.contains("Ada <Lovelace>") == true)
    }

    @Test("every page keeps its top and bottom margins, the first one and the ones after it")
    func margins() async throws {
        let document = try ContractFixture.rendered()
        let long = document.html.replacingOccurrences(of: "</main>", with: String(repeating: "<p>Line of a long document.</p>", count: 150) + "</main>")
        let pdf = try await renderer().render(html: long, page: PageSetup(widthPoints: 595, heightPoints: 842, maxPages: 10))
        let read = try #require(PDFDocument(data: pdf.data))
        #expect(read.pageCount >= 2)
        for index in 0..<read.pageCount {
            let page = try #require(read.page(at: index))
            let text = try #require(page.selection(for: page.bounds(for: .mediaBox))).bounds(for: page)
            #expect(text.maxY <= 842 - 36 + 1 && text.minY >= 36 - 1, "page \(index + 1): text at \(text)")
        }
    }

    @Test("the inspector reads the page count and the text of every page, and refuses what is not a PDF")
    func inspector() async throws {
        let pdf = try await renderer().render(html: try ContractFixture.rendered().html, page: .a4)
        #expect(PDFKitInspector().pageCount(of: pdf.data) == pdf.pageCount)
        #expect(PDFKitInspector().text(of: pdf.data)?.contains("Mathematics") == true)
        #expect(PDFKitInspector().pageCount(of: Data("not a PDF".utf8)) == nil && PDFKitInspector().text(of: Data()) == nil)
    }

    @Test("a render cancelled while it works ends at once in a cancellation")
    func cancelledInFlight() async throws {
        let document = try ContractFixture.rendered()
        let long = document.html.replacingOccurrences(of: "</main>", with: String(repeating: "<p>Line of a long document.</p>", count: 30_000) + "</main>")
        let renderer = try await renderer()
        let existing = Set(NSApplication.shared.windows.map(ObjectIdentifier.init))
        let task = Task { try await renderer.render(html: long, page: PageSetup(widthPoints: 595, heightPoints: 842, maxPages: 10_000)) }
        #expect(await Self.renderWindowAppears(besides: existing), "the render did not start")
        let cancelled = ContinuousClock.now
        task.cancel()
        let result = await task.result
        #expect(throws: CancellationError.self) { _ = try result.get() }
        #expect(ContinuousClock.now - cancelled < Self.patience, "the render should end with the cancellation, not run on")
    }

    /// The bound on a wait for something that must happen: generous, since it costs time only when the code is broken.
    static let patience: Duration = .seconds(60)

    /// Whether a window holding a web view appears besides `existing`, within `patience`. A render makes its offscreen
    /// window just before it loads, and prints from it: while the window is there, the render is loading or printing.
    static func renderWindowAppears(besides existing: Set<ObjectIdentifier>) async -> Bool {
        let deadline = ContinuousClock.now + patience
        while ContinuousClock.now < deadline {
            if NSApplication.shared.windows.contains(where: { !existing.contains(ObjectIdentifier($0)) && $0.contentView is WKWebView }) {
                return true
            }
            do { try await Task.sleep(for: .milliseconds(10)) } catch { return false }
        }
        return false
    }

    @Test("a page setup with no page or no printable height is refused", arguments: [
        PageSetup(widthPoints: 595, heightPoints: 842, maxPages: 0), PageSetup(widthPoints: 595, heightPoints: 60, maxPages: 1),
    ])
    func invalidPageSetup(page: PageSetup) async throws {
        await #expect(throws: MacPDFRenderer.Failure.invalidPageSetup) { _ = try await renderer().render(html: "<p>x</p>", page: page) }
    }
}

/// #78 on macOS: the checks shared with the other platform, one line each, so a check cannot differ between them. They
/// are nested in the serialized suite above, so no other render runs while they do.
extension MacPDFRendererTests {
    @MainActor static func checks() async throws -> NativeRendererChecks<MacPDFRenderer> {
        NativeRendererChecks(renderer: MacPDFRenderer(rules: try await SecureWebViewConfiguration.compileRules()))
    }

    @MainActor
    @Suite("#78 · completeness on real PDFs")
    struct Completeness {
        @Test("a field the renderer drops is incomplete on a real PDF")
        func droppedField() async throws { try await MacPDFRendererTests.checks().droppedField() }

        @Test("flex and grid keep inline entries apart", arguments: SeparationDesign.allCases)
        func inlineEntries(design: SeparationDesign) async throws { try await MacPDFRendererTests.checks().inlineEntriesStayApart(design: design) }
    }

    @MainActor
    @Suite("#78 · R8 on the renderer")
    struct R8 {
        @Test("a script in the document does not run")
        func script() async throws { try await MacPDFRendererTests.checks().scriptDoesNotRun() }

        @Test("a remote image, stylesheet and font make no connection")
        func remoteResources() async throws { try await MacPDFRendererTests.checks().remoteResourcesMakeNoConnection() }

        @Test("a link and a meta refresh are not followed")
        func linkAndRefresh() async throws { try await MacPDFRendererTests.checks().linkAndRefreshAreNotFollowed() }

        @Test("the PDF still holds the document's text after those attempts")
        func keepsItsText() async throws { try await MacPDFRendererTests.checks().documentKeepsItsText() }
    }

    /// Recorded: macOS keeps one link annotation per href.
    @MainActor
    @Suite("#78 · link annotations")
    struct LinkAnnotations {
        @Test("the annotations match the builder's hrefs, or the platform keeps none, as recorded")
        func annotations() async throws { try await MacPDFRendererTests.checks().linkAnnotations(kept: true) }
    }

    @MainActor
    @Suite("#78 · the geometry of the real PDFs")
    struct Geometry {
        @Test("no violation for the fixture")
        func fixture() async throws { try await MacPDFRendererTests.checks().fixtureGeometry() }
    }

    @MainActor
    @Suite("#78 · the step budget")
    struct StepBudget {
        @Test("real documents use at most 10% of the budget")
        func budget() async throws { try await MacPDFRendererTests.checks().stepBudget() }
    }
}
#endif
