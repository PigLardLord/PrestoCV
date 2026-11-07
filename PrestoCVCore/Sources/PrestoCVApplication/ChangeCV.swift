import Foundation
import PrestoCVDomain

/// Changes the look or the document language of a CV and stores it, like any other save: only at the revision the caller
/// saw, so that a change never undoes what another window saved (`AuthoringError.conflict`).
///
/// It stores the choice and does not check that the design exists: resolving a choice into a design is the catalog's job.
/// A change that leaves the CV as it is writes nothing and returns the CV.
public struct ChangeCV: Sendable {
    let save: SaveCV
    public init(repository: any CVRepository) { save = SaveCV(repository: repository) }

    /// - Returns: The CV with the look changed as `change` says, as stored.
    public func look(of cv: CV, _ change: LookChange) async throws(AuthoringError) -> CV {
        var changed = cv
        changed.choose(design: change.applying(to: cv.design))
        return try await storing(changed, replacing: cv)
    }

    /// - Parameter language: The tag the document is written in, or nil to follow the CV's text (automatic).
    public func documentLanguage(of cv: CV, to language: DocumentLanguage?) async throws(AuthoringError) -> CV {
        var changed = cv
        changed.setLanguage(language)
        return try await storing(changed, replacing: cv)
    }

    private func storing(_ changed: CV, replacing cv: CV) async throws(AuthoringError) -> CV {
        guard changed != cv else { return cv }
        return try await save(changed)
    }
}
