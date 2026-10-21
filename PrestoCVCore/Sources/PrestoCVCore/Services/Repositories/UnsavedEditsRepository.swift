import Foundation

/// The unsaved edits earlier versions kept, each editing's in a file of its own, in a storage of its own: the storage
/// of the CVs reads every file it holds as a CV.
public final class UnsavedEditsRepository: UnsavedEditsRepositoryProtocol, Sendable {
    private let storageService: StorageServiceProtocol

    public init(storageService: StorageServiceProtocol) {
        self.storageService = storageService
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

    /// The file name an editing's edits are kept under.
    static func identifier(for id: UUID) -> String {
        "edits_\(id.uuidString)"
    }
}
