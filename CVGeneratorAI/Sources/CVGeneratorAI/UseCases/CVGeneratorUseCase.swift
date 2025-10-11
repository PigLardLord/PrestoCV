import Foundation

/// Use case for generating CVs with validation
public final class CVGeneratorUseCase: Sendable {
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
}
