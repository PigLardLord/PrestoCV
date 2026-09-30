#if os(iOS)   // iOS only (R11)
import Testing
import Foundation
import PDFKit
import CVRendering
import CVRenderingIOS
import CVRenderingWebKitSupport
import CVRenderingPDFKitInspector
import CVRenderingTestSupport

/// Page setups no renderer can print on: no page, no printable height, a negative margin or dimension, or a value that
/// is not finite.
let invalidPageSetups: [PageSetup] = {
    var setups: [PageSetup] = []
    setups.append(PageSetup(widthPoints: 595, heightPoints: 842, maxPages: 0))
    setups.append(PageSetup(widthPoints: 595, heightPoints: 60, maxPages: 1))
    setups.append(PageSetup(widthPoints: 595, heightPoints: 842, maxPages: 1, verticalMarginPoints: -36))
    setups.append(PageSetup(widthPoints: 595, heightPoints: -1, maxPages: 1, verticalMarginPoints: -36))
    setups.append(PageSetup(widthPoints: -595, heightPoints: 842, maxPages: 1))
    setups.append(PageSetup(widthPoints: .infinity, heightPoints: 842, maxPages: 1))
    setups.append(PageSetup(widthPoints: 595, heightPoints: .nan, maxPages: 1))
    setups.append(PageSetup(widthPoints: 595, heightPoints: 842, maxPages: 1, verticalMarginPoints: .infinity))
    setups.append(PageSetup(widthPoints: 100, heightPoints: 842, maxPages: 1))                              // too narrow
    setups.append(PageSetup(widthPoints: 595, heightPoints: 842, maxPages: 1, verticalMarginPoints: 360))   // printable height 122
    return setups
}()

@MainActor
@Suite("#76 · the iOS renderer, checked with PDFKit", .serialized, .timeLimit(.minutes(3)))
struct IOSPDFRendererTests {
    func renderer() async throws -> IOSPDFRenderer { IOSPDFRenderer(rules: try await SecureWebViewConfiguration.compileRules()) }

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

    @Test("a render cancelled while it works ends at once in a cancellation")
    func cancelledInFlight() async throws {
        let document = try ContractFixture.rendered()
        let long = document.html.replacingOccurrences(of: "</main>", with: String(repeating: "<p>Line of a long document.</p>", count: 30_000) + "</main>")
        let renderer = try await renderer()
        let start = ContinuousClock.now
        let task = Task { try await renderer.render(html: long, page: PageSetup(widthPoints: 595, heightPoints: 842, maxPages: 10_000)) }
        try await Task.sleep(for: .milliseconds(20))   // the render has started: it is loading
        task.cancel()
        let result = await task.result
        #expect(throws: CancellationError.self) { _ = try result.get() }
        #expect(ContinuousClock.now - start < .seconds(10))
    }

    @Test("a page setup that cannot be printed on is refused before it reaches the platform", arguments: invalidPageSetups)
    func invalidPageSetup(page: PageSetup) async throws {
        await #expect(throws: IOSPDFRenderer.Failure.invalidPageSetup) { _ = try await renderer().render(html: "<p>x</p>", page: page) }
    }

    @Test("a document longer than the paginated-page limit is refused before any page is drawn")
    func tooLong() async throws {
        let document = try ContractFixture.rendered()
        let long = document.html.replacingOccurrences(of: "</main>", with: String(repeating: "<p>Line of a long document.</p>", count: 8_000) + "</main>")
        let error = await #expect(throws: IOSPDFRenderer.Failure.self) {
            _ = try await renderer().render(html: long, page: PageSetup(widthPoints: 595, heightPoints: 842, maxPages: 1))
        }
        guard case .documentTooLong(let pages)? = error else { Issue.record("\(String(describing: error))"); return }
        #expect(pages > IOSPDFRenderer.maxPaginatedPages)
    }

    @Test("HTML larger than the renderer paginates is refused before pagination")
    func tooLarge() async throws {
        let html = "<p>" + String(repeating: "x", count: IOSPDFRenderer.maxHTMLBytes) + "</p>"
        await #expect(throws: IOSPDFRenderer.Failure.documentTooLarge) { _ = try await renderer().render(html: html, page: .a4) }
    }
}
#endif
