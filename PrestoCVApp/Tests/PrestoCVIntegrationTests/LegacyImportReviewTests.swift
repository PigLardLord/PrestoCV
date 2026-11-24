import Testing
import Foundation
import PrestoCVDomain
import PrestoCVApplication
import PrestoCVCoreTestSupport
import PrestoCVWorkflowPorts
import PrestoCVIntegration

@Suite("The report of the launch's import")
struct LegacyImportReviewTests {
    let ada = CVID(UUID()), grace = CVID(UUID()), linus = CVID(UUID()), margaret = CVID(UUID())

    /// Ada and Grace lost details, Ada and Margaret keep a period to check, Linus has nothing to tell; two files are damaged.
    func launch() async throws -> (LegacyImportReview, InMemoryLegacyStore) {
        let legacy = InMemoryLegacyStore([
            LegacyCV(cv: Invented.cv("Ada", id: ada), drops: [.look], checks: [.period]),
            LegacyCV(cv: Invented.cv("Grace", id: grace), drops: [.email], checks: []),
            LegacyCV(cv: Invented.cv("Linus", id: linus), drops: [], checks: []),
            LegacyCV(cv: Invented.cv("Margaret", id: margaret), drops: [], checks: [.period]),
        ], damaged: 2)
        let importer = ImportLegacyStore(source: legacy, target: InMemoryCVRepository())
        return (LegacyImportReview(outcome: .ran(try await importer.run()), importer: importer), legacy)
    }

    @Test("the report holds what each CV lost, apart from what it keeps to check, and counts the CVs left out by cause")
    func summary() async throws {
        let (review, _) = try await launch()
        #expect(review.summary == LegacyImportSummary(
            drops: [ada: [.look], grace: [.email]], toCheck: [ada: [.period], margaret: [.period]], leftOut: [.damaged: 2],
            didNotRun: false
        ))
    }

    @Test("removing the old copies removes those of the CVs with drops or checks and leaves the damaged files")
    func removes() async throws {
        let (review, legacy) = try await launch()
        #expect(await review.removeOldCopies(of: [ada, grace, margaret]).isEmpty)
        #expect(await legacy.names == ["damaged_0.json", "damaged_1.json"])
    }

    @Test("only the old copies of the CVs named are removed: those of the others stay")
    func removesOnlyTheNamed() async throws {
        let (review, legacy) = try await launch()
        #expect(await review.removeOldCopies(of: [ada, linus]).isEmpty)
        let left = [grace, margaret].map(InMemoryLegacyStore.name(of:)) + ["damaged_0.json", "damaged_1.json"]
        #expect(await legacy.names == left.sorted())
    }

    @Test("an old copy that cannot be removed stays, and its CV is given back")
    func keepsWhatItCannotRemove() async throws {
        let (review, legacy) = try await launch()
        await legacy.failRemoving(grace)
        #expect(await review.removeOldCopies(of: [ada, grace, margaret]) == [grace])
        #expect(await legacy.names.contains(InMemoryLegacyStore.name(of: grace)))
    }

    @Test("an import that failed did not run, and leaves every old file")
    func failed() async throws {
        let legacy = InMemoryLegacyStore([LegacyCV(cv: Invented.cv("Ada", id: ada), drops: [.look], checks: [])])
        let importer = ImportLegacyStore(source: legacy, target: InMemoryCVRepository())
        let review = LegacyImportReview(outcome: .failed(.storeUnavailable(.cannotList)), importer: importer)

        #expect(review.summary == LegacyImportSummary(drops: [:], toCheck: [:], leftOut: [:], didNotRun: true))
        #expect(await review.removeOldCopies(of: [ada]).isEmpty)
        #expect(await legacy.names == [InMemoryLegacyStore.name(of: ada)])
    }
}
