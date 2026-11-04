import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore

// MARK: - Test Doubles

private struct UnusedSampleCVRepository: SampleCVRepositoryProtocol {
    func getDefaultSample() async throws -> CVModel { CVModel() }
    func getAllSamples() async throws -> [CVModel] { [] }
    func getSample(by name: String) async throws -> CVModel? { nil }
}

// MARK: - CVListViewModel Row Text Tests

@MainActor
@Suite("CVListViewModel Tests - what a row says besides the name of the CV")
struct CVListRowTextTests {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let separator = " · "

    private func makeViewModel(repository: InMemoryCVRepository) -> CVListViewModel {
        makeViewModel(repository: repository, clock: TestClock(now))
    }

    private func makeViewModel(
        repository: InMemoryCVRepository,
        clock: TestClock,
        calendar: @escaping () -> Calendar = { CVListRowTextTests.calendar },
        sleep: @escaping (Duration) async throws -> Void = { _ in }
    ) -> CVListViewModel {
        let useCase = CVManagementUseCase(cvRepository: repository, sampleRepository: UnusedSampleCVRepository())
        return CVListViewModel(cvManagementUseCase: useCase, now: { clock.now() }, calendar: calendar, sleep: sleep)
    }

    /// What the row of a CV that was saved at `savedAt` says when it is looked at in `moment`, in a time zone.
    private func line(saved savedAt: Date, at moment: Date, zone: String = "UTC") -> String {
        LastSavedDescription(locale: Locale(identifier: "en"), calendar: TestZone(zone).calendar).text(for: savedAt, relativeTo: moment)
    }

    private nonisolated static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func moment(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        Self.calendar.date(from: DateComponents(year: 2023, month: 11, day: day, hour: hour, minute: minute))!
    }

    private func cv(name: String = "", person: String = "", jobTitle: String = "") -> CVModel {
        CVModel(name: name, personalInfo: PersonalInfo(name: person, title: jobTitle))
    }

    // MARK: - The line under the title

    @Test("Under a CV titled by its own name, the line gives the name of the person and the job title")
    func subtitleOfANamedCVHasNameAndJobTitle() {
        let viewModel = makeViewModel(repository: InMemoryCVRepository())

        #expect(viewModel.subtitle(of: cv(name: "Portfolio", person: "Alex Morgan", jobTitle: "Product Designer")) == "Alex Morgan\(separator)Product Designer")
    }

    @Test("Under a CV titled by its own name, the line has what is there when the name or the job title is missing")
    func subtitleOfANamedCVHasWhatIsThere() {
        let viewModel = makeViewModel(repository: InMemoryCVRepository())

        #expect(viewModel.subtitle(of: cv(name: "Portfolio", person: "Alex Morgan")) == "Alex Morgan")
        #expect(viewModel.subtitle(of: cv(name: "Portfolio", jobTitle: "Product Designer")) == "Product Designer")
    }

    @Test("Under a CV titled by its person, the line gives only the job title, and nothing without one")
    func subtitleOfACVTitledByItsPersonIsTheJobTitle() {
        let viewModel = makeViewModel(repository: InMemoryCVRepository())

        #expect(viewModel.subtitle(of: cv(person: "Alex Morgan", jobTitle: "Product Designer")) == "Product Designer")
        #expect(viewModel.subtitle(of: cv(person: "Alex Morgan")) == nil)
    }

    @Test("Under a CV titled by its job title there is no line: it has no person")
    func subtitleOfACVTitledByItsRoleIsNil() {
        let viewModel = makeViewModel(repository: InMemoryCVRepository())

        #expect(viewModel.subtitle(of: cv(jobTitle: "Product Designer")) == nil)
    }

    @Test("There is no line when the CV has neither a name nor a job title, or only white space", arguments: ["", "  ", " \n "])
    func subtitleIsNilWithoutPersonOrTitle(blank: String) {
        let viewModel = makeViewModel(repository: InMemoryCVRepository())

        #expect(viewModel.subtitle(of: cv(person: blank, jobTitle: blank)) == nil)
    }

    @Test("The line trims the white space around the parts")
    func subtitleTrims() {
        let viewModel = makeViewModel(repository: InMemoryCVRepository())

        #expect(viewModel.subtitle(of: cv(name: "Portfolio", person: "  Alex Morgan ", jobTitle: " Designer\n")) == "Alex Morgan\(separator)Designer")
    }

    // MARK: - The last save

    @Test("The last save line says how long ago the CV was saved")
    func lastSavedLineIsRelativeToNow() async {
        let saved = cv(name: "A")
        let repository = InMemoryCVRepository(cvs: [saved])
        await repository.setLastSaved(now.addingTimeInterval(-2 * 86_400), for: saved.id)
        let viewModel = makeViewModel(repository: repository)

        await viewModel.loadCVs()

        #expect(viewModel.lastSavedLine(of: saved) == line(saved: now.addingTimeInterval(-2 * 86_400), at: now))
    }

