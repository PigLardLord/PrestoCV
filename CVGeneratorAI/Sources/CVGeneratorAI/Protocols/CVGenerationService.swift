import Foundation

/// Protocol for CV generation services
/// Implementations can use different AI backends (FoundationModels, remote APIs, etc.)
public protocol CVGenerationService: Sendable {
    /// Check if the service is available on the current device/platform
    func isAvailable() async -> Bool

    /// Generate a CV from user input
    /// - Parameter request: The generation request containing user prompt and preferences
    /// - Returns: Generated CV data with metadata
    /// - Throws: CVGenerationError if generation fails
    func generateCV(from request: CVGenerationRequest) async throws -> CVGenerationResult
}
