import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Protocol for CV generation services
/// Implementations can use different AI backends (FoundationModels, remote APIs, etc.)
/// @MainActor isolation ensures all operations stay within the same actor context, avoiding concurrency issues
@MainActor
public protocol CVGenerationService {
    /// Check if the service is available on the current device/platform
    func isAvailable() async -> Bool

    /// Generate a CV from user input
    /// - Parameter request: The generation request containing user prompt and preferences
    /// - Returns: Generated CV data with metadata
    /// - Throws: CVGenerationError if generation fails
    func generateCV(from request: CVGenerationRequest) async throws -> CVGenerationResult

    #if canImport(FoundationModels)
    /// Generate a CV with streaming support for real-time UI updates
    /// - Parameter request: The generation request containing user prompt and preferences
    /// - Returns: AsyncThrowingStream of partially generated CV data
    /// - Note: Both producer and consumer must be @MainActor isolated to ensure safe streaming
    @available(iOS 26, macOS 26, *)
    func generateCVStream(from request: CVGenerationRequest) -> AsyncThrowingStream<CVData.PartiallyGenerated, Error>
    #endif
}