    @Test("The last save line is nil for a CV that was stored without a time")
    func lastSavedLineIsNilWithoutTime() async {
        let unstamped = cv(name: "A")
        let viewModel = makeViewModel(repository: InMemoryCVRepository(cvs: [unstamped]))

        await viewModel.loadCVs()

        #expect(viewModel.lastSavedLine(of: unstamped) == nil)
    }

    @Test("A CV that was just renamed, or duplicated, was saved just now, before the list is read again")
    func changedCVWasSavedJustNow() async throws {
        let original = cv(name: "A")
        let repository = InMemoryCVRepository(cvs: [original])
        await repository.setLastSaved(now.addingTimeInterval(-86_400), for: original.id)
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadCVs()
        let justNow = "cv.list.edited_just_now".localized

        await repository.holdNextListings()
        let renaming = Task { await viewModel.renameCV(id: original.id, to: "B") }
        await repository.waitUntilListingsAreHeld(1)
        let renamed = try #require(viewModel.cvs.first)
        let renamedLine = viewModel.lastSavedLine(of: renamed)
        await repository.releaseOldestListing(failingWith: AppError.unknown("disk"))
        await renaming.value

        await repository.holdNextListings()
        let duplicating = Task { await viewModel.duplicateCV(withId: original.id) }
        await repository.waitUntilListingsAreHeld(1)
        let copy = try #require(viewModel.cvs.first)
        let copyLine = viewModel.lastSavedLine(of: copy)
        await repository.releaseOldestListing(failingWith: AppError.unknown("disk"))
        await duplicating.value

        #expect(renamed.name == "B")
        #expect(renamedLine == justNow)
        #expect(copy.id != original.id)
        #expect(copyLine == justNow)
    }

    @Test("A CV that is removed leaves no time behind")
    func deletedCVLeavesNoTime() async {
        let doomed = cv(name: "A")
        let repository = InMemoryCVRepository(cvs: [doomed])
        await repository.setLastSaved(now.addingTimeInterval(-86_400), for: doomed.id)
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadCVs()

        await viewModel.deleteCV(withId: doomed.id)

        #expect(viewModel.lastSavedLine(of: doomed) == nil)
    }

    // MARK: - The clock of the list

    @Test("The last save line follows the clock when the presentation date is refreshed, with no new listing")
    func lastSavedLineFollowsTheClock() async {
        let saved = cv(name: "A")
        let savedAt = moment(14, 12)
        let repository = InMemoryCVRepository(cvs: [saved])
        await repository.setLastSaved(savedAt, for: saved.id)
        let clock = TestClock(savedAt.addingTimeInterval(30))
        let viewModel = makeViewModel(repository: repository, clock: clock)
        await viewModel.loadCVs()
        let justNow = viewModel.lastSavedLine(of: saved)

        clock.advance(by: 5 * 60)
        let beforeRefresh = viewModel.lastSavedLine(of: saved)
        viewModel.refreshPresentationDate()
        let minutesLater = viewModel.lastSavedLine(of: saved)
        clock.advance(by: 3 * 3_600)
        viewModel.refreshPresentationDate()
        let hoursLater = viewModel.lastSavedLine(of: saved)

        #expect(justNow == "cv.list.edited_just_now".localized)
        #expect(beforeRefresh == justNow, "The text changes when the clock the list shows is refreshed, not when it is asked for")
        #expect(minutesLater == line(saved: savedAt, at: savedAt.addingTimeInterval(30 + 5 * 60)))
        #expect(hoursLater == line(saved: savedAt, at: savedAt.addingTimeInterval(30 + 5 * 60 + 3 * 3_600)))
        #expect(Set([justNow, minutesLater, hoursLater].compactMap { $0 }).count == 3)
    }

    @Test("Coming back to the foreground tells the times of the rows again; leaving it does not")
    func foregroundTellsTheTimesAgain() async {
        let saved = cv(name: "A")
        let savedAt = moment(14, 12)
        let repository = InMemoryCVRepository(cvs: [saved])
        await repository.setLastSaved(savedAt, for: saved.id)
        let clock = TestClock(savedAt.addingTimeInterval(30))
        let viewModel = makeViewModel(repository: repository, clock: clock)
        await viewModel.loadCVs()
        let justNow = viewModel.lastSavedLine(of: saved)

        clock.advance(by: 2 * 3_600)
        viewModel.sceneDidChange(isActive: false)
        #expect(viewModel.lastSavedLine(of: saved) == justNow, "Leaving the foreground moves nothing")

        viewModel.sceneDidChange(isActive: true)
        #expect(viewModel.lastSavedLine(of: saved) == line(saved: savedAt, at: savedAt.addingTimeInterval(30 + 2 * 3_600)))
    }

