import DiagnosticLogging
import DiagnosticTrace
@testable import CVGeneratorAI

extension CVGeneratorUseCase {
    /// A use case that logs and traces nothing, for the tests that are about neither, with every time limit on a test clock (#413).
    convenience init(
        service: CVGenerationService, claimChecker: ClaimChecking,
        validator: CVValidator = DefaultCVValidator(), sanitizer: CVDataSanitizer = CVDataSanitizer(),
        limits: DraftingLimits = .onTestClock()
    ) {
        self.init(
            service: service, claimChecker: claimChecker, logger: SilentLogger(), clock: ContinuousClock(), tracer: NoTracer(),
            validator: validator, sanitizer: sanitizer, limits: limits
        )
    }
}
