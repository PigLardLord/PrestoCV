import Testing
import PrestoCVDomain
@testable import PrestoCVPresentation

/// The look picker runs one operation at a time. Each case starts one operation, holds it in its port, makes a second
/// operation, then lets both go on.
@MainActor
@Suite("Look picker: one operation at a time")
struct LookOperationTableTests {

    enum Step: Sendable, CustomTestStringConvertible {
        case load, apply
        var testDescription: String { self == .load ? "load" : "apply" }
    }

    /// What is left when both operations are over. The person chose the palette `ocean` before them.
    struct Case: Sendable, CustomTestStringConvertible {
        let first: Step
        let second: Step
        let succeeds: Bool
        /// How many times the CV was read by the two operations, and how many changes reached the writer.
        let reads: Int
        let writes: Int
        let status: LookStatus
        let chosen: Set<LookPart>
        /// The palette the store holds at the end.
        let storedPalette: String
        var testDescription: String { "\(first), then \(second), the first \(succeeds ? "works" : "fails")" }
    }

    nonisolated static let cases = [
        Case(first: .load, second: .load, succeeds: true, reads: 2, writes: 0, status: .ready, chosen: [.palette], storedPalette: "forest"),
        Case(first: .load, second: .load, succeeds: false, reads: 2, writes: 0, status: .ready, chosen: [.palette], storedPalette: "forest"),
        Case(first: .load, second: .apply, succeeds: true, reads: 1, writes: 0, status: .ready, chosen: [.palette], storedPalette: "forest"),
        Case(first: .load, second: .apply, succeeds: false, reads: 1, writes: 0, status: .failed, chosen: [.palette], storedPalette: "forest"),
        Case(first: .apply, second: .load, succeeds: true, reads: 0, writes: 1, status: .applied, chosen: [], storedPalette: "ocean"),
        Case(first: .apply, second: .load, succeeds: false, reads: 0, writes: 1, status: .conflict, chosen: [.palette], storedPalette: "forest"),
        Case(first: .apply, second: .apply, succeeds: true, reads: 0, writes: 1, status: .applied, chosen: [], storedPalette: "ocean"),
        Case(first: .apply, second: .apply, succeeds: false, reads: 0, writes: 1, status: .conflict, chosen: [.palette], storedPalette: "forest"),
    ]

    @Test("two operations of the picker never overlap", arguments: cases)
    func operationsDoNotOverlap(_ run: Case) async throws {
        let world = Browsing()
        let cv = try await world.stored(title: "Backend", design: DesignChoice(design: "classic", palette: "forest", fonts: "serif"))
        let look = world.look(of: cv)
        await look.load()
        look.choose(palette: "ocean")
        let readsBefore = world.editing.loads.withLock { $0 }
        let gate = run.first == .load ? world.editing.loadGate : world.editing.gate
        if run.first == .load, !run.succeeds { world.editing.loadErrors.withLock { $0 = [.unavailable] } }
        await gate.close()

        let first = Task { await perform(run.first, on: look) }
        await waitUntil("the first operation to start") { await gate.waiting == 1 }
        if run.first == .apply, !run.succeeds { try await world.editing.otherWindowSaves(cv, fullName: "Someone Else") }
        let second = Task { await perform(run.second, on: look) }
        if run.first == .load, run.second == .load {
            await waitUntil("the second read to start") { await gate.waiting == 2 }
        } else {
            await settle()
        }
        await gate.open()
        await first.value
        await second.value

        #expect(world.editing.loads.withLock { $0 } - readsBefore == run.reads)
        #expect(world.editing.looks.withLock { $0.count } == run.writes)
        #expect(look.status == run.status)
        #expect(look.chosen == run.chosen)
        let palette = try await world.editing.inStore(cv.id).design?.palette
        #expect(palette == run.storedPalette)
        #expect(look.shown.palette == "ocean")
    }

    private func perform(_ step: Step, on look: LookViewModel) async {
        switch step {
        case .load: await look.load()
        case .apply: await look.apply()
        }
    }
}
