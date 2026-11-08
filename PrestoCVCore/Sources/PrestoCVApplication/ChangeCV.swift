import Foundation
import PrestoCVDomain

/// Changes the look or the document language of a CV and stores it, like any other save: only at the revision the caller
/// saw, so that a change never undoes what another window saved (`AuthoringError.conflict`).
///
/// It stores the choice and does not check that the design exists: resolving a choice into a design is the catalog's job.
/// A change that leaves the CV as it is writes nothing, but still checks the stored revision: it returns the stored CV, or
/// fails with `conflict` or `deletedElsewhere` like any other change. A CV never saved (revision 0) has nothing to check.
public struct ChangeCV: Sendable {
    let repository: any CVRepository
    let save: SaveCV
    public init(repository: any CVRepository) { self.repository = repository; save = SaveCV(repository: repository) }

    /// The CV with the look changed as `change` says, nothing stored. For a CV that is not stored yet.
    public static func applying(_ change: LookChange, to cv: CV) -> CV {
        var changed = cv
        changed.choose(design: change.applying(to: cv.design))
        return changed
    }

    /// The CV with its document language set, nothing stored. For a CV that is not stored yet.
    public static func applying(language: DocumentLanguage?, to cv: CV) -> CV {
        var changed = cv
        changed.setLanguage(language)
        return changed
    }

    /// - Returns: The CV with the look changed as `change` says, as stored.
    public func look(of cv: CV, _ change: LookChange) async throws(AuthoringError) -> CV {
        try await storing(Self.applying(change, to: cv), replacing: cv)
    }

    /// - Parameter language: The tag the document is written in, or nil to follow the CV's text (automatic).
    public func documentLanguage(of cv: CV, to language: DocumentLanguage?) async throws(AuthoringError) -> CV {
        try await storing(Self.applying(language: language, to: cv), replacing: cv)
    }

    private func storing(_ changed: CV, replacing cv: CV) async throws(AuthoringError) -> CV {
        guard changed != cv else { return try await confirmed(cv) }
        return try await save(changed)
    }

    /// A change that changes nothing still answers for the revision: the store may have moved on or lost the CV.
    private func confirmed(_ cv: CV) async throws(AuthoringError) -> CV {
        guard cv.revision > 0 else { return cv }
        let stored = try await LoadCV(repository: repository)(cv.id)
        guard stored.revision == cv.revision else { throw .conflict(storedRevision: stored.revision) }
        return stored
    }
}
