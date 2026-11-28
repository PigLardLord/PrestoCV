import Testing
import Foundation
import Synchronization
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

/// A renderer whose prints each wait until the test lets that print go, and that keeps the most prints it ran at once
/// and the order they began in.
private actor GatedRenderer: PDFRendering {
    private(set) var running = 0, most = 0
    private(set) var begun: [String] = []
    private var held: [String: CheckedContinuation<Void, Never>] = [:]
    private var watchers: [(html: String, waiter: CheckedContinuation<Void, Never>)] = []

    func render(html: String, page: PageSetup) async throws -> RenderedPDF {
        running += 1
        most = max(most, running)
        begun.append(html)
        let told = watchers.filter { $0.html == html }
        watchers.removeAll { $0.html == html }
        for watcher in told { watcher.waiter.resume() }
        await withCheckedContinuation { held[html] = $0 }
        running -= 1
        return RenderedPDF(data: Data(html.utf8), pageCount: 1, requiredPages: 1)
    }

    /// Returns once the print of `html` has begun.
    func waitUntilBegun(_ html: String) async {
        guard !begun.contains(html) else { return }
        await withCheckedContinuation { watchers.append((html, $0)) }
    }

    /// Lets the print of `html` end; it must have begun.
    func release(_ html: String) { held.removeValue(forKey: html)?.resume() }
}

/// A renderer that counts its prints and prints at once, with no actor: a print stays on the executor of its task.
private final class UnheldRenderer: PDFRendering {
    private let count = Mutex(0)
    var prints: Int { count.withLock { $0 } }

    @concurrent func render(html: String, page: PageSetup) async throws -> RenderedPDF {
        count.withLock { $0 += 1 }
        return RenderedPDF(data: Data(html.utf8), pageCount: 1, requiredPages: 1)
    }
}

/// A task executor that runs nothing by itself: the jobs of a task that prefers it wait until the test drains them, so
/// a task resumed meanwhile stays where it was until then.
private final class DrainedExecutor: TaskExecutor {
    private let jobs = Mutex<[UnownedJob]>([])

    func enqueue(_ job: consuming ExecutorJob) {
        let job = UnownedJob(job)
        jobs.withLock { $0.append(job) }
    }

    /// Runs the jobs that wait, and those they enqueue, on a thread of its own, and returns once none is left: the
    /// tasks that prefer the executor then wait on something else, or ended.
    func drain() async {
        await withCheckedContinuation { (drained: CheckedContinuation<Void, Never>) in
            Thread {
                while let job = self.jobs.withLock({ $0.isEmpty ? nil : $0.removeFirst() }) {
                    job.runSynchronously(on: self.asUnownedTaskExecutor())
                }
                drained.resume()
            }.start()
        }
    }
}

/// Lets the other tasks run as far as they can go, with no clock: a print that would begin begins meanwhile.
private func settle() async { for _ in 0..<200 { await Task.yield() } }

@Suite("The export prints before the check of the designs (#566)", .timeLimit(.minutes(1)))
struct ExportFirstTests {
    @Test("a print of the check waits while an export prints, then goes on", arguments: [false, true])
    func checkWaitsForTheExport(exportFails: Bool) async throws {
        let turns = ExportFirst(prints: 2)
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
        let turns = ExportFirst(prints: 2)
        let checkRenderer = CountingRenderer()

        _ = try await turns.checking(checkRenderer).render(html: "check", page: .a4)

        #expect(await checkRenderer.prints == 1)
    }

