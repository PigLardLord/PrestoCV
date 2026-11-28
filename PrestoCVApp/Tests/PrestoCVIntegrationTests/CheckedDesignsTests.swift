import Testing
import Synchronization
import PrestoCVWorkflowPorts
import PrestoCVIntegration
import CVDesignCatalog
import CVRenderingTestSupport

private func design(_ id: String) throws -> ValidatedDesign { try DesignStoreContract.design(id: id) }

private func ids(_ snapshot: CheckedDesignsSnapshot?) -> [String]? { snapshot?.designs.map(\.manifest.id) }

@Suite("The designs a PDF can be made with, while the check runs (#566)", .timeLimit(.minutes(1)))
struct CheckedDesignsTests {
    @Test("the designs the store holds are offered at once, while the check runs")
    func heldAtOnce() async throws {
        let checking = DrivenChecking(holding: [try design("minimal")])
        let designs = CheckedDesigns(checking: checking, defaultDesign: "professional")
        designs.start()
        let now = await first(designs) { !$0.designs.isEmpty }
        #expect(ids(now) == ["minimal"])
        #expect(now?.status == .checking)
    }

    @Test("each design joins once it passes; the default design comes first, the others by identifier")
    func joinInOrder() async throws {
        let checking = DrivenChecking(holding: [])
        let designs = CheckedDesigns(checking: checking, defaultDesign: "professional")
        designs.start()
        checking.tell("professional", try design("professional"))
        #expect(ids(await first(designs) { $0.designs.count == 1 }) == ["professional"])
        checking.tell("modern", try design("modern"))
        checking.tell("minimal", try design("minimal"))
        checking.endCheck()
        let over = await first(designs) { $0.status != .checking }
        #expect(ids(over) == ["professional", "minimal", "modern"])
        #expect(over?.status == .ready)
        #expect(ids(designs.current) == ["professional", "minimal", "modern"])
    }

    @Test("a design that does not pass is never offered")
    func refusedNeverOffered() async throws {
        let checking = DrivenChecking(holding: [])
        let designs = CheckedDesigns(checking: checking, defaultDesign: "professional")
        designs.start()
        checking.tell("professional", try design("professional"))
        checking.tell("modern", nil)
        checking.endCheck()
        let over = await first(designs) { $0.status != .checking }
        #expect(ids(over) == ["professional"])
        #expect(over?.status == .ready)
    }

    @Test("a held design the store can no longer give leaves the designs")
    func unreadableLeaves() async throws {
        let checking = DrivenChecking(holding: [try design("professional"), try design("modern")])
        let designs = CheckedDesigns(checking: checking, defaultDesign: "professional")
        designs.start()
        checking.tell("modern", nil)
        checking.endCheck()
        #expect(ids(await first(designs) { $0.status != .checking }) == ["professional"])
    }

    @Test("a default design that does not pass makes the designs unavailable; the others are still offered")
    func refusedDefault() async throws {
        let checking = DrivenChecking(holding: [])
        let designs = CheckedDesigns(checking: checking, defaultDesign: "professional")
        designs.start()
        checking.tell("professional", nil)
        checking.tell("minimal", try design("minimal"))
        checking.endCheck()
        let over = await first(designs) { $0.status != .checking }
        #expect(over?.status == .unavailable)
        #expect(ids(over) == ["minimal"])
    }

    @Test("the check runs once, however often it is started")
    func startsOnce() async throws {
        let checking = DrivenChecking(holding: [])
        let designs = CheckedDesigns(checking: checking, defaultDesign: "professional")
        designs.start()
        designs.start()
        checking.tell("professional", try design("professional"))
        checking.endCheck()
        _ = await first(designs) { $0.status != .checking }
        #expect(checking.checks == 1)
    }

    @Test("a retry checks again only when the designs are unavailable, and can make them ready")
    func retry() async throws {
        let checking = DrivenChecking(holding: [])
        let designs = CheckedDesigns(checking: checking, defaultDesign: "professional")
        designs.start()
        designs.retry()                                                 // the check runs: nothing to retry
        checking.tell("professional", nil)
        checking.endCheck()
        #expect(await first(designs) { $0.status != .checking }?.status == .unavailable)
        #expect(checking.checks == 1)

        designs.retry()
        #expect(designs.current.status == .checking)
        checking.tell("professional", try design("professional"))
        checking.endCheck()
        let over = await first(designs) { $0.status != .checking }
        #expect(over?.status == .ready)
        #expect(ids(over) == ["professional"])
        #expect(checking.checks == 2)

        designs.retry()                                                 // ready: nothing to retry
        #expect(designs.current.status == .ready)
        #expect(checking.checks == 2)
    }

    @Test("a retry once the default design did not pass, while the others are still checked, checks again when that check ends")
    func retryWhileTheCheckRuns() async throws {
        let checking = DrivenChecking(holding: [])
        let designs = CheckedDesigns(checking: checking, defaultDesign: "professional")
        designs.start()
        checking.tell("professional", nil)
        try await designs.verdict(on: "professional")                   // the default did not pass; the check still runs

        designs.retry()
        designs.retry()                                                 // already asked: one more check, not two
        checking.endCheck()
        checking.tell("professional", try design("professional"))
        checking.endCheck()
        let over = await first(designs) { $0.status != .checking }

        #expect(over?.status == .ready, "the check that ran on is not the end: the default design is checked again")
        #expect(ids(over) == ["professional"])
        #expect(checking.checks == 2)
    }

