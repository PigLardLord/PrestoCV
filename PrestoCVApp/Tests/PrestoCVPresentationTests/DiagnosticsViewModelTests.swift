import Foundation
import Testing
import PrestoCVWorkflowPorts
@testable import PrestoCVPresentation

@MainActor
@Suite("Diagnostics")
struct DiagnosticsViewModelTests {

    private let older = DiagnosticRun.run(1, at: 0, kind: .textImport, outcome: .failed)
    private let newer = DiagnosticRun.run(2, at: 600)

    @Test("DiagnosticsViewModel starts loading, with nothing chosen")
    func startsLoading() {
        let diagnostics = DiagnosticsViewModel(reading: DiagnosticsFake(runs: [newer]))

        #expect(diagnostics.state == .loading)
        #expect(diagnostics.rows.isEmpty)
        #expect(diagnostics.selection == nil)
        #expect(diagnostics.summary == "")
    }

    @Test("DiagnosticsViewModel selects the newest run on load")
    func selectsTheNewest() async {
        let diagnostics = DiagnosticsViewModel(reading: DiagnosticsFake(runs: [newer, older]))

        await diagnostics.load()

        #expect(diagnostics.state == .listed)
        #expect(diagnostics.rows.map(\.id) == [newer.id, older.id])
        #expect(diagnostics.selection == newer.id)
        #expect(diagnostics.summary == "Summary of run 2")
    }

    @Test("DiagnosticsViewModel lists the runs newest first whatever order the store gives them")
    func ordersNewestFirst() async {
        let diagnostics = DiagnosticsViewModel(reading: DiagnosticsFake(runs: [older, newer]))

        await diagnostics.load()

        #expect(diagnostics.rows.map(\.id) == [newer.id, older.id])
        #expect(diagnostics.selection == newer.id)
    }

    @Test("DiagnosticsViewModel shows the empty state when there are no runs")
    func emptyState() async {
        let reading = DiagnosticsFake(runs: [])
        let diagnostics = DiagnosticsViewModel(reading: reading)

        await diagnostics.load()

        #expect(diagnostics.state == .empty)
        #expect(diagnostics.selection == nil)
        #expect(diagnostics.summary == "")
        #expect(diagnostics.shareFiles.isEmpty)
        #expect(reading.copiesMadeFor.isEmpty)
    }

    @Test("DiagnosticsViewModel maps kinds and outcomes to codes")
    func mapsCodes() async {
        let runs = [
            DiagnosticRun.run(4, at: 40, kind: .aiDraft, outcome: .finished),
            DiagnosticRun.run(3, at: 30, kind: .textImport, outcome: .failed),
            DiagnosticRun.run(2, at: 20, kind: .aiDraft, outcome: .cancelled),
            DiagnosticRun.run(1, at: 10, kind: .textImport, outcome: .unfinished),
        ]
        let diagnostics = DiagnosticsViewModel(reading: DiagnosticsFake(runs: runs))

        await diagnostics.load()

        #expect(diagnostics.rows.map(\.kind) == [.aiDraft, .textImport, .aiDraft, .textImport])
        #expect(diagnostics.rows.map(\.outcome) == [.finished, .failed, .cancelled, .unfinished])
        #expect(diagnostics.rows.map(\.started) == runs.map(\.started))
    }

    @Test("DiagnosticsViewModel makes share copies on selection")
    func copiesOnSelection() async {
        let reading = DiagnosticsFake(runs: [newer, older])
        let diagnostics = DiagnosticsViewModel(reading: reading)
        await diagnostics.load()
        #expect(diagnostics.shareFiles == DiagnosticsFake.files(of: newer.id))

        await diagnostics.select(older.id)

        #expect(diagnostics.selection == older.id)
        #expect(diagnostics.summary == "Summary of run 1")
        #expect(diagnostics.shareFiles == DiagnosticsFake.files(of: older.id))
        #expect(reading.copiesMadeFor == [newer.id, older.id])
    }

    @Test("DiagnosticsViewModel ignores a run it does not list")
    func unknownRunIsIgnored() async {
        let reading = DiagnosticsFake(runs: [newer])
        let diagnostics = DiagnosticsViewModel(reading: reading)
        await diagnostics.load()

        await diagnostics.select(older.id)

        #expect(diagnostics.selection == newer.id)
        #expect(reading.copiesMadeFor == [newer.id])
    }

    @Test("DiagnosticsViewModel keeps the summary and offers no files when the copies cannot be made")
    func copyFailure() async {
        let reading = DiagnosticsFake(runs: [newer, older])
        reading.failCopies(of: older.id)
        let diagnostics = DiagnosticsViewModel(reading: reading)
        await diagnostics.load()

        await diagnostics.select(older.id)

        #expect(diagnostics.selection == older.id)
        #expect(diagnostics.summary == "Summary of run 1")
        #expect(diagnostics.shareFiles.isEmpty)
    }

    @Test("DiagnosticsViewModel discards share copies on finish")
    func discardsOnFinish() async {
        let reading = DiagnosticsFake(runs: [newer])
        let diagnostics = DiagnosticsViewModel(reading: reading)
        await diagnostics.load()

        await diagnostics.finish()

        #expect(diagnostics.shareFiles.isEmpty)
        #expect(reading.discards == 1)
    }

    @Test("a copy that finishes after the screen closed is discarded and not offered")
    func lateCopyAfterFinish() async throws {
        let reading = DiagnosticsFake(runs: [newer])
        await reading.copying.close()
        let diagnostics = DiagnosticsViewModel(reading: reading)
        let loading = Task { await diagnostics.load() }
        #expect(try await reading.copying.holds(1))

        await diagnostics.finish()
        await reading.copying.open()
        await loading.value

        #expect(diagnostics.shareFiles.isEmpty)
        #expect(reading.discards == 2)
    }

    @Test("a slower copy of an earlier choice does not replace the files of the later one")
    func staleCopyIsIgnored() async throws {
        let reading = DiagnosticsFake(runs: [newer, older])
        let diagnostics = DiagnosticsViewModel(reading: reading)
        await diagnostics.load()
        await reading.copying.close()
        let first = Task { await diagnostics.select(older.id) }
        #expect(try await reading.copying.holds(1))
        let second = Task { await diagnostics.select(newer.id) }
        #expect(try await reading.copying.holds(2))

        await reading.copying.releaseNewest()
        await second.value
        await reading.copying.releaseAll()
        await first.value

        #expect(diagnostics.selection == newer.id)
        #expect(diagnostics.summary == "Summary of run 2")
        #expect(diagnostics.shareFiles == DiagnosticsFake.files(of: newer.id))
        #expect(reading.discards == 0)
    }
}
