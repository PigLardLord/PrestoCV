import Foundation

/// Use case for generating CVs with validation
@MainActor
public final class CVGeneratorUseCase {
    private let service: CVGenerationService
    private let validator: CVValidator

    public init(
        service: CVGenerationService,
        validator: CVValidator = DefaultCVValidator()
    ) {
        self.service = service
        self.validator = validator
    }

    /// Check if CV generation is available
    public func isAvailable() async -> Bool {
        return await service.isAvailable()
    }

    /// Generate and validate a CV from user input
    /// - Parameter request: The generation request
    /// - Returns: Validated CV generation result
    /// - Throws: CVGenerationError if generation or validation fails
    public func generateCV(from request: CVGenerationRequest) async throws -> CVGenerationResult {
        // Validate request
        try validator.validateRequest(request)

        // Generate CV
        let result = try await service.generateCV(from: request)

        // Validate generated CV
        try validator.validateCVData(result.cvData)

        return result
    }

    #if canImport(FoundationModels)
    /// Generate CV with streaming support for real-time UI updates
    /// - Parameter request: The generation request
    /// - Returns: AsyncThrowingStream of partially generated CV data
    /// - Note: Request validation is performed before streaming begins
    @available(iOS 26, macOS 26, *)
    public func generateCVStream(from request: CVGenerationRequest) throws -> AsyncThrowingStream<CVData.PartiallyGenerated, Error> {
        // Validate request upfront
        try validator.validateRequest(request)

        // Return the service's stream directly
        return service.generateCVStream(from: request)
    }
    #endif
}
