import Testing
import PrestoCVDomain
@testable import PrestoCVPresentation

/// A value published after an await from an intent that is no longer the latest must not replace what a newer intent
/// published. Each test suspends a port, makes the second intent, releases the first and asserts.
@MainActor
@Suite("Look picker: overlapping intents")
struct LookOverlapTests {

    private let classicForest = DesignChoice(design: "classic", palette: "forest", fonts: "serif")

    @Test("a choice made while the look is being written stays pending, shown and applicable")
    func choiceDuringApplyStays() async throws {
        let world = Browsing()
        let cv = try await world.stored(title: "Backend", design: classicForest)
        let look = world.look(of: cv)
        await look.load()
        look.choose(palette: "ocean")
        await world.editing.gate.close()

        let applying = Task { await look.apply() }
        await waitUntil("the write to start") { await world.editing.gate.waiting == 1 }
        look.choose(fonts: "sans")
        await world.editing.gate.open()
        await applying.value

        #expect(look.shown == EditorLook(design: "classic", palette: "ocean", fonts: "sans"))
        #expect(look.chosen == [.fonts])
        #expect(look.status == .ready)
        #expect(try await world.editing.inStore(cv.id).design == DesignChoice(design: "classic", palette: "ocean", fonts: "serif"))

        await look.apply()

        #expect(try await world.editing.inStore(cv.id).design == DesignChoice(design: "classic", palette: "ocean", fonts: "sans"))
        #expect(look.chosen.isEmpty)
        #expect(look.status == .applied)
    }

    @Test("a write that fails keeps what was submitted and what was chosen after it")
    func failedApplyKeepsEveryChoice() async throws {
        let world = Browsing()
        let cv = try await world.stored(title: "Backend", design: classicForest)
        let look = world.look(of: cv)
        await look.load()
        look.choose(palette: "ocean")
        await world.editing.gate.close()

        let applying = Task { await look.apply() }
        await waitUntil("the write to start") { await world.editing.gate.waiting == 1 }
        look.choose(fonts: "sans")
        try await world.editing.otherWindowSaves(cv, fullName: "Someone Else")
        await world.editing.gate.open()
        await applying.value

        #expect(look.status == .conflict)
        #expect(look.chosen == [.palette, .fonts])
        #expect(look.shown == EditorLook(design: "classic", palette: "ocean", fonts: "sans"))

        await look.load()
        await look.apply()

        #expect(try await world.editing.inStore(cv.id).design == DesignChoice(design: "classic", palette: "ocean", fonts: "sans"))
        #expect(look.status == .applied)
    }

    @Test("a design chosen while the CV is read stays chosen when the read returns")
    func choiceDuringLoadStays() async throws {
        let world = Browsing()
        let cv = try await world.stored(title: "Backend", design: classicForest)
        let look = world.look(of: cv)
        await world.editing.loadGate.close()

        let loading = Task { await look.load() }
        await waitUntil("the read to start") { await world.editing.loadGate.waiting == 1 }
        look.choose(design: "modern")
        await world.editing.loadGate.open()
        await loading.value

        #expect(look.shown == EditorLook(design: "modern", palette: "forest", fonts: "serif"))
        #expect(look.chosen == [.design])
        #expect(look.status == .ready)
    }

    @Test("a read that fails while a change is written does not let a second apply write it again")
    func failedReadDuringApplyDoesNotAllowASecondWrite() async throws {
        let world = Browsing()
        let cv = try await world.stored(title: "Backend", design: classicForest)
        let look = world.look(of: cv)
        await look.load()
        look.choose(palette: "ocean")
        world.editing.loadErrors.withLock { $0 = [.unavailable] }
        await world.editing.gate.close()

        let applying = Task { await look.apply() }
        await waitUntil("the write to start") { await world.editing.gate.waiting == 1 }
        await look.load()
        let again = Task { await look.apply() }
        await settle()
        await world.editing.gate.open()
        await applying.value
        await again.value

        #expect(world.editing.looks.withLock { $0.count } == 1)
        #expect(look.status == .applied)
        #expect(look.chosen.isEmpty)
        #expect(try await world.editing.inStore(cv.id).design == DesignChoice(design: "classic", palette: "ocean", fonts: "serif"))
    }

    @Test("a read during a write does not make the next change a conflict")
    func readDuringApplyKeepsTheWriter() async throws {
        let world = Browsing()
        let cv = try await world.stored(title: "Backend", design: classicForest)
        let look = world.look(of: cv)
        await look.load()
        look.choose(palette: "ocean")
        await world.editing.gate.close()

        let applying = Task { await look.apply() }
        await waitUntil("the write to start") { await world.editing.gate.waiting == 1 }
        await look.load()
        await world.editing.gate.open()
        await applying.value
        look.choose(fonts: "sans")
        await look.apply()

        #expect(look.status == .applied)
        #expect(try await world.editing.inStore(cv.id).design == DesignChoice(design: "classic", palette: "ocean", fonts: "sans"))
    }

    @Test("a cancelled read that replaced another read goes back to the status before both")
    func cancelledReadAfterAnotherReadIsNotLeftLoading() async throws {
        let world = Browsing()
        let cv = try await world.stored(title: "Backend", design: classicForest)
        let look = world.look(of: cv)
        await look.load()
        world.editing.loadErrors.withLock { $0 = [.unavailable, .unavailable] }
        await world.editing.loadGate.close()

        let first = Task { await look.load() }
        await waitUntil("the first read to wait") { await world.editing.loadGate.waiting == 1 }
        let second = Task { await look.load() }
        await waitUntil("the second read to wait") { await world.editing.loadGate.waiting == 2 }
        second.cancel()
        await world.editing.loadGate.open()
        await first.value
        await second.value

        #expect(look.status == .ready)
    }

    @Test("a read that returns the CV after its task was cancelled publishes it, so the next change is no conflict")
    func cancelledReadThatReturnsPublishes() async throws {
        let world = Browsing()
        let cv = try await world.stored(title: "Backend", design: classicForest)
        let look = world.look(of: cv)
        await look.load()
        try await world.editing.otherWindowSaves(cv, fullName: "Someone Else")
        await world.editing.loadGate.close()

        let reading = Task { await look.load() }
        await waitUntil("the read to wait") { await world.editing.loadGate.waiting == 1 }
        reading.cancel()
        await world.editing.loadGate.open()
        await reading.value

        #expect(look.status == .ready)

        look.choose(palette: "ocean")
        await look.apply()

        #expect(look.status == .applied)
        #expect(try await world.editing.inStore(cv.id).design == DesignChoice(design: "classic", palette: "ocean", fonts: "serif"))
    }

    @Test("a change applied while the CV is read writes nothing and keeps the choices")
    func applyDuringLoadWritesNothing() async throws {
        let world = Browsing()
        let cv = try await world.stored(title: "Backend", design: classicForest)
        let look = world.look(of: cv)
        await look.load()
        look.choose(palette: "ocean")
        await world.editing.loadGate.close()

        let loading = Task { await look.load() }
        await waitUntil("the read to start") { await world.editing.loadGate.waiting == 1 }
        await look.apply()

        #expect(world.editing.looks.withLock { $0.isEmpty })
        #expect(look.chosen == [.palette])
        #expect(look.status == .loading)

        await world.editing.loadGate.open()
        await loading.value
        await look.apply()

        #expect(look.status == .applied)
        #expect(try await world.editing.inStore(cv.id).design == DesignChoice(design: "classic", palette: "ocean", fonts: "serif"))
    }
}
