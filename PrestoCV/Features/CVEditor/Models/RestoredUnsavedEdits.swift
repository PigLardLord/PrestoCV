import PrestoCVCore
import Synchronization

/// Edits a window took to restore, on their way to the editor that shows them, with the window's claim on them. The
/// editor takes the claim; when nobody does, as when the window closes first, the claim is let go and the edits are
/// offered again.
final class RestoredUnsavedEdits: Sendable {
    let edits: UnsavedEdits
    private let claim: Mutex<UnsavedEditsClaim?>
    private let useCase: UnsavedEditsUseCaseProtocol?

    init(edits: UnsavedEdits, claim: UnsavedEditsClaim?, useCase: UnsavedEditsUseCaseProtocol?) {
        self.edits = edits
        self.claim = Mutex(claim)
        self.useCase = useCase
    }

    deinit {
        guard let claim = takeClaim(), let useCase else { return }
        Task { await useCase.release(claim) }
    }

    /// Hands the claim over, once: to the keeper of the editor that shows the edits.
    func takeClaim() -> UnsavedEditsClaim? {
        claim.withLock { held in
            defer { held = nil }
            return held
        }
    }
}
