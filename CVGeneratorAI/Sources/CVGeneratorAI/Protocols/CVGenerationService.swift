import Foundation

/// Protocol for CV generation services
/// Implementations can use different AI backends (FoundationModels, remote APIs, etc.)
/// @MainActor isolation ensures all operations stay within the same actor context, avoiding concurrency issues
@MainActor
public protocol CVGenerationService {
    /// Whether the service can generate now on this device, and the reason when it cannot
    func availability() -> AIAvailability

    /// Generate a CV from user input
    /// - Parameter request: The generation request containing the person's description
    /// - Returns: The CV data the model produced, not yet checked against the description
    /// - Throws: CVGenerationError if generation fails, or CancellationError if the task was cancelled
    func generateCV(from request: CVGenerationRequest) async throws -> CVData

    /// Write the summary, the duties of each role and the role's skills around the facts of a draft: the second pass (ADR 0031)
    /// - Parameter brief: The facts the rules kept from the first pass, without the description
    /// - Returns: What the model wrote, not yet checked; nil when the service writes nothing around the facts
    /// - Throws: CVGenerationError if generation fails, or CancellationError if the task was cancelled
    func writeDraft(for brief: DraftBrief) async throws -> DraftWriting?
}

extension CVGenerationService {
    /// A service that only extracts writes nothing around the facts: the draft keeps them alone.
    public func writeDraft(for brief: DraftBrief) async throws -> DraftWriting? { nil }
}