    @Test("a verdict waits for its design, not for the whole check")
    func verdictWaitsForItsDesign() async throws {
        let checking = DrivenChecking(holding: [])
        let designs = CheckedDesigns(checking: checking, defaultDesign: "professional")
        designs.start()
        let returned = Mutex(false)
        let wait = Task {
            try await designs.verdict(on: "modern")
            returned.withLock { $0 = true }
        }
        checking.tell("professional", try design("professional"))
        _ = await first(designs) { $0.designs.count == 1 }
        for _ in 0..<50 { await Task.yield() }
        #expect(returned.withLock { $0 } == false)
        checking.tell("modern", try design("modern"))
        try await wait.value
        #expect(returned.withLock { $0 })
        #expect(designs.current.status == .checking)
    }

    @Test("a verdict on a design the check never names comes when the check is over")
    func verdictAtTheEnd() async throws {
        let checking = DrivenChecking(holding: [])
        let designs = CheckedDesigns(checking: checking, defaultDesign: "professional")
        designs.start()
        let wait = Task { try await designs.verdict(on: "gone") }
        checking.tell("professional", try design("professional"))
        _ = await first(designs) { $0.designs.count == 1 }
        for _ in 0..<50 { await Task.yield() }
        #expect(designs.current.status == .checking)
        checking.endCheck()
        #expect(try await wait.value == false, "a design the check never names did not pass")
        #expect(designs.current.status == .ready)
    }

    @Test("a cancelled wait for a verdict is a CancellationError")
    func cancelledVerdict() async throws {
        let checking = DrivenChecking(holding: [])
        let designs = CheckedDesigns(checking: checking, defaultDesign: "professional")
        designs.start()
        let wait = Task { try await designs.verdict(on: "modern") }
        wait.cancel()
        await #expect(throws: CancellationError.self) { try await wait.value }
    }

    @Test("a wait cancelled while the check is held is a CancellationError at once, and no verdict is published")
    func cancelledWhileTheCheckIsHeld() async throws {
        let checking = DrivenChecking(holding: [])
        let designs = CheckedDesigns(checking: checking, defaultDesign: "professional")
        designs.start()
        checking.tell("professional", try design("professional"))
        _ = await first(designs) { $0.designs.count == 1 }
        let wait = Task { try await designs.verdict(on: "modern") }
        for _ in 0..<50 { await Task.yield() }
        wait.cancel()

        await #expect(throws: CancellationError.self) { try await wait.value }
        #expect(ids(designs.current) == ["professional"])
        #expect(designs.current.status == .checking)
    }

    @Test("a cancelled task's wait is a CancellationError even when its design has its verdict")
    func cancelledWithItsVerdict() async throws {
        let checking = DrivenChecking(holding: [try design("professional")])
        let designs = CheckedDesigns(checking: checking, defaultDesign: "professional")
        designs.start()
        _ = await first(designs) { $0.designs.count == 1 }
        let (never, keep) = AsyncStream.makeStream(of: Void.self)
        let wait = Task {
            for await _ in never {}                                     // ends when the task is cancelled
            try await designs.verdict(on: "professional")
        }
        wait.cancel()

        await #expect(throws: CancellationError.self) { try await wait.value }
        keep.finish()
    }
}

@Suite("The look options follow the checked designs (#566)", .timeLimit(.minutes(1)))
struct CatalogLookOptionsCheckTests {
    @Test("the options say checking while the check runs, then ready, and gain each design that joins")
    func optionsFollowTheCheck() async throws {
        let checking = DrivenChecking(holding: [])
        let designs = CheckedDesigns(checking: checking, defaultDesign: "professional")
        let options = CatalogLookOptions(designs: designs)
        #expect(options.options().status == .checking && options.options().designs.isEmpty)
        designs.start()
        checking.tell("professional", try design("professional"))
        checking.tell("modern", try design("modern"))
        checking.endCheck()
        var seen: [LookOptions] = []
        for await now in options.changes() {
            seen.append(now)
            if now.status != .checking { break }
        }
        #expect(seen.last?.designs.map(\.id) == ["professional", "modern"])
        #expect(seen.last?.status == .ready)
        #expect(seen.last?.defaultPalette == NamedPalette.ink.rawValue)
        #expect(seen.dropLast().allSatisfy { $0.status == .checking })
        #expect(options.options().designs.map(\.id) == ["professional", "modern"])
    }

    @Test("a retry of the options checks the designs again when they are unavailable")
    func retryThroughTheOptions() async throws {
        let checking = DrivenChecking(holding: [])
        let designs = CheckedDesigns(checking: checking, defaultDesign: "professional")
        let options = CatalogLookOptions(designs: designs)
        designs.start()
        checking.tell("professional", nil)
        checking.endCheck()
        #expect(await first(designs) { $0.status != .checking }?.status == .unavailable)
        #expect(options.options().status == .unavailable)
        options.retry()
        #expect(options.options().status == .checking)
    }
}
