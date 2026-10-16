import Foundation
import CVGeneratorAI

/// A scripted `CVGenerationService` for view model tests.
///
/// By default it answers at once. With `holdsGeneration` it keeps `generateCV` waiting until the
/// task is cancelled or the test calls `releaseOldestGeneration`, so tests can act
/// mid-generation without sleeping.
@MainActor
final class FakeCVGenerationService: CVGenerationService {
    var availabilityResult: AIAvailability = .available
    var generateResult: Result<CVData, Error> = .success(FakeCVGenerationService.sample)
    var holdsGeneration = false
    /// When false, a held generation ignores cancellation, like a model that finishes anyway.
    var honoursCancellation = true

    private(set) var generateRequests: [CVGenerationRequest] = []

    private var heldIds: [UUID] = []
    private var heldContinuations: [UUID: CheckedContinuation<CVData, Error>] = [:]
    private var waiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

    func availability() -> AIAvailability {
        availabilityResult
    }

    func generateCV(from request: CVGenerationRequest) async throws -> CVData {
        generateRequests.append(request)
        guard holdsGeneration else {
            return try generateResult.get()
        }

        let id = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                heldIds.append(id)
                heldContinuations[id] = continuation
                resumeWaiters()
                if honoursCancellation && Task.isCancelled {
                    release(id, throwing: CancellationError())
                }
            }
        } onCancel: {
            Task { @MainActor in
                if self.honoursCancellation {
                    self.release(id, throwing: CancellationError())
                }
            }
        }
    }

    /// Returns once at least `count` generations are being held.
    func waitUntilGenerationsAreHeld(_ count: Int = 1) async {
        if heldIds.count >= count { return }
        await withCheckedContinuation { waiters.append((count, $0)) }
    }

    /// Ends the longest-held generation with a result.
    func releaseOldestGeneration(returning cvData: CVData) {
        guard let id = heldIds.first else { return }
        take(id)?.resume(returning: cvData)
    }

    /// Ends the longest-held generation with an error.
    func releaseOldestGeneration(throwing error: Error) {
        guard let id = heldIds.first else { return }
        release(id, throwing: error)
    }

    private func release(_ id: UUID, throwing error: Error) {
        take(id)?.resume(throwing: error)
    }

    private func take(_ id: UUID) -> CheckedContinuation<CVData, Error>? {
        heldIds.removeAll { $0 == id }
        return heldContinuations.removeValue(forKey: id)
    }

    private func resumeWaiters() {
        let ready = waiters.filter { heldIds.count >= $0.count }
        waiters.removeAll { heldIds.count >= $0.count }
        ready.forEach { $0.continuation.resume() }
    }

    static let sample = CVData(
        personalInfo: PersonalInfo(name: "John Doe"),
        summary: "An engineer.",
        experience: [Experience(title: "Engineer", company: "Tech Corp", startDate: "2020", current: true)],
        languages: [Language(name: "Italian", proficiency: .native), Language(name: "French")]
    )
}
