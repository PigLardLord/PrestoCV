import Foundation
import PrestoCVDomain

/// What presentation needs to know, without the port's error shape (R7).
public enum AuthoringError: Error, Equatable, Sendable {
    case notEnoughContent, conflict(storedRevision: Int), deletedElsewhere, tooLarge, unavailable
    /// A value of an application, of its letter or of the letter defaults was refused (R6): which one is the code.
    case invalid(ApplicationError)
}

/// A new, unsaved CV with a fresh identity.
public struct NewCV: Sendable {
    let ids: any IDGenerator
    public init(ids: any IDGenerator) { self.ids = ids }
    public func callAsFunction() -> CV { CV(id: ids.next()) }
}

/// Saves a CV: create when never saved, conditional update otherwise. Returns the stored CV.
public struct SaveCV: Sendable {
    let repository: any CVRepository
    public init(repository: any CVRepository) { self.repository = repository }
    public func callAsFunction(_ cv: CV) async throws(AuthoringError) -> CV {
        guard cv.canBeSaved else { throw .notEnoughContent }
        do { return cv.revision == 0 ? try await repository.create(cv) : try await repository.update(cv) }
        catch .conflict(_, let stored) { throw .conflict(storedRevision: stored) }
        catch .notFound { throw .deletedElsewhere }
        catch .wouldNotReadBack { throw .tooLarge }
        catch { throw .unavailable }
    }
}

public struct LoadCV: Sendable {
    let repository: any CVRepository
    public init(repository: any CVRepository) { self.repository = repository }
    public func callAsFunction(_ id: CVID) async throws(AuthoringError) -> CV {
        do { return try await repository.load(id) } catch .notFound { throw .deletedElsewhere } catch { throw .unavailable }
    }
}

/// The healthy CVs, most recently changed first, and every issue the store found.
public struct ListCVs: Sendable {
    let repository: any CVRepository
    public init(repository: any CVRepository) { self.repository = repository }
    public func callAsFunction() async throws(AuthoringError) -> CVListing {
        do { return try await repository.list() } catch { throw .unavailable }
    }
}

/// Renames a stored CV: a conditional update, so a rename never overwrites another window's changes.
public struct RenameCV: Sendable {
    let save: SaveCV
    public init(repository: any CVRepository) { save = SaveCV(repository: repository) }
    public func callAsFunction(_ cv: CV, to title: String) async throws(AuthoringError) -> CV {
        var renamed = cv
        renamed.rename(title)
        return try await save(renamed)
    }
}

/// Stores a copy of a CV under a new identity. The title is composed by presentation (R13).
public struct DuplicateCV: Sendable {
    let ids: any IDGenerator
    let save: SaveCV
    public init(repository: any CVRepository, ids: any IDGenerator) { self.ids = ids; save = SaveCV(repository: repository) }
    public func callAsFunction(_ cv: CV, title: String) async throws(AuthoringError) -> CV {
        try await save(cv.duplicated(as: ids.next(), title: title))
    }
}

/// Deletes the CV only if it is still at the revision the caller saw.
public struct DeleteCV: Sendable {
    let repository: any CVRepository
    public init(repository: any CVRepository) { self.repository = repository }
    public func callAsFunction(_ cv: CV) async throws(AuthoringError) {
        do { try await repository.delete(cv.id, revision: cv.revision) }
        catch .conflict(_, let stored) { throw .conflict(storedRevision: stored) }
        catch .notFound { throw .deletedElsewhere }
        catch { throw .unavailable }
    }
}

/// An unsaved CV with the content of a sample and a fresh identity. Nothing is stored until the user saves.
public struct StartFromSample: Sendable {
    let samples: any SampleCVSource
    let ids: any IDGenerator
    public init(samples: any SampleCVSource, ids: any IDGenerator) { self.samples = samples; self.ids = ids }
    public func available() async throws(AuthoringError) -> [CV] {
        do { return try await samples.samples() } catch { throw .unavailable }
    }
    public func callAsFunction(_ sample: CV) -> CV { sample.duplicated(as: ids.next(), title: sample.title) }
}

/// First run is when the store holds nothing at all: no CV and no file with an issue, so data that
/// could not be read never makes the app look empty.
public enum OnboardingState: Equatable, Sendable { case firstRun, returning }

public struct DetermineOnboarding: Sendable {
    let list: ListCVs
    public init(repository: any CVRepository) { list = ListCVs(repository: repository) }
    public func callAsFunction() async throws(AuthoringError) -> OnboardingState {
        let listing = try await list()
        return listing.cvs.isEmpty && listing.issues.isEmpty ? .firstRun : .returning
    }
}
