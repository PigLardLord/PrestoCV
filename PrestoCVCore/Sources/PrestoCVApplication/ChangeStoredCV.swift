import Foundation
import PrestoCVDomain

/// The stored CVs, as `ChangeStoredCV` reads and writes them (R3: the port belongs to its use case). A CV is a `Record`
/// of the store's own shape, which the store also knows how to change. The app's stored CVs implement it until the
/// migration replaces them with `CVRepository`.
///
/// Its errors reach the caller unchanged: the use case adds only `StoredCVChangeError`.
public protocol StoredCVs<Record>: Sendable {
    associatedtype Record: Sendable
    /// The CV stored under `id`; nil when there is none.
    func load(_ id: UUID) async throws -> Record?
    /// Stores `cv` in place of the CV stored under its identity, and returns it as stored.
    func update(_ cv: Record) async throws -> Record
    /// `cv` with another title.
    func renaming(_ cv: Record, to title: String) -> Record
    /// `cv` with another language for its PDF, as a BCP 47 tag; nil is automatic.
    func settingDocumentLanguage(of cv: Record, to tag: String?) -> Record
    /// `cv` with its look for its PDF changed as `change` says: the parts the person chose are set, and the others are
    /// left as the CV holds them.
    func settingLook(of cv: Record, to change: LookChange) -> Record
}

public enum StoredCVChangeError: Error, Equatable, Sendable {
    /// No CV is stored under the identity any more: it was deleted meanwhile.
    case notFound
}

/// Changes one field of a stored CV, and nothing else: the CV is read again just before it is stored, so that the change
/// does not undo what was saved meanwhile, as another window can. What the change is made on, and whether it changes
/// anything, is decided on that CV, never on one the caller saw earlier.
public struct ChangeStoredCV<Record: Sendable & Equatable>: Sendable {
    private let cvs: any StoredCVs<Record>

    public init(cvs: any StoredCVs<Record>) {
        self.cvs = cvs
    }

    /// Gives a stored CV a new title. The title is trimmed; a blank one changes nothing.
    /// - Returns: The CV as stored, or nil when the title is blank and nothing changed.
    public func rename(_ id: UUID, to title: String) async throws -> Record? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return try await change(id) { cvs.renaming($0, to: trimmed) }
    }

    /// Sets the language of a stored CV's PDF, as a BCP 47 tag; nil is automatic.
    /// - Returns: The CV as stored.
    public func setDocumentLanguage(_ tag: String?, of id: UUID) async throws -> Record {
        try await change(id) { cvs.settingDocumentLanguage(of: $0, to: tag) }
    }

    /// Changes the design, palette or font a stored CV's PDF is made with: the parts the person chose, and no other.
    /// Choosing the look the CV has already is no change: the CV as stored now is the judge, and nothing is stored.
    /// - Returns: The CV as stored, or nil when it has that look already and nothing changed.
    public func setLook(_ lookChange: LookChange, of id: UUID) async throws -> Record? {
        let stored = try await storedCV(id)
        let changed = cvs.settingLook(of: stored, to: lookChange)
        guard changed != stored else { return nil }
        return try await cvs.update(changed)
    }

    private func change(_ id: UUID, _ apply: (Record) -> Record) async throws -> Record {
        try await cvs.update(apply(try await storedCV(id)))
    }

    private func storedCV(_ id: UUID) async throws -> Record {
        guard let stored = try await cvs.load(id) else { throw StoredCVChangeError.notFound }
        return stored
    }
}
