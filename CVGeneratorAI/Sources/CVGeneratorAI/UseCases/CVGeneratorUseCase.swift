import Foundation

/// Use case for generating CVs: it checks the request, asks the service, removes whatever the
/// description does not support, has the claim check judge the personal items left, lists the jobs in the order of a CV
/// and checks the answer.
@MainActor
public final class CVGeneratorUseCase {
    private let service: CVGenerationService
    private let claimChecker: ClaimChecking
    private let validator: CVValidator
    private let sanitizer: CVDataSanitizer

    /// - Parameter claimChecker: The second check of the personal items a grounded draft keeps (ADR 0028). It can only withdraw.
    public init(
        service: CVGenerationService,
        claimChecker: ClaimChecking,
        validator: CVValidator = DefaultCVValidator(),
        sanitizer: CVDataSanitizer = CVDataSanitizer()
    ) {
        self.service = service
        self.claimChecker = claimChecker
        self.validator = validator
        self.sanitizer = sanitizer
    }

    /// Whether CV generation can run now, and the reason when it cannot
    public func availability() -> AIAvailability {
        service.availability()
    }

    /// Generate and validate a CV from user input
    /// - Parameter request: The generation request
    /// - Returns: CV data limited to what the description supports and the claim check kept, with the current job first, then the
    ///   newest; and whether the personal items were withdrawn because the check gave no answer
    /// - Throws: CVGenerationError if the service is unavailable, the device lacks the language data that grounding the description
    ///   needs (asked before the model runs), or generation or validation fails; CancellationError if the task was cancelled. A
    ///   claim check that fails or refuses throws nothing: the draft comes back without its personal items (ADR 0028).
    public func generateCV(from request: CVGenerationRequest) async throws -> GeneratedDraft {
        if case .unavailable(let reason) = service.availability() {
            throw CVGenerationError.unavailable(reason)
        }

        try validator.validateRequest(request)
        try sanitizer.requireLanguageData(for: request.userPrompt)

        let generated = try await service.generateCV(from: request)
        let grounded = try sanitizer.sanitize(generated, against: request.userPrompt)
        let checked = try await ClaimWithdrawal.checking(grounded, in: request.userPrompt, with: claimChecker)
        let cvData = JobOrder.ordered(checked.cvData)

        try validator.validateCVData(cvData)

        return GeneratedDraft(cvData: cvData, personalItemsUnchecked: checked.personalItemsUnchecked)
    }
}
