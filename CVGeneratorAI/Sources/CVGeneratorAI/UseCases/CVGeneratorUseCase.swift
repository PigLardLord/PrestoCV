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
    ///   claim check that fails, refuses or runs out of time throws nothing: the draft comes back without its personal items, even
    ///   if that leaves it empty (ADR 0028).
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

        // A check that gave no answer withdrew every personal item itself, and says so: the person adds them by hand, so the draft
        // is judged on what the rules kept, never on what is left. A check that ran and withdrew everything leaves a draft that
        // says nothing about the writer, and that is an empty result (ADR 0028).
        try validator.validateCVData(checked.personalItemsUnchecked ? grounded : cvData)

        return GeneratedDraft(cvData: cvData, personalItemsUnchecked: checked.personalItemsUnchecked)
    }
}