    @Test("an export prints at once while the check prints")
    func exportDoesNotWait() async throws {
        let turns = ExportFirst(prints: 2)
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
        let turns = ExportFirst(prints: 2)
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

    @Test("a print of the check and two exports at once never run more than two prints, and both exports print")
    func heldCheckAndTwoExports() async throws {
        let turns = ExportFirst(prints: 2)
        let renderer = GatedRenderer()
        let exporting = turns.exporting(renderer), checking = turns.checking(renderer)

        let check = Task { try await checking.render(html: "check", page: .a4) }
        await renderer.waitUntilBegun("check")
        let first = Task { try await exporting.render(html: "first", page: .a4) }
        let second = Task { try await exporting.render(html: "second", page: .a4) }
        await settle()
        let running = await renderer.running
        #expect(running == 2)

        await renderer.release("check")
        _ = try await check.value
        for html in ["first", "second"] {
            await renderer.waitUntilBegun(html)
            await renderer.release(html)
        }
        #expect(try await first.value.data == Data("first".utf8))
        #expect(try await second.value.data == Data("second".utf8))
        let most = await renderer.most
        #expect(most == 2)
    }

    /// A print of the check takes its place when it is let in, under the same lock that lets the exports in: an export
    /// that comes after it finds that place taken, so it prints within what the renderer can print at once, and it goes
    /// before every print of the check still waiting.
    @Test("an export that comes once a print of the check is let in waits for a place, then goes before the next check")
    func exportAfterAdmittedCheck() async throws {
        let turns = ExportFirst(prints: 1)
        let renderer = GatedRenderer()
        let exporting = turns.exporting(renderer), checking = turns.checking(renderer)

        let firstCheck = Task { try await checking.render(html: "first check", page: .a4) }
        await renderer.waitUntilBegun("first check")
        let export = Task { try await exporting.render(html: "export", page: .a4) }
        await settle()
        let secondCheck = Task { try await checking.render(html: "second check", page: .a4) }
        await settle()
        let begun = await renderer.begun
        #expect(begun == ["first check"])

        for html in ["first check", "export", "second check"] {
            await renderer.waitUntilBegun(html)
            await renderer.release(html)
        }
        _ = try await firstCheck.value
        _ = try await export.value
        _ = try await secondCheck.value
        let begunThen = await renderer.begun
        #expect(begunThen == ["first check", "export", "second check"])
        let most = await renderer.most
        #expect(most == 1)
    }

    @Test("a print of the check leaves a place for an export: a second print of the check waits while the first prints")
    func checksLeaveAPlace() async throws {
        let turns = ExportFirst(prints: 2)
        let renderer = GatedRenderer()
        let exporting = turns.exporting(renderer), checking = turns.checking(renderer)

        let firstCheck = Task { try await checking.render(html: "first check", page: .a4) }
        await renderer.waitUntilBegun("first check")
        let secondCheck = Task { try await checking.render(html: "second check", page: .a4) }
        await settle()
        let export = Task { try await exporting.render(html: "export", page: .a4) }
        await renderer.waitUntilBegun("export")
        let begun = await renderer.begun
        #expect(begun == ["first check", "export"])

        await renderer.release("first check")
        _ = try await firstCheck.value
        await settle()
        let begunThen = await renderer.begun
        #expect(begunThen == ["first check", "export"])
        await renderer.release("export")
        _ = try await export.value
        await renderer.waitUntilBegun("second check")
        await renderer.release("second check")
        _ = try await secondCheck.value
        let most = await renderer.most
        #expect(most == 2)
    }

    @Test("an export cancelled while it waits for a place is cancelled, never begins, and gives its place back")
    func exportCancelledWhileWaiting() async throws {
        let turns = ExportFirst(prints: 1)
        let renderer = GatedRenderer()
        let exporting = turns.exporting(renderer), checking = turns.checking(renderer)

        let first = Task { try await exporting.render(html: "first", page: .a4) }
        await renderer.waitUntilBegun("first")
        let cancelled = Task { try await exporting.render(html: "cancelled", page: .a4) }
        await settle()
        let begun = await renderer.begun
        #expect(begun == ["first"])
        cancelled.cancel()
        await renderer.release("cancelled")                             // nothing to let go, unless it began
        await #expect(throws: CancellationError.self) { try await cancelled.value }

        let check = Task { try await checking.render(html: "check", page: .a4) }
        await renderer.release("first")
        _ = try await first.value
        await renderer.waitUntilBegun("check")
        await renderer.release("check")
        _ = try await check.value
        let begunThen = await renderer.begun
        #expect(begunThen == ["first", "check"])
    }

    /// The print before it lets a waiting print in when it ends, under the lock, and a cancel that comes then finds
    /// nothing to take back. The waiting print's task prefers an executor the test drains, so it stays let in and not yet
    /// resumed while the test cancels it: the cancel comes between the two on every run.
    @Test("a print cancelled once it is let in, before its render begins, never begins and gives its place back",
          arguments: [true, false])
    func cancelledOnceLetIn(export: Bool) async throws {
        let turns = ExportFirst(prints: 1)
        let firstRenderer = HeldRenderer(fails: false), renderer = UnheldRenderer(), executor = DrainedExecutor()
        let printing = export ? turns.exporting(renderer) : turns.checking(renderer)

        let first = Task { try await turns.exporting(firstRenderer).render(html: "first", page: .a4) }
        await firstRenderer.waitUntilEntered()
        let cancelled = Task(executorPreference: executor) { try await printing.render(html: "cancelled", page: .a4) }
        await executor.drain()                                          // it waits for the place the first print holds
        await firstRenderer.release()
        _ = try await first.value                                       // its end let the waiting print in
        cancelled.cancel()
        await executor.drain()

        await #expect(throws: CancellationError.self) { try await cancelled.value }
        #expect(renderer.prints == 0)
        _ = try await turns.checking(renderer).render(html: "after", page: .a4)
        #expect(renderer.prints == 1, "the place is free again")
    }
}
