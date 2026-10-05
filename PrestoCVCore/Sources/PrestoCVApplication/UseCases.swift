import Foundation
import PrestoCVDomain

/// A new, unsaved CV with a fresh identity.
public struct NewCV: Sendable {
    let ids: any IDGenerator

    /// - Parameter ids: Where the identity of each new CV comes from.
    public init(ids: any IDGenerator) { self.ids = ids }

    /// - Returns: A CV with no content, at revision 0.
    public func callAsFunction() -> CV { CV(id: ids.next()) }
}

/// Saves a CV: create when never saved, conditional update otherwise.
public struct SaveCV: Sendable {
    let repository: any CVRepository

    /// - Parameter repository: The store the CV is saved in.
    public init(repository: any CVRepository) { self.repository = repository }

    /// - Parameter cv: The CV to save, at the revision the caller last saw.
    /// - Returns: The stored CV, with its new revision and timestamps.
    /// - Throws: `AuthoringError.notEnoughContent` when the CV cannot be saved yet; `.conflict` when the stored revision is
    ///   not the one the caller saw; `.deletedElsewhere` when the CV is gone; `.tooLarge` when its file would exceed the
    ///   size cap; `.unavailable` for any other failure of the store.
    public func callAsFunction(_ cv: CV) async throws(AuthoringError) -> CV {
        guard cv.canBeSaved else { throw .notEnoughContent }
        do throws(RepositoryError) { return try await store(cv) } catch { throw AuthoringError(error) }
    }

    private func store(_ cv: CV) async throws(RepositoryError) -> CV {
        if cv.revision == 0 { return try await repository.create(cv) }
        return try await repository.update(cv)
    }
}

/// Loads a stored CV.
public struct LoadCV: Sendable {
    let repository: any CVRepository

    /// - Parameter repository: The store the CV is loaded from.
    public init(repository: any CVRepository) { self.repository = repository }

    /// - Parameter id: The identity of the CV, from a listing.
    /// - Throws: `AuthoringError.deletedElsewhere` when the CV is gone; `.unavailable` when the store cannot be read.
    public func callAsFunction(_ id: CVID) async throws(AuthoringError) -> CV {
        do throws(RepositoryError) { return try await repository.load(id) } catch { throw AuthoringError(error) }
    }
}

/// The healthy CVs, most recently changed first, and every issue the store found.
public struct ListCVs: Sendable {
    let repository: any CVRepository

    /// - Parameter repository: The store that is listed.
    public init(repository: any CVRepository) { self.repository = repository }

    /// - Throws: `AuthoringError.unavailable` when the store itself cannot be listed. A file that cannot be read is an issue
    ///   of the listing, not a failure.
    public func callAsFunction() async throws(AuthoringError) -> CVListing {
        do throws(RepositoryError) { return try await repository.list() } catch { throw AuthoringError(error) }
    }
}

/// Renames a stored CV: a conditional update, so a rename never overwrites another window's changes.
public struct RenameCV: Sendable {
    let save: SaveCV

    /// - Parameter repository: The store the CV is saved in.
    public init(repository: any CVRepository) { save = SaveCV(repository: repository) }

    /// - Parameters:
    ///   - cv: The stored CV, at the revision the caller last saw.
    ///   - title: The new title.
    /// - Returns: The stored CV with its new title.
    /// - Throws: The errors of `SaveCV`.
    public func callAsFunction(_ cv: CV, to title: String) async throws(AuthoringError) -> CV {
        var renamed = cv
        renamed.rename(title)
        return try await save(renamed)
    }
}

/// Stores a copy of a CV under a new identity. The title is composed by presentation (LocalisationAtEdges).
public struct DuplicateCV: Sendable {
    let ids: any IDGenerator
    let save: SaveCV

    /// - Parameters:
    ///   - repository: The store the copy is saved in.
    ///   - ids: Where the identity of the copy comes from.
    public init(repository: any CVRepository, ids: any IDGenerator) { self.ids = ids; save = SaveCV(repository: repository) }

    /// - Parameters:
    ///   - cv: The CV to copy.
    ///   - title: The title of the copy.
    /// - Returns: The stored copy, at revision 1.
    /// - Throws: The errors of `SaveCV`.
    public func callAsFunction(_ cv: CV, title: String) async throws(AuthoringError) -> CV {
        try await save(cv.duplicated(as: ids.next(), title: title))
    }
}

/// Deletes the CV only if it is still at the revision the caller saw.
public struct DeleteCV: Sendable {
    let repository: any CVRepository

    /// - Parameter repository: The store the CV is deleted from.
    public init(repository: any CVRepository) { self.repository = repository }

    /// - Parameter cv: The CV to delete, at the revision the caller last saw.
    /// - Throws: `AuthoringError.conflict` when the stored revision is not the one the caller saw; `.deletedElsewhere` when
    ///   the CV is already gone; `.unavailable` for any other failure of the store.
    public func callAsFunction(_ cv: CV) async throws(AuthoringError) {
        do throws(RepositoryError) { try await repository.delete(cv.id, revision: cv.revision) } catch { throw AuthoringError(error) }
    }
}

/// An unsaved CV with the content of a sample and a fresh identity. Nothing is stored until the user saves.
public struct StartFromSample: Sendable {
    let samples: any SampleCVSource
    let ids: any IDGenerator

    /// - Parameters:
    ///   - samples: Where the samples come from.
    ///   - ids: Where the identity of a started CV comes from.
    public init(samples: any SampleCVSource, ids: any IDGenerator) { self.samples = samples; self.ids = ids }

    /// - Returns: The samples to offer.
    /// - Throws: `AuthoringError.unavailable` when a sample cannot be used.
    public func available() async throws(AuthoringError) -> [CV] {
        do throws(RepositoryError) { return try await samples.samples() } catch { throw AuthoringError(error) }
    }

    /// - Parameter sample: One of the samples offered.
    /// - Returns: An unsaved CV with the content of `sample` and a fresh identity.
    public func callAsFunction(_ sample: CV) -> CV { sample.duplicated(as: ids.next(), title: sample.title) }
}

/// First run is when the store holds nothing at all: no CV and no file with an issue, so data that
/// could not be read never makes the app look empty.
public enum OnboardingState: Equatable, Sendable { case firstRun, returning }

/// Tells whether the app is on its first run.
public struct DetermineOnboarding: Sendable {
    let list: ListCVs

    /// - Parameter repository: The store that is looked at.
    public init(repository: any CVRepository) { list = ListCVs(repository: repository) }

    /// - Throws: `AuthoringError.unavailable` when the store cannot be listed.
    public func callAsFunction() async throws(AuthoringError) -> OnboardingState {
        let listing = try await list()
        return listing.cvs.isEmpty && listing.issues.isEmpty ? .firstRun : .returning
    }
}
