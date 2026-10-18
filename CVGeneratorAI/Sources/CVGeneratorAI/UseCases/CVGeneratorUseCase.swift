import Foundation

/// Use case for generating CVs: it checks the request, asks the service, removes whatever the
/// description does not support, lists the jobs in the order of a CV and checks the answer.
@MainActor
public final class CVGeneratorUseCase {
    private let service: CVGenerationService
    private let validator: CVValidator
    private let sanitizer: CVDataSanitizer

    public init(
        service: CVGenerationService,
        validator: CVValidator = DefaultCVValidator(),
        sanitizer: CVDataSanitizer = CVDataSanitizer()
    ) {
        self.service = service
        self.validator = validator
        self.sanitizer = sanitizer
    }

    /// Whether CV generation can run now, and the reason when it cannot
    public func availability() -> AIAvailability {
        service.availability()
    }

    /// Generate and validate a CV from user input
    /// - Parameter request: The generation request
    /// - Returns: CV data limited to what the description supports, with the current job first, then the newest
    /// - Throws: CVGenerationError if the service is unavailable, the device lacks the language data that grounding the description
    ///   needs (asked before the model runs), or generation or validation fails; CancellationError if the task was cancelled
    public func generateCV(from request: CVGenerationRequest) async throws -> CVData {
        if case .unavailable(let reason) = service.availability() {
            throw CVGenerationError.unavailable(reason)
        }

        try validator.validateRequest(request)
        try sanitizer.requireLanguageData(for: request.userPrompt)

        let generated = try await service.generateCV(from: request)
        let cvData = try JobOrder.ordered(sanitizer.sanitize(generated, against: request.userPrompt))

        try validator.validateCVData(cvData)

        return cvData
    }
}
