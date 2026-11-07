#if os(iOS)   // iOS only (R11)
import Testing
import Foundation
import UIKit
import PDFKit
import WebKit
import CVRendering
@testable import CVRenderingIOS
import CVRenderingWebKitSupport
import CVRenderingPDFKitInspector
import CVRenderingTestSupport

@MainActor
@Suite("#76 · the iOS renderer, checked with PDFKit", .serialized, .timeLimit(.minutes(3)))
struct IOSPDFRendererTests {
    func renderer() async throws -> IOSPDFRenderer { IOSPDFRenderer(rules: try await SecureWebViewConfiguration.compileRules()) }

    @Test("passes the renderer contract: every field, the real page count, truncation and cancellation")
    func contract() async throws {
        let document = try ContractFixture.rendered()
        try await PDFRenderingContract.verify(try await renderer(), inspector: PDFKitInspector(), html: document.html, expectedText: document.textNodes)
    }

    @Test("pages have the page size and read from the top, and a long document keeps its first pages and says how many it needed")
    func pages() async throws {
        let document = try ContractFixture.rendered()
        let long = document.html.replacingOccurrences(of: "</main>", with: String(repeating: "<p>Line of a long document.</p>", count: 300) + "</main>")
        let pdf = try await renderer().render(html: long, page: PageSetup(widthPoints: 595, heightPoints: 842, maxPages: 2))
        let read = try #require(PDFDocument(data: pdf.data))
        #expect(pdf.pageCount == 2 && read.pageCount == 2 && pdf.requiredPages > 2 && pdf.truncated)
        let first = try #require(read.page(at: 0))
        let bounds = first.bounds(for: .mediaBox)
        #expect(bounds.width == 595 && bounds.height == 842)
        #expect(first.string?.contains("Ada <Lovelace>") == true)
        // The name opens the document, so it sits in the upper half of the first page (PDF space grows upwards):
        // a context drawn upside down puts it at the bottom.
        let name = try #require(read.findString("Lovelace", withOptions: []).first { $0.pages.first == first })
        #expect(name.bounds(for: first).minY > 421, "the name is at \(name.bounds(for: first))")
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
        #expect(IOSPrintEngine.rendersInFlight == 0)
        let task = Task { try await renderer.render(html: long, page: PageSetup(widthPoints: 595, heightPoints: 842, maxPages: 10_000)) }
        #expect(await Self.renderStarts(), "the render did not start")
        let cancelled = ContinuousClock.now
        task.cancel()
        let result = await task.result
        #expect(throws: CancellationError.self) { _ = try result.get() }
        #expect(ContinuousClock.now - cancelled < Self.patience, "the render should end with the cancellation, not run on")
        #expect(IOSPrintEngine.rendersInFlight == 0)
    }

    /// The bound on a wait for something that must happen: generous, since it costs time only when the code is broken.
    static let patience: Duration = .seconds(60)

    /// Whether a render starts within `patience`. A render counts itself from the start of its load to its end.
    static func renderStarts() async -> Bool {
        let deadline = ContinuousClock.now + patience
        while ContinuousClock.now < deadline {
            if IOSPrintEngine.rendersInFlight > 0 { return true }
            do { try await Task.sleep(for: .milliseconds(10)) } catch { return false }
        }
        return false
    }

    /// The steps of a render that run on the main actor without a break: laying the pages out, then drawing each page.
    /// A cancellation from another task lands during one of them and is seen at the next point the engine asks at.
    nonisolated static let synchronousSteps: [IOSPrintEngine.CancellationPoint] = [.afterLoad, .beforePage(0), .beforePage(1)]

    @Test("a cancellation that arrives while the pages are laid out or drawn, the last page included, ends in a cancellation, never in a PDF",
          arguments: synchronousSteps)
    func cancelledDuringASynchronousStep(arrivesAfter point: IOSPrintEngine.CancellationPoint) async throws {
        let probe = CancellationArriving(after: point)
        let renderer = IOSPDFRenderer(engine: try await Self.engine(asking: probe))
        await #expect(throws: CancellationError.self) { _ = try await renderer.render(html: try Self.twoPages(), page: Self.twoPageLimit) }
        #expect(probe.asked.contains(point), "the render never reached \(point), so the cancellation did not land in its step")
    }

    @Test("a render whose task is never cancelled draws its pages through the same engine")
    func notCancelled() async throws {
        let probe = CancellationArriving(after: nil)
        let pdf = try await IOSPDFRenderer(engine: try await Self.engine(asking: probe)).render(html: try Self.twoPages(), page: Self.twoPageLimit)
        #expect(pdf.pageCount == 2 && PDFDocument(data: pdf.data)?.pageCount == 2)
        #expect(Self.synchronousSteps.allSatisfy { probe.asked.contains($0) }, "asked at \(probe.asked)")
    }

    static let twoPageLimit = PageSetup(widthPoints: 595, heightPoints: 842, maxPages: 2)

    static func twoPages() throws -> String {
        try ContractFixture.rendered().html.replacingOccurrences(
            of: "</main>", with: String(repeating: "<p>Line of a long document.</p>", count: 300) + "</main>")
    }

    static func engine(asking probe: CancellationArriving) async throws -> IOSPrintEngine {
        IOSPrintEngine(rules: try await SecureWebViewConfiguration.compileRules(), loadTimeout: .seconds(30),
                       readinessTimeout: .seconds(10), isCancelled: probe.isCancelled)
    }

    @Test("a page setup with no page or no printable height is refused", arguments: [
        PageSetup(widthPoints: 595, heightPoints: 842, maxPages: 0), PageSetup(widthPoints: 595, heightPoints: 60, maxPages: 1),
    ])
    func invalidPageSetup(page: PageSetup) async throws {
        await #expect(throws: IOSPDFRenderer.Failure.invalidPageSetup) { _ = try await renderer().render(html: "<p>x</p>", page: page) }
    }
}

/// A task cancelled while the step after `after` runs: the engine sees "not cancelled" at `after` and at every point
/// before it, and "cancelled" at every point after it, as `Task.isCancelled` does once a task is cancelled.
@MainActor
final class CancellationArriving {
    let after: IOSPrintEngine.CancellationPoint?
    private(set) var asked: [IOSPrintEngine.CancellationPoint] = []
    private var cancelled = false

    init(after: IOSPrintEngine.CancellationPoint?) { self.after = after }

    func isCancelled(_ point: IOSPrintEngine.CancellationPoint) -> Bool {
        asked.append(point)
        defer { if point == after { cancelled = true } }
        return cancelled
    }
}
#endif
