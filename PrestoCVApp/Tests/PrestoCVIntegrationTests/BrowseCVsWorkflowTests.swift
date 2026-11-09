import Testing
import Foundation
import PrestoCVDomain
import PrestoCVApplication
import PrestoCVCoreTestSupport
import PrestoCVWorkflowPorts
@testable import PrestoCVIntegration

@Suite("Browsing the CVs")
struct BrowseCVsWorkflowTests {
    let repository = RepositorySpy()
    let ids = SequentialIDGenerator()
    let sample = FixtureCV.full(id: CVID(UUID(uuidString: "77777777-7777-7777-7777-777777777777")!))

    func workflow(samples: [CV] = []) -> BrowseCVsWorkflow {
        BrowseCVsWorkflow(repository: repository, samples: InMemorySampleCVSource(samples), ids: ids)
    }

    private func store(_ name: String) async throws -> CV {
        try await repository.create(Invented.cv(name, id: ids.next()))
    }

    @Test("the list holds the CVs, most recently changed first, and the issues of the store")
    func listReturnsCVsAndIssues() async throws {
        let older = try await store("Ada"), newer = try await store("Grace")
        let issues: [StoreIssue] = [.corrupt(file: "a.json", reason: "x"), .upgradeRequired(file: "b.json", version: 9),
                                    .unreadable(file: "c.json"), .tooLarge(file: "d.json", bytes: 99)]
        await repository.report(issues)

        let listing = try await workflow().list()

        #expect(listing.cvs.map(\.id) == [newer.id, older.id])
        #expect(listing.issues == issues)
    }

    @Test("an issue of the store does not hide the other CVs")
    func aStoreIssueDoesNotHideOtherCVs() async throws {
        let healthy = try await store("Ada")
        await repository.report([.corrupt(file: "broken.json", reason: "x")])

        let listing = try await workflow().list()

        #expect(listing.cvs == [healthy])
        #expect(listing.issues.count == 1)
    }

    @Test("a store with nothing in it is a first run")
    func emptyStoreIsFirstRun() async throws {
        #expect(try await workflow().onboarding() == .firstRun)
    }

    @Test("a store with a CV, or with only an issue, is a returning person")
    func storeWithCVsIsReturning() async throws {
        await repository.report([.unreadable(file: "c.json")])
        #expect(try await workflow().onboarding() == .returning)

        await repository.report([])
        _ = try await store("Ada")
        #expect(try await workflow().onboarding() == .returning)
    }

    /// The store reports a file it could not read on one listing only, the one that sets it aside; at launch that is the
    /// read of the first-run screen. The first-run screen and the list hold copies of one workflow.
    @Test("a file the store reported once, to the first-run screen, is in every later listing of the launch")
    func anIssueReportedOnceStaysForTheLaunch() async throws {
        let browsing = workflow()
        let firstRun: any CVBrowsing = browsing, list: any CVBrowsing = browsing
        let issue = StoreIssue.corrupt(file: "a.json", reason: "x")
        await repository.report([issue])
        #expect(try await firstRun.onboarding() == .returning)

        await repository.report([])

        #expect(try await list.list().issues == [issue])
        #expect(try await list.list().issues == [issue])
        #expect(try await firstRun.onboarding() == .returning)
    }

    @Test("a file reported again counts once, as the store last reported it, where the store first met it")
    func anIssueReportedAgainCountsOnce() async throws {
        let browsing = workflow()
        await repository.report([.unreadable(file: "c.json"), .corrupt(file: "a.json", reason: "x")])
        _ = try await browsing.list()

        await repository.report([.tooLarge(file: "c.json", bytes: 99), .unreadable(file: "d.json")])

        #expect(try await browsing.list().issues == [
            .tooLarge(file: "c.json", bytes: 99), .corrupt(file: "a.json", reason: "x"), .unreadable(file: "d.json"),
        ])
    }

    @Test("a store that cannot be read is 'unavailable', never an empty list")
    func anUnreadableStoreIsUnavailable() async {
        await repository.fail(with: .storeUnavailable(.cannotList))

        await #expect(throws: EditFailure.unavailable) { _ = try await workflow().list() }
        await #expect(throws: EditFailure.unavailable) { _ = try await workflow().onboarding() }
    }

    @Test("a sample starts as an unsaved copy under a new id, and nothing is stored")
    func samplesStartAsUnsavedCopies() async throws {
        let browse = workflow(samples: [sample])

        let offered = try await browse.samples()
        let started = browse.startFromSample(try #require(offered.first))

        #expect(offered == [sample])
        #expect(started.id != sample.id && started.revision == 0 && started.createdAt == nil)
        #expect(started.personal == sample.personal && started.sections == sample.sections && started.title == sample.title)
        #expect(await repository.writes == 0)
    }
}
