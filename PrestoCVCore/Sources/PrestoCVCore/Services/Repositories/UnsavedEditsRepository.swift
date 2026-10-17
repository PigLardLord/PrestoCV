import Foundation

/// Keeps each editing's unsaved edits in a file of its own, in a storage of its own: the storage of the CVs reads
/// every file it holds as a CV.
public final class UnsavedEditsRepository: UnsavedEditsRepositoryProtocol, Sendable {
    private let storageService: StorageServiceProtocol

    public init(storageService: StorageServiceProtocol) {
        self.storageService = storageService
    }

    public func keep(_ edits: UnsavedEdits) async throws {
        try await storageService.save(edits, to: Self.identifier(for: edits.id))
    }

    public func allKept() async throws -> [UnsavedEdits] {
        try await storageService.loadAll(UnsavedEdits.self)
    }

    public func kept(editing id: UUID) async throws -> UnsavedEdits? {
        try await storageService.load(UnsavedEdits.self, from: Self.identifier(for: id))
    }

    public func discard(editing id: UUID) async throws {
        try await storageService.delete(identifier: Self.identifier(for: id))
    }

    /// The file name an editing's edits are kept under.
    static func identifier(for id: UUID) -> String {
        "edits_\(id.uuidString)"
    }
}
