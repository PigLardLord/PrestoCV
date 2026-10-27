import DiagnosticLogging
import Foundation

/// Use case for generating CVs: it checks the request, asks the service, removes whatever the
/// description does not support, has the claim check judge the personal items left, lists the jobs in the order of a CV
/// and checks the answer. It logs each step as counts, names and times, never the text (ADR 0030).
@MainActor
public final class CVGeneratorUseCase {
    private let service: CVGenerationService
    private let claimChecker: ClaimChecking
    private let validator: CVValidator
    private let sanitizer: CVDataSanitizer
    private let log: DraftLog
    private let clock: any Clock<Duration>
    /// The availability last logged, so that a caller that asks again while the model downloads logs only a change.
    private var loggedAvailability: AIAvailability?

    /// - Parameters:
    ///   - claimChecker: The second check of the personal items a grounded draft keeps (ADR 0028). It can only withdraw.
    ///   - logger: Where the steps of a draft are logged (ADR 0030).
    ///   - clock: What times a draft, from the request to the model to its end.
    public init(
        service: CVGenerationService,
        claimChecker: ClaimChecking,
        logger: any DiagnosticLogger,
        clock: any Clock<Duration>,
        validator: CVValidator = DefaultCVValidator(),
        sanitizer: CVDataSanitizer = CVDataSanitizer()
    ) {
        self.service = service
        self.claimChecker = claimChecker
        self.validator = validator
        self.sanitizer = sanitizer
        self.log = DraftLog(logger: logger)
        self.clock = clock
    }

    /// Whether CV generation can run now, and the reason when it cannot
    public func availability() -> AIAvailability {
        let availability = service.availability()
        if availability != loggedAvailability {
            loggedAvailability = availability
            log.availability(availability)
        }
        return availability
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
            log.unavailable(reason)
            throw CVGenerationError.unavailable(reason)
        }

        do {
            try validator.validateRequest(request)
        } catch {
            log.rejected(check: .request, by: error)
            throw error
        }
        let language = sanitizer.languageCheck(of: request.userPrompt)
        log.language(language)
        do {
            try language.require()
        } catch {
            log.rejected(check: .language, by: error)
            throw error
        }

        log.started(characters: request.userPrompt.count)
        let stopwatch = Stopwatch(started: self.clock)
        var stage = DraftLog.Stage.model
        do {
            let generated = try await service.generateCV(from: request)
            stage = .grounding
            let grounded = try sanitizer.sanitize(generated, against: request.userPrompt)
            stage = .claimCheck
            let checked = try await ClaimWithdrawal.checking(grounded, in: request.userPrompt, with: claimChecker)
            log.claims(of: grounded, checked: checked, in: request.userPrompt)
            stage = .result
            let cvData = JobOrder.ordered(checked.cvData)

            // A check that gave no answer withdrew every personal item itself, and says so: the person adds them by hand, so the
            // draft is judged on what the rules kept, never on what is left. A check that ran and withdrew everything leaves a draft
            // that says nothing about the writer, and that is an empty result (ADR 0028).
            try validator.validateCVData(checked.personalItemsUnchecked ? grounded : cvData)

            log.finished(elapsed: stopwatch.elapsed)
            return GeneratedDraft(cvData: cvData, personalItemsUnchecked: checked.personalItemsUnchecked)
        } catch {
            log.stopped(at: stage, by: error, elapsed: stopwatch.elapsed)
            throw error
        }
    }
}
