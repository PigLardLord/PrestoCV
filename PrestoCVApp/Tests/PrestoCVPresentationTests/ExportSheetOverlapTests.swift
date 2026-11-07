import Foundation
import Testing
import PrestoCVDomain
@testable import PrestoCVPresentation
import PrestoCVWorkflowPorts

/// Each pair of the overlap table of the export sheet: an intent, or the end of the share sheet, that comes while an
/// earlier intent still waits for its pause or for its export. Every row starts with the port's gate closed, on a CV in
/// Italian; after its steps the gate opens, every export left ends, and any late result lands.
@MainActor
@Suite("Export sheet overlaps")
struct ExportSheetOverlapTests {

    enum Step: Sendable {
        case start, refresh, stop
        case select(String)
        /// The task of the last intent waits in its pause.
        case pauseBegins
        /// The clock passes the pause; nothing waits for what it wakes.
        case pauseEnds
        /// So many exports wait at the port's gate.
        case held(Int)
        case releaseNewest, releaseAll
        /// The export on screen ends.
        case exportEnds
        /// What the port gives from now on.
        case portGives(Result<ExportOutcome, ExportFailure>)
        /// The editor's look changes, while the sheet is open.
        case lookChanges(String)
        /// The share sheet of the first PDF ends.
        case shareOfTheFirstPDFEnds(ShareResult)
    }

    struct Overlap: Sendable, CustomTestStringConvertible {
        let name: String
        let steps: [Step]
        /// The language of each export that reached the port.
        let languages: [String]
        /// The design of each export that reached the port.
        let looks: [String?]
        let cancelled: Int
        /// How many times the sheet read the CV.
        let snapshots: Int
        let status: ExportStatus
        let document: ExportedDocument?
        var testDescription: String { name }
    }

    nonisolated static let late = ExportOutcome(pdf: Data([9]), pageCount: 3, requiredPages: 3)
    nonisolated static let second = ExportOutcome(pdf: Data([7]), pageCount: 2, requiredPages: 2)
    nonisolated static let first = ExportingFake.onePageDocument

    nonisolated static let overlaps: [Overlap] = [
        Overlap(name: "a selection during the pause",
                steps: [.start, .pauseBegins, .select("de"), .pauseEnds, .held(1)],
                languages: ["de"], looks: [nil], cancelled: 0, snapshots: 1, status: .done(pages: 1), document: first),
        Overlap(name: "a selection after the pause ended, before its export began",
                steps: [.start, .pauseBegins, .pauseEnds, .select("de"), .pauseEnds, .held(1)],
                languages: ["de"], looks: [nil], cancelled: 0, snapshots: 1, status: .done(pages: 1), document: first),
        Overlap(name: "a selection during the export",
                steps: [.start, .pauseEnds, .held(1), .select("de"), .pauseEnds, .held(2), .releaseNewest, .exportEnds,
                        .portGives(.success(late)), .releaseAll],
                languages: ["it", "de"], looks: [nil, nil], cancelled: 1, snapshots: 2, status: .done(pages: 1),
                document: first),
        Overlap(name: "refresh during the export",
                steps: [.start, .pauseEnds, .held(1), .lookChanges("classic"), .refresh, .pauseEnds, .held(2),
                        .releaseNewest, .exportEnds, .portGives(.success(late)), .releaseAll],
                languages: ["it", "it"], looks: [nil, "classic"], cancelled: 1, snapshots: 2, status: .done(pages: 1),
                document: first),
        Overlap(name: "stop during the pause",
                steps: [.start, .pauseBegins, .stop, .pauseEnds],
                languages: [], looks: [], cancelled: 0, snapshots: 0, status: .idle, document: nil),
        Overlap(name: "stop during the export, its PDF coming late",
                steps: [.start, .pauseEnds, .held(1), .stop, .releaseAll],
                languages: ["it"], looks: [nil], cancelled: 1, snapshots: 1, status: .idle, document: nil),
        Overlap(name: "a late failure after stop",
                steps: [.start, .pauseEnds, .held(1), .stop, .portGives(.failure(.renderingFailed)), .releaseAll],
                languages: ["it"], looks: [nil], cancelled: 1, snapshots: 1, status: .idle, document: nil),
        Overlap(name: "a share ending after a new export started",
                steps: [.start, .pauseEnds, .held(1), .releaseAll, .exportEnds, .select("de"),
                        .shareOfTheFirstPDFEnds(.saved), .portGives(.success(second)), .pauseEnds, .held(1), .releaseAll,
                        .exportEnds, .shareOfTheFirstPDFEnds(.sent)],
                languages: ["it", "de"], looks: [nil, nil], cancelled: 0, snapshots: 2, status: .done(pages: 2),
                document: ExportedDocument(pdf: Data([7]), pages: 2)),
    ]

    @Test("A late intent or share wins over the task it overlaps, which publishes nothing", arguments: overlaps)
    func overlapsFollowTheTable(row: Overlap) async {
        let world = SheetWorld()
        let sheet = world.sheet()
        await world.exporter.gate.close()

        for step in row.steps {
            await take(step, on: sheet, in: world)
        }
        await world.exporter.gate.open()
        await waitUntil("every export to end") { sheet.status != .exporting }
        await settle()

        #expect(world.exporter.languages.withLock { $0 }.map(\.tag) == row.languages)
        #expect(world.exporter.snapshots.withLock { $0 }.map(\.design?.design) == row.looks)
        #expect(world.exporter.cancellations.withLock { $0 } == row.cancelled)
        #expect(world.snapshotsTaken == row.snapshots, "a superseded task reads nothing")
        #expect(sheet.status == row.status)
        #expect(sheet.document == row.document)
        #expect(sheet.shareOutcome == nil, "no share in the table ends while its PDF is on screen")
    }

    private func take(_ step: Step, on sheet: ExportSheetViewModel, in world: SheetWorld) async {
        switch step {
        case .start: sheet.start()
        case .refresh: sheet.refresh()
        case .stop: sheet.stop()
        case .select(let tag): sheet.select(language: SheetWorld.language(tag))
        case .pauseBegins: await waitUntil("the pause to begin") { world.clock.sleeping == 1 }
        case .pauseEnds: world.passThePause()
        case .held(let count): await world.held(count)
        case .releaseNewest: await world.exporter.gate.releaseNewest()
        case .releaseAll: await world.exporter.gate.releaseAll()
        case .exportEnds: await waitUntil("the export to end") { sheet.status != .exporting }
        case .portGives(let result): world.exporter.returns(result.mapError { $0 as any Error })
        case .lookChanges(let design): world.cv = SheetWorld.cv(design: design)
        case .shareOfTheFirstPDFEnds(let result): sheet.shareEnded(result, of: Self.first)
        }
    }
}
