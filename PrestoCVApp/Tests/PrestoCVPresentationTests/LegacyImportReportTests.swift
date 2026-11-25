import Synchronization
import Testing
import PrestoCVApplication
import PrestoCVDomain
@testable import PrestoCVPresentation
import PrestoCVWorkflowPorts

/// The import's report as a test sets it, and the removal of the old copies: it records the CVs each removal names, and
/// after its gate returns those of them in `kept`.
final class ReviewingFake: LegacyImportReviewing {
    let summary: LegacyImportSummary
    let kept: Set<CVID>
    let removals = Mutex<[Set<CVID>]>([])
    let gate = Gate()

    init(
        drops: [CVID: [LegacyDrop]] = [:], toCheck: [CVID: [LegacyCheck]] = [:], leftOut: [LegacyLeftOut: Int] = [:],
        didNotRun: Bool = false, kept: Set<CVID> = []
    ) {
        summary = LegacyImportSummary(drops: drops, toCheck: toCheck, leftOut: leftOut, didNotRun: didNotRun)
        self.kept = kept
    }

    func removeOldCopies(of shown: Set<CVID>) async -> Set<CVID> {
        removals.withLock { $0.append(shown) }
        await gate.pass()
        return kept.intersection(shown)
    }
}

/// The choice not to be reminded, in memory. A failing one never keeps it.
final class ReminderFake: LegacyReportReminding {
    let stopped: Mutex<Bool>
    let failing: Bool

    init(stopped: Bool = false, failing: Bool = false) { self.stopped = Mutex(stopped); self.failing = failing }

    func remindsAgain() async -> Bool { !stopped.withLock { $0 } }

    func stopReminding() async throws(LegacyReminderFailure) {
        if failing { throw .notKept }
        stopped.withLock { $0 = true }
    }
}

@MainActor
@Suite("Import report")
struct LegacyImportReportTests {
    let world = Browsing()

    func report(_ reviewing: ReviewingFake, reminder: ReminderFake = ReminderFake()) -> LegacyImportReportViewModel {
        LegacyImportReportViewModel(
            reviewing: reviewing, reminder: reminder, browsing: world.browsing, untitled: Browsing.untitled,
            numbered: { "\($0) (\($1))" }
        )
    }

