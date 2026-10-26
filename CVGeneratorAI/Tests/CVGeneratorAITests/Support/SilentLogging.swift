import DiagnosticLogging
@testable import CVGeneratorAI

extension CVGeneratorUseCase {
    /// A use case that logs nothing, for the tests that are not about the log.
    convenience init(
        service: CVGenerationService, claimChecker: ClaimChecking,
        validator: CVValidator = DefaultCVValidator(), sanitizer: CVDataSanitizer = CVDataSanitizer()
    ) {
        self.init(
            service: service, claimChecker: claimChecker, logger: SilentLogger(), clock: ContinuousClock(),
            validator: validator, sanitizer: sanitizer
        )
    }
}
