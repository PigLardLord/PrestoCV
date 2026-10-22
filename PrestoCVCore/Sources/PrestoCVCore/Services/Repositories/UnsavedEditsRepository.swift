import Foundation

/// The unsaved edits earlier versions kept, each editing's in a file of its own, in a storage of its own: the storage
/// of the CVs reads every file it holds as a CV.
public final class UnsavedEditsRepository: UnsavedEditsRepositoryProtocol, Sendable {
    private let storageService: StorageServiceProtocol
    private let marks: StorageServiceProtocol

    /// - Parameters:
    ///   - storageService: The storage of the edits.
    ///   - marks: The storage of the marks of the edits already stored: another one, so that a folder of edits that cannot
    ///     be changed, which keeps edits whose removal fails, does not stop their mark either.
    public init(storageService: StorageServiceProtocol, marks: StorageServiceProtocol) {
        self.storageService = storageService
        self.marks = marks
    }

    public func allKept() async throws -> StorageLoadReport<UnsavedEdits> {
        try await storageService.loadAllReporting(UnsavedEdits.self)
    }

    public func acknowledgeUnreadable() async throws {
        try await storageService.acknowledgeQuarantined()
    }

    public func discard(editing id: UUID) async throws {
        try await storageService.delete(identifier: Self.identifier(for: id))
    }

    public func markStored(editing id: UUID) async throws {
        try await marks.save(StoredMark(editing: id), to: Self.markIdentifier(for: id))
    }

    public func isMarkedStored(editing id: UUID) async -> Bool {
        await marks.exists(identifier: Self.markIdentifier(for: id))
    }

    /// The file name an editing's edits are kept under.
    static func identifier(for id: UUID) -> String {
        "edits_\(id.uuidString)"
    }

    /// The file name of the mark that an editing's edits are stored.
    static func markIdentifier(for id: UUID) -> String {
        "stored_\(id.uuidString)"
    }

    /// The mark that the edits of an editing are stored. Its file is what counts; what it holds names the editing again.
    private struct StoredMark: Codable, Sendable {
        let editing: UUID
    }
}
