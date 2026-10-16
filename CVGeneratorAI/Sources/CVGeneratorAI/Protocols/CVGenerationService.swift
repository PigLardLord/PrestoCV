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
}
