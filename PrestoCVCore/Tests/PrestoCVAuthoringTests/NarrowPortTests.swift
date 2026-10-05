import Testing
import Foundation
import PrestoCVDomain
import PrestoCVApplication
import PrestoCVCoreTestSupport

/// Each double implements only the port its use case calls, so these tests compile only while a use case asks no more.
private struct OnlySaves: CVSaver {
    func create(_ cv: CV) async throws(RepositoryError) -> CV { cv.stored(revision: 1, at: Date(timeIntervalSince1970: 1)) }
    func update(_ cv: CV) async throws(RepositoryError) -> CV { cv.stored(revision: cv.revision + 1, at: Date(timeIntervalSince1970: 2)) }
}

private struct OnlyLoads: CVLoader {
    func load(_ id: CVID) async throws(RepositoryError) -> CV { CV(id: id, personal: PersonalDetails(fullName: "Loaded")) }
}

private struct OnlyLists: CVLister {
    func list() async throws(RepositoryError) -> CVListing { CVListing(cvs: [], issues: []) }
}

private struct OnlyDeletes: CVDeleter {
    func delete(_ id: CVID, revision: Int) async throws(RepositoryError) {}
}

@Suite("ISP · a use case depends only on the port it calls")
struct NarrowPortTests {
    @Test("saving, renaming and duplicating need only a saver")
    func saver() async throws {
        let saved = try await SaveCV(repository: OnlySaves())(named("Ada"))
        #expect(saved.revision == 1)
        #expect(try await RenameCV(repository: OnlySaves())(saved, to: "New").revision == 2)
        #expect(try await DuplicateCV(repository: OnlySaves(), ids: SequentialIDGenerator())(saved, title: "Copy").revision == 1)
    }

    @Test("loading needs only a loader")
    func loader() async throws {
        #expect(try await LoadCV(repository: OnlyLoads())(id1).personal.fullName == "Loaded")
    }

    @Test("listing and the onboarding question need only a lister")
    func lister() async throws {
        #expect(try await ListCVs(repository: OnlyLists())().cvs.isEmpty)
        #expect(try await DetermineOnboarding(repository: OnlyLists())() == .firstRun)
    }

    @Test("deleting needs only a deleter")
    func deleter() async throws {
        try await DeleteCV(repository: OnlyDeletes())(named("Ada"))
    }
}