    @Test("the sheet lists the CVs with details lost, then those to check, in the list's order by label, each detail once")
    func rows() async throws {
        let ada = try await world.stored(title: "Ada")
        let grace = try await world.stored(title: "Grace")
        let linus = try await world.stored(title: "Linus")
        _ = try await world.stored(title: "Margaret")
        let nameless = try await world.stored(title: "", fullName: "")
        let every: [LegacyDrop] = [
            .documentLanguage, .profile, .certificationLink, .certificationYear, .skillLevel, .website, .phone, .email, .look,
        ]
        let report = report(ReviewingFake(
            drops: [ada.id: [.email, .look, .email], grace.id: every, nameless.id: [.email], world.editing.ids.next(): [.phone]],
            toCheck: [ada.id: [.period], linus.id: [.period, .period]]
        ))

        await report.load()

        #expect(report.leftOut == [
            LegacyReportRow(id: world.reference(nameless), label: Browsing.untitled, details: [.email]),
            LegacyReportRow(id: world.reference(grace), label: "Grace", details: LegacyDetail.allCases.filter { $0 != .period }),
            LegacyReportRow(id: world.reference(ada), label: "Ada", details: [.look, .email]),
        ])
        #expect(report.toCheck == [
            LegacyReportRow(id: world.reference(linus), label: "Linus", details: [.period]),
            LegacyReportRow(id: world.reference(ada), label: "Ada", details: [.period]),
        ])
        #expect(report.state == .review && report.isPresented)
    }

    @Test("a CV whose details are all to check is in the sheet, with nothing lost")
    func onlyToCheck() async throws {
        let ada = try await world.stored(title: "Ada")
        let report = report(ReviewingFake(toCheck: [ada.id: [.period]]))

        await report.load()

        #expect(report.leftOut.isEmpty)
        #expect(report.toCheck == [LegacyReportRow(id: world.reference(ada), label: "Ada", details: [.period])])
        #expect(report.state == .review)
    }

    @Test("no sheet without losses, after the choice not to be reminded, or when the list cannot be read; the mark stays")
    func noSheet() async throws {
        let ada = try await world.stored(title: "Ada")
        let nothing = report(ReviewingFake())
        await nothing.load()
        #expect(nothing.state == .hidden && nothing.leftOut.isEmpty && nothing.toCheck.isEmpty && nothing.notice == nil)

        let declined = report(ReviewingFake(drops: [ada.id: [.look]]), reminder: ReminderFake(stopped: true))
        await declined.load()
        #expect(declined.state == .hidden)
        #expect(declined.leftOut.map(\.id) == [world.reference(ada)] && declined.isIncomplete(world.reference(ada)))

        world.browsing.listError.withLock { $0 = .unavailable }
        let unlisted = report(ReviewingFake(drops: [ada.id: [.look]]))
        await unlisted.load()
        #expect(unlisted.state == .hidden && unlisted.leftOut.isEmpty && unlisted.isIncomplete(world.reference(ada)))
    }

    @Test("a list the report could not read and that reads later still marks the CV that lost details, and no other")
    func markWithoutTheList() async throws {
        let ada = try await world.stored(title: "Ada")
        let linus = try await world.stored(title: "Linus")
        world.browsing.listError.withLock { $0 = .unavailable }
        let report = report(ReviewingFake(drops: [ada.id: [.look], linus.id: []], toCheck: [linus.id: [.period]]))

        await report.load()
        world.browsing.listError.withLock { $0 = nil }
        let listed = try await world.browsing.list().cvs.map { CVReference(id: $0.id) }

        #expect(listed.filter(report.isIncomplete) == [world.reference(ada)])
        #expect(report.state == .hidden)
    }

    @Test("the list marks the CVs that lost details as incomplete, not those only to check, and the mark stays after Not now")
    func incomplete() async throws {
        let ada = try await world.stored(title: "Ada")
        let linus = try await world.stored(title: "Linus")
        let margaret = try await world.stored(title: "Margaret")
        let report = report(ReviewingFake(drops: [ada.id: [.look]], toCheck: [ada.id: [.period], linus.id: [.period]]))

        await report.load()
        #expect(report.isIncomplete(world.reference(ada)))
        #expect(!report.isIncomplete(world.reference(linus)) && !report.isIncomplete(world.reference(margaret)))

        report.close()
        #expect(report.state == .hidden && report.isIncomplete(world.reference(ada)))
    }

    @Test("Confirm removes only the old copies of the CVs the sheet shows: one missing from the list keeps its copy")
    func confirmNamesTheShown() async throws {
        let ada = try await world.stored(title: "Ada")
        let linus = try await world.stored(title: "Linus")
        let unlisted = world.editing.ids.next()
        let reviewing = ReviewingFake(drops: [ada.id: [.look], unlisted: [.email]], toCheck: [linus.id: [.period], unlisted: [.period]])
        let report = report(reviewing)
        await report.load()
        #expect(report.leftOut.map(\.id) == [world.reference(ada)] && report.toCheck.map(\.id) == [world.reference(linus)])

        await report.confirm()

        #expect(reviewing.removals.withLock { $0 } == [[ada.id, linus.id]])
        #expect(report.state == .removed && !report.isIncomplete(world.reference(ada)))
        #expect(report.isIncomplete(CVReference(id: unlisted)))
    }

    @Test("the CVs not imported are counted by cause, and their notice stays until hidden")
    func notImported() async {
        let report = report(ReviewingFake(leftOut: [.notSaved: 1, .damaged: 2]))

        await report.load()

        #expect(report.notImported == [NotImportedCount(cause: .damaged, count: 2), NotImportedCount(cause: .notSaved, count: 1)])
        #expect(report.notice == .notImported(3) && report.state == .hidden)
        report.hideNotice()
        #expect(report.notice == nil)
    }

    @Test("an import that did not run shows that it did not, never an empty report")
    func didNotRun() async {
        let report = report(ReviewingFake(didNotRun: true))

        await report.load()

        #expect(report.notice == .didNotRun)
        #expect(report.state == .hidden && report.notImported.isEmpty)
    }

    @Test("Confirm removes the old copies once, whatever the check says, and closes the sheet when none stay")
    func confirm() async throws {
        let ada = try await world.stored(title: "Ada")
        let reviewing = ReviewingFake(drops: [ada.id: [.look]])
        let reminder = ReminderFake()
        let report = report(reviewing, reminder: reminder)
        await report.load()
        report.remindsNoMore = true
        await reviewing.gate.close()

        let first = Task { await report.confirm() }
        await waitUntil("the removal to start") { await reviewing.gate.waiting == 1 }
        #expect(report.state == .removing && report.isBusy && report.isPresented)
        let second = Task { await report.confirm() }
        report.close()
        #expect(report.state == .removing)
        await reviewing.gate.open()
        await first.value
        await second.value

        #expect(report.state == .removed && !report.isPresented)
        #expect(reviewing.removals.withLock { $0 } == [[ada.id]])
        #expect(await reminder.remindsAgain())
    }

    @Test("old copies that stay keep the sheet on the result until Done, and their CVs keep the mark")
    func keptSome() async throws {
        let ada = try await world.stored(title: "Ada")
        let grace = try await world.stored(title: "Grace")
        let linus = try await world.stored(title: "Linus")
        let report = report(ReviewingFake(
            drops: [ada.id: [.look], grace.id: [.email]], toCheck: [linus.id: [.period]], kept: [ada.id, linus.id]
        ))
        await report.load()

        await report.confirm()
        #expect(report.state == .keptSome(2) && report.isPresented)
        #expect(report.isIncomplete(world.reference(ada)))
        #expect(!report.isIncomplete(world.reference(grace)) && !report.isIncomplete(world.reference(linus)))
        report.close()
        #expect(report.state == .hidden && report.isIncomplete(world.reference(ada)))
    }

    @Test("Not now keeps the old copies, and with the check the report does not come back")
    func notNow() async throws {
        let ada = try await world.stored(title: "Ada")
        let reviewing = ReviewingFake(drops: [ada.id: [.look]])
        let reminder = ReminderFake()
        let plain = report(reviewing, reminder: reminder)
        await plain.load()
        plain.close()
        #expect(plain.state == .hidden && plain.storingChoice == nil)
        #expect(await reminder.remindsAgain())

        let checked = report(reviewing, reminder: reminder)
        await checked.load()
        checked.remindsNoMore = true
        checked.close()
        await checked.storingChoice?.value
        #expect(checked.state == .hidden && checked.remindsNoMore)
        #expect(await !reminder.remindsAgain())
        #expect(reviewing.removals.withLock { $0 }.isEmpty)
    }

    @Test("a choice that cannot be kept is unchecked, and the report comes back")
    func choiceNotKept() async throws {
        let ada = try await world.stored(title: "Ada")
        let reminder = ReminderFake(failing: true)
        let report = report(ReviewingFake(drops: [ada.id: [.look]]), reminder: reminder)
        await report.load()
        report.remindsNoMore = true

        report.close()
        await report.storingChoice?.value

        #expect(!report.remindsNoMore)
        #expect(await reminder.remindsAgain())
    }
}
