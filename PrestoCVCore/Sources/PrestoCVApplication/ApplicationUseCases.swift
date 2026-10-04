import Foundation
import PrestoCVDomain

// MARK: - Errors, translated once at the boundary (R7)

extension AuthoringError {
    init(_ error: ApplicationError) {
        switch error {
        case .cvCannotBeSaved: self = .notEnoughContent
        case .empty, .tooLong, .tooMany, .forbiddenCharacters, .invalidReference, .overrideNotApplied, .cvIdentityChanged: self = .invalid(error)
        }
    }

    init(_ error: ApplicationRepositoryError) {
        switch error {
        case .conflict(_, let stored): self = .conflict(storedRevision: stored)
        case .notFound: self = .deletedElsewhere
        case .wouldNotReadBack: self = .tooLarge
        case .alreadyExists, .corrupt, .unreadable, .upgradeRequired, .tooLarge, .invalidName, .storeUnavailable, .writeFailed: self = .unavailable
        }
    }

    init(_ error: LetterDefaultsError) {
        switch error {
        case .conflict(let stored): self = .conflict(storedRevision: stored)
        case .corrupt: self = .corrupt
        case .upgradeRequired(_, let version): self = .upgradeRequired(version: version)
        case .wouldNotReadBack: self = .tooLarge
        case .alreadyExists, .unreadable, .tooLarge, .invalidName, .storeUnavailable, .writeFailed, .quarantineFailed: self = .unavailable
        }
    }
}

// MARK: - Use cases (ADR 0019)

/// What creating an application takes, as plain values: the tailored CV's content with no identity, its letter, the advert and
/// the provenance. `PrestoCVIntegration` maps a tailoring result to it, and the create use case gives the identities (R2).
public struct ApplicationValues: Sendable {
    public let title: String, personal: PersonalDetails, sections: CVSections, design: DesignChoice?, language: DocumentLanguage?
    public let letter: CoverLetter, advert: Advert, provenance: ApplicationProvenance

    public init(title: String, personal: PersonalDetails, sections: CVSections, design: DesignChoice?, language: DocumentLanguage?,
                letter: CoverLetter, advert: Advert, provenance: ApplicationProvenance) {
        self.title = title; self.personal = personal; self.sections = sections; self.design = design; self.language = language
        self.letter = letter; self.advert = advert; self.provenance = provenance
    }
}

/// Keeps a tailoring as an application. The identities of the application and of its CV come from the injected generator, and
/// the repository gives the revision and the times. For a job that the store already holds, it returns that application, so
/// saving a result twice leaves one (#188).
public struct CreateApplication: Sendable {
    let repository: any ApplicationRepository
    let ids: any IDGenerator
    public init(repository: any ApplicationRepository, ids: any IDGenerator) { self.repository = repository; self.ids = ids }

    public func callAsFunction(_ values: ApplicationValues) async throws(AuthoringError) -> Application {
        let cv = CV(id: ids.next(), title: values.title, personal: values.personal, sections: values.sections, design: values.design, language: values.language)
        let application: Application
        do { application = try Application(id: ids.nextApplication(), cv: cv, letter: values.letter, advert: values.advert, provenance: values.provenance) }
        catch { throw AuthoringError(error) }
        do { return try await repository.create(application) } catch { throw AuthoringError(error) }
    }
}

public struct LoadApplication: Sendable {
    let repository: any ApplicationRepository
    public init(repository: any ApplicationRepository) { self.repository = repository }
    public func callAsFunction(_ id: ApplicationID) async throws(AuthoringError) -> Application {
        do { return try await repository.load(id) } catch { throw AuthoringError(error) }
    }
}

/// The healthy applications, most recently changed first, and every issue the store found.
public struct ListApplications: Sendable {
    let repository: any ApplicationRepository
    public init(repository: any ApplicationRepository) { self.repository = repository }
    public func callAsFunction() async throws(AuthoringError) -> ApplicationListing {
        do { return try await repository.list() } catch { throw AuthoringError(error) }
    }
}

/// Keeps the edited CV of an application: a conditional update on the application's revision, which its letter shares. So an
/// edit of the CV and an edit of the letter made from the same revision conflict, and neither overwrites the other (#191).
public struct UpdateApplicationCV: Sendable {
    let repository: any ApplicationRepository
    public init(repository: any ApplicationRepository) { self.repository = repository }
    public func callAsFunction(_ application: Application, to cv: CV) async throws(AuthoringError) -> Application {
        var edited = application
        do { try edited.setCV(cv) } catch { throw AuthoringError(error) }
        do { return try await repository.update(edited) } catch { throw AuthoringError(error) }
    }
}

/// Keeps the edited letter of an application, conditional on the application's revision, as the CV is.
public struct UpdateApplicationLetter: Sendable {
    let repository: any ApplicationRepository
    public init(repository: any ApplicationRepository) { self.repository = repository }
    public func callAsFunction(_ application: Application, to letter: CoverLetter) async throws(AuthoringError) -> Application {
        var edited = application
        edited.setLetter(letter)
        do { return try await repository.update(edited) } catch { throw AuthoringError(error) }
    }
}

/// Deletes the application only if it is still at the revision the caller saw. The CV inside goes with it.
public struct DeleteApplication: Sendable {
    let repository: any ApplicationRepository
    public init(repository: any ApplicationRepository) { self.repository = repository }
    public func callAsFunction(_ application: Application) async throws(AuthoringError) {
        do { try await repository.delete(application.id, revision: application.revision) } catch { throw AuthoringError(error) }
    }
}

/// The person's letter defaults, or none yet. A store that cannot be read is an error, never empty defaults: a corrupt file
/// reports `corrupt` until the user restores the quarantined copy or saves new defaults.
public struct LoadLetterDefaults: Sendable {
    let store: any LetterDefaultsStore
    public init(store: any LetterDefaultsStore) { self.store = store }
    public func callAsFunction() async throws(AuthoringError) -> StoredLetterDefaults {
        do { return try await store.load() } catch { throw AuthoringError(error) }
    }
}

/// Saves the person's letter defaults over the ones that the caller loaded: a conditional save, so it never overwrites another
/// window's changes. An empty text for a field clears it.
public struct SaveLetterDefaults: Sendable {
    let store: any LetterDefaultsStore
    public init(store: any LetterDefaultsStore) { self.store = store }
    public func callAsFunction(_ defaults: LetterDefaults, over current: StoredLetterDefaults) async throws(AuthoringError) -> StoredLetterDefaults {
        do { return try await store.save(defaults, expectedRevision: current.revision) } catch { throw AuthoringError(error) }
    }
}
