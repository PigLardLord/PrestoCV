import Foundation

/// Keeps the editor's unsaved edits, and offers to restore those that nobody holds. There is one for the whole app,
/// shared by every window: it gives each set of edits to one holder at a time, an editor or a window, and only that
/// holder changes them.
public actor UnsavedEditsUseCase: UnsavedEditsUseCaseProtocol {
    private let repository: UnsavedEditsRepositoryProtocol
    private let now: @Sendable () -> Date
    private let makeToken: @Sendable () -> UUID
    /// Who holds which editing: its token.
    private var holders: [UUID: UUID] = [:]

    /// - Parameters:
    ///   - now: The clock that dates the edits when they are kept.
    ///   - makeToken: Makes the token of each claim.
    public init(
        repository: UnsavedEditsRepositoryProtocol,
        now: @escaping @Sendable () -> Date,
        makeToken: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.repository = repository
        self.now = now
        self.makeToken = makeToken
    }

    /// The use case of the app, over the folder that holds the unsaved edits.
    /// - Throws: AppError if the folder cannot be made
    public static func inDirectory(_ directory: URL) throws -> UnsavedEditsUseCase {
        UnsavedEditsUseCase(
            repository: UnsavedEditsRepository(storageService: try FileStorageService(baseDirectory: directory)),
            now: { Date() }
        )
    }

    public func claimEditing(_ editing: UUID) async -> UnsavedEditsClaim? {
        hold(editing)
    }

    public func claim(_ edits: UnsavedEdits) async throws -> UnsavedEditsClaim? {
        // Held before the store is read, so that no other claim gets in while it is
        guard let claim = hold(edits.id) else {
            return nil
        }
        let kept: UnsavedEdits?
        do {
            kept = try await repository.kept(editing: edits.id)
        } catch {
            release(claim)
            throw error
        }
        guard kept == edits else {
            release(claim)
            return nil
        }
        return claim
    }

    public func release(_ claim: UnsavedEditsClaim) {
        guard holders[claim.editing] == claim.token else { return }
        holders[claim.editing] = nil
    }

    public func keep(_ cv: CVModel, over base: CVModel?, as claim: UnsavedEditsClaim) async throws {
        try checkHeld(claim)
        let keptAt = Date(timeIntervalSince1970: now().timeIntervalSince1970.rounded(.down))
        try await repository.keep(UnsavedEdits(id: claim.editing, cv: cv, base: base, keptAt: keptAt))
    }

    public func discard(as claim: UnsavedEditsClaim) async throws {
        try checkHeld(claim)
        try await repository.discard(editing: claim.editing)
    }

    public func editsToRestore() async throws -> UnsavedEdits? {
        try await repository.allKept()
            .filter { holders[$0.id] == nil }
            .max { ($0.keptAt, $0.id.uuidString) < ($1.keptAt, $1.id.uuidString) }
    }

    // MARK: - Private Methods

    private func hold(_ editing: UUID) -> UnsavedEditsClaim? {
        guard holders[editing] == nil else {
            return nil
        }
        let claim = UnsavedEditsClaim(editing: editing, token: makeToken())
        holders[editing] = claim.token
        return claim
    }

    private func checkHeld(_ claim: UnsavedEditsClaim) throws {
        guard holders[claim.editing] == claim.token else {
            throw UnsavedEditsError.notHeld
        }
    }
}