    @Test("A CV saved in the evening reads yesterday once the clock passes midnight")
    func eveningSaveReadsYesterdayAfterMidnight() async {
        let saved = cv(name: "A")
        let savedAt = moment(14, 22, 30)
        let repository = InMemoryCVRepository(cvs: [saved])
        await repository.setLastSaved(savedAt, for: saved.id)
        let clock = TestClock(moment(14, 23, 0))
        let viewModel = makeViewModel(repository: repository, clock: clock)
        await viewModel.loadCVs()
        let beforeMidnight = viewModel.lastSavedLine(of: saved)

        clock.advance(by: 90 * 60)
        viewModel.refreshPresentationDate()

        #expect(beforeMidnight == line(saved: savedAt, at: moment(14, 23, 0)))
        #expect(viewModel.lastSavedLine(of: saved) == line(saved: savedAt, at: moment(15, 0, 30)))
        #expect(viewModel.lastSavedLine(of: saved) != beforeMidnight)
    }

    @Test("A list that is back on screen several days later reads the days that went by")
    func resumeSeveralDaysLater() async {
        let saved = cv(name: "A")
        let savedAt = moment(10, 9)
        let repository = InMemoryCVRepository(cvs: [saved])
        await repository.setLastSaved(savedAt, for: saved.id)
        let clock = TestClock(moment(10, 9, 5))
        let viewModel = makeViewModel(repository: repository, clock: clock)
        await viewModel.loadCVs()

        clock.advance(by: 3 * 86_400 + 4 * 3_600)
        viewModel.refreshPresentationDate()

        #expect(viewModel.lastSavedLine(of: saved) == line(saved: savedAt, at: moment(13, 13, 5)))
    }

    @Test("Reading the list again brings the time of its rows up to date")
    func loadingBringsTheTimeUpToDate() async {
        let saved = cv(name: "A")
        let savedAt = moment(14, 12)
        let repository = InMemoryCVRepository(cvs: [saved])
        await repository.setLastSaved(savedAt, for: saved.id)
        let clock = TestClock(savedAt)
        let viewModel = makeViewModel(repository: repository, clock: clock)
        await viewModel.loadCVs()

        clock.advance(by: 2 * 86_400)
        await viewModel.loadCVs()

        #expect(viewModel.lastSavedLine(of: saved) == line(saved: savedAt, at: savedAt.addingTimeInterval(2 * 86_400)))
    }

    @Test("A change of the time zone moves the days of the rows with it, and not only the clock")
    func timeZoneChangeMovesTheDays() async {
        let saved = cv(name: "A")
        let savedAt = moment(14, 23)
        let repository = InMemoryCVRepository(cvs: [saved])
        await repository.setLastSaved(savedAt, for: saved.id)
        let clock = TestClock(moment(14, 23, 10))
        let zone = TestZone("UTC")
        let viewModel = makeViewModel(repository: repository, clock: clock, calendar: { zone.calendar })
        await viewModel.loadCVs()
        clock.advance(by: 2 * 3_600 - 10 * 60)

        viewModel.refreshPresentationDate()
        let inTheOldZone = viewModel.lastSavedLine(of: saved)
        zone.change(to: "America/Los_Angeles")
        viewModel.refreshPresentationDate()
        let inTheNewZone = viewModel.lastSavedLine(of: saved)

        #expect(inTheOldZone == line(saved: savedAt, at: moment(15, 1), zone: "UTC"))
        #expect(inTheNewZone == line(saved: savedAt, at: moment(15, 1), zone: "America/Los_Angeles"))
        #expect(inTheNewZone != inTheOldZone, "Both moments are on the same local day in Los Angeles: hours went by, not a day")
    }

    @Test("While the list is shown, the clock ticks once a minute")
    func clockTicksOnceAMinute() async {
        let saved = cv(name: "A")
        let savedAt = moment(14, 12)
        let repository = InMemoryCVRepository(cvs: [saved])
        await repository.setLastSaved(savedAt, for: saved.id)
        let clock = TestClock(savedAt)
        let waits = WaitLog()
        let viewModel = makeViewModel(repository: repository, clock: clock, sleep: { duration in
            await waits.record(duration)
            guard await waits.count <= 3 else { throw CancellationError() }
            clock.advance(by: 60)
        })
        await viewModel.loadCVs()

        await viewModel.keepPresentationDateCurrent()

        #expect(await waits.durations == Array(repeating: .seconds(60), count: 4))
        #expect(viewModel.lastSavedLine(of: saved) == line(saved: savedAt, at: savedAt.addingTimeInterval(3 * 60)))
    }
}

// MARK: - Test Doubles

/// A clock that only moves when a test moves it.
private final class TestClock: @unchecked Sendable {
    private var current: Date

    init(_ start: Date) {
        current = start
    }

    func now() -> Date {
        current
    }

    func advance(by interval: TimeInterval) {
        current = current.addingTimeInterval(interval)
    }
}

/// A time zone that a test can change, as a person does by travelling or by setting the device.
private final class TestZone: @unchecked Sendable {
    private var identifier: String

    init(_ identifier: String) {
        self.identifier = identifier
    }

    func change(to identifier: String) {
        self.identifier = identifier
    }

    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        return calendar
    }
}

/// The waits that the clock of the list asked for.
private actor WaitLog {
    private(set) var durations: [Duration] = []

    var count: Int {
        durations.count
    }

    func record(_ duration: Duration) {
        durations.append(duration)
    }
}
