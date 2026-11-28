import Testing
import Foundation
import PrestoCVIntegration
import CVRendering

/// A renderer whose prints wait until the test lets them go, and that counts the prints it began.
private actor HeldRenderer: PDFRendering {
    struct Failed: Error {}
    private let fails: Bool
    private(set) var began = 0
    private let entered: AsyncStream<Void>, enteredSignal: AsyncStream<Void>.Continuation
    private let released: AsyncStream<Void>, releaseSignal: AsyncStream<Void>.Continuation

    init(fails: Bool) {
        self.fails = fails
        (entered, enteredSignal) = AsyncStream.makeStream(of: Void.self)
        (released, releaseSignal) = AsyncStream.makeStream(of: Void.self)
    }

    /// Waits until a print has begun.
    func waitUntilEntered() async { for await _ in entered { return } }

    /// Lets one held print go on.
    func release() { releaseSignal.yield() }

    func render(html: String, page: PageSetup) async throws -> RenderedPDF {
        began += 1
        enteredSignal.yield()
        for await _ in released { break }
        if fails { throw Failed() }
        return RenderedPDF(data: Data(html.utf8), pageCount: 1, requiredPages: 1)
    }
}

/// A renderer that counts its prints and prints at once.
private actor CountingRenderer: PDFRendering {
    private(set) var prints = 0
    func render(html: String, page: PageSetup) async throws -> RenderedPDF {
        prints += 1
        return RenderedPDF(data: Data(html.utf8), pageCount: 1, requiredPages: 1)
    }
}

@Suite("The export prints before the check of the designs (#566)", .timeLimit(.minutes(1)))
struct ExportFirstTests {
    @Test("a print of the check waits while an export prints, then goes on", arguments: [false, true])
    func checkWaitsForTheExport(exportFails: Bool) async throws {
        let turns = ExportFirst()
        let exportRenderer = HeldRenderer(fails: exportFails), checkRenderer = CountingRenderer()
        let exporting = turns.exporting(exportRenderer), checking = turns.checking(checkRenderer)

        let export = Task { try await exporting.render(html: "export", page: .a4) }
        await exportRenderer.waitUntilEntered()
        let check = Task { try await checking.render(html: "check", page: .a4) }
        for _ in 0..<50 { await Task.yield() }
        #expect(await checkRenderer.prints == 0)

        await exportRenderer.release()
        _ = await export.result
        _ = try await check.value
        #expect(await checkRenderer.prints == 1)
    }

    @Test("a print of the check goes on at once when no export prints")
    func checkAlone() async throws {
        let turns = ExportFirst()
        let checkRenderer = CountingRenderer()

        _ = try await turns.checking(checkRenderer).render(html: "check", page: .a4)

        #expect(await checkRenderer.prints == 1)
    }

    @Test("an export prints at once while the check prints")
    func exportDoesNotWait() async throws {
        let turns = ExportFirst()
        let checkRenderer = HeldRenderer(fails: false), exportRenderer = CountingRenderer()

        let check = Task { try await turns.checking(checkRenderer).render(html: "check", page: .a4) }
        await checkRenderer.waitUntilEntered()
        _ = try await turns.exporting(exportRenderer).render(html: "export", page: .a4)
        #expect(await exportRenderer.prints == 1)

        await checkRenderer.release()
        _ = try await check.value
    }

    @Test("a print of the check cancelled while it waits for its turn is cancelled and never begins")
    func cancelledWhileWaiting() async throws {
        let turns = ExportFirst()
        let exportRenderer = HeldRenderer(fails: false), checkRenderer = CountingRenderer()

        let export = Task { try await turns.exporting(exportRenderer).render(html: "export", page: .a4) }
        await exportRenderer.waitUntilEntered()
        let check = Task { try await turns.checking(checkRenderer).render(html: "check", page: .a4) }
        for _ in 0..<50 { await Task.yield() }
        check.cancel()

        await #expect(throws: CancellationError.self) { try await check.value }
        #expect(await checkRenderer.prints == 0)
        await exportRenderer.release()
        _ = try await export.value
    }
}
