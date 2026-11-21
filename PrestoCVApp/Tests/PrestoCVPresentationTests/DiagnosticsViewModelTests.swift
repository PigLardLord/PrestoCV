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

    @Test("a copy that finishes after the screen closed is not offered, and the discard comes after it")
    func lateCopyAfterFinish() async throws {
        let reading = DiagnosticsFake(runs: [newer])
        await reading.copying.close()
        let diagnostics = DiagnosticsViewModel(reading: reading)
        let loading = Task { await diagnostics.load() }
        #expect(try await reading.copying.holds(1))

        let closing = Task { await diagnostics.finish() }
        await settle()
        #expect(reading.discards == 0, "The discard waits for the copy")
        await reading.copying.open()
        await loading.value
        await closing.value

        #expect(diagnostics.shareFiles.isEmpty)
        #expect(reading.calls == [.copy(newer.id), .copied(newer.id), .discard])
        #expect(reading.folder.isEmpty)
    }

    @Test("a later choice waits for the copy of an earlier one, and its files stay in the folder")
    func copiesOneAtATime() async throws {
        let reading = DiagnosticsFake(runs: [newer, older])
        let diagnostics = DiagnosticsViewModel(reading: reading)
        await diagnostics.load()
        await reading.copying.close()
        let first = Task { await diagnostics.select(older.id) }
        #expect(try await reading.copying.holds(1))
        let second = Task { await diagnostics.select(newer.id) }
        await settle()
        #expect(reading.copiesMadeFor == [newer.id, older.id], "The later copy has not started")

        await reading.copying.open()
        await first.value
        await second.value

        #expect(diagnostics.selection == newer.id)
        #expect(diagnostics.summary == "Summary of run 2")
        #expect(diagnostics.shareFiles == DiagnosticsFake.files(of: newer.id))
        #expect(reading.folder == diagnostics.shareFiles, "No earlier copy emptied the folder after the later one")
        #expect(reading.mostCopiesAtOnce == 1)
        #expect(reading.discards == 0)
    }

    @Test("a choice replaced before its turn came makes no copy")
    func replacedChoiceMakesNoCopy() async throws {
        let reading = DiagnosticsFake(runs: [newer, older])
        let diagnostics = DiagnosticsViewModel(reading: reading)
        await diagnostics.load()
        await reading.copying.close()
        let first = Task { await diagnostics.select(older.id) }
        #expect(try await reading.copying.holds(1))
        let replaced = Task { await diagnostics.select(newer.id) }
        await settle()
        let last = Task { await diagnostics.select(older.id) }
        await settle()

        await reading.copying.open()
        await first.value
        await replaced.value
        await last.value

        #expect(reading.copiesMadeFor == [newer.id, older.id, older.id])
        #expect(diagnostics.selection == older.id)
        #expect(diagnostics.shareFiles == DiagnosticsFake.files(of: older.id))
        #expect(reading.folder == diagnostics.shareFiles)
    }

    @Test("a screen closed while its runs are read lists nothing and makes no copy")
    func closedWhileLoading() async throws {
        let reading = DiagnosticsFake(runs: [newer])
        await reading.listing.close()
        let diagnostics = DiagnosticsViewModel(reading: reading)
        let loading = Task { await diagnostics.load() }
        #expect(try await reading.listing.holds(1))

        await diagnostics.finish()
        await reading.listing.open()
        await loading.value

        #expect(diagnostics.state == .loading)
        #expect(diagnostics.rows.isEmpty)
        #expect(diagnostics.selection == nil)
        #expect(reading.calls == [.discard])
    }

    @Test("the runs read for an earlier opening of the screen are not listed in a later one")
    func earlierOpeningIsIgnored() async throws {
        let reading = DiagnosticsFake(runs: [newer])
        await reading.listing.close()
        let diagnostics = DiagnosticsViewModel(reading: reading)
        let firstOpening = Task { await diagnostics.load() }
        #expect(try await reading.listing.holds(1))
        await diagnostics.finish()
        reading.setRuns([newer, older])
        let secondOpening = Task { await diagnostics.load() }
        #expect(try await reading.listing.holds(2))

        await reading.listing.releaseNewest()
        await secondOpening.value
        await reading.listing.releaseAll()
        await firstOpening.value

        #expect(diagnostics.rows.map(\.id) == [newer.id, older.id])
        #expect(diagnostics.selection == newer.id)
        #expect(reading.calls == [.discard, .copy(newer.id), .copied(newer.id)])
        #expect(diagnostics.shareFiles == DiagnosticsFake.files(of: newer.id))
    }

    @Test("a choice on a closed screen changes nothing")
    func choiceOnAClosedScreen() async {
        let reading = DiagnosticsFake(runs: [newer, older])
        let diagnostics = DiagnosticsViewModel(reading: reading)
        await diagnostics.load()
        await diagnostics.finish()

        await diagnostics.select(older.id)

        #expect(diagnostics.selection == newer.id)
        #expect(diagnostics.shareFiles.isEmpty)
        #expect(reading.copiesMadeFor == [newer.id])
    }

    @Test("DiagnosticsViewModel reports a failed copy")
    func reportsAFailedCopy() async {
        let reading = DiagnosticsFake(runs: [newer, older])
        reading.failCopies(of: older.id)
        let diagnostics = DiagnosticsViewModel(reading: reading)
        await diagnostics.load()
        #expect(!diagnostics.copiesFailed)

        await diagnostics.select(older.id)

        #expect(diagnostics.copiesFailed)
        #expect(diagnostics.shareFiles.isEmpty)
    }

    @Test("a newer choice clears a failed copy")
    func newerChoiceClearsAFailedCopy() async {
        let reading = DiagnosticsFake(runs: [newer, older])
        reading.failCopies(of: older.id)
        let diagnostics = DiagnosticsViewModel(reading: reading)
        await diagnostics.load()
        await diagnostics.select(older.id)
        #expect(diagnostics.copiesFailed)

        await diagnostics.select(newer.id)

        #expect(!diagnostics.copiesFailed)
        #expect(diagnostics.shareFiles == DiagnosticsFake.files(of: newer.id))
    }

    @Test("a failed copy after the screen closed is not reported")
    func failedCopyAfterFinishIsNotReported() async throws {
        let reading = DiagnosticsFake(runs: [newer])
        reading.failCopies(of: newer.id)
        await reading.copying.close()
        let diagnostics = DiagnosticsViewModel(reading: reading)
        let loading = Task { await diagnostics.load() }
        #expect(try await reading.copying.holds(1))

        let closing = Task { await diagnostics.finish() }
        await settle()
        await reading.copying.open()
        await loading.value
        await closing.value

        #expect(!diagnostics.copiesFailed)
    }
}
