import Foundation
import PrestoCVDomain
import PrestoCVApplication
import PrestoCVCoreTestSupport

/// The in-memory repository, with what the editing tests need besides: how many writes reached it, the issues a listing
/// reports, and a failure every call can be told to fail with.
actor RepositorySpy: CVRepository {
    private let inner = InMemoryCVRepository()
    private(set) var creates = 0, updates = 0, deletes = 0
    var issues: [StoreIssue] = []
    var failure: RepositoryError?

    func fail(with error: RepositoryError?) { failure = error }
    func report(_ issues: [StoreIssue]) { self.issues = issues }

    func create(_ cv: CV) async throws(RepositoryError) -> CV {
        creates += 1
        if let failure { throw failure }
        return try await inner.create(cv)
    }

    func update(_ cv: CV) async throws(RepositoryError) -> CV {
        updates += 1
        if let failure { throw failure }
        return try await inner.update(cv)
    }

    func load(_ id: CVID) async throws(RepositoryError) -> CV {
        if let failure { throw failure }
        return try await inner.load(id)
    }

    func list() async throws(RepositoryError) -> CVListing {
        if let failure { throw failure }
        let listing = try await inner.list()
        return CVListing(cvs: listing.cvs, issues: issues)
    }

    func delete(_ id: CVID, revision: Int) async throws(RepositoryError) {
        deletes += 1
        if let failure { throw failure }
        try await inner.delete(id, revision: revision)
    }

    /// Writes that reached the store, whatever came of them.
    var writes: Int { creates + updates + deletes }
}

enum Invented {
    static func cv(_ name: String, id: CVID) -> CV {
        CV(id: id, personal: PersonalDetails(fullName: name))
    }

    static func design(_ design: String, palette: String? = nil, fonts: String? = nil) -> DesignChoice {
        guard let choice = DesignChoice(design: design, palette: palette, fonts: fonts) else { preconditionFailure("design choice") }
        return choice
    }
}
