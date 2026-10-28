import DiagnosticLogging
import DiagnosticTrace
import Foundation

/// Use case for generating CVs: it checks the request, asks the service, removes whatever the
/// description does not support, has the claim check judge the personal items left, lists the jobs in the order of a CV
/// and checks the answer. It logs each step as counts, names and times, never the text (ADR 0030), and records each step with its
/// text in the trace, which only a test build keeps (ADR 0032).
@MainActor
public final class CVGeneratorUseCase {
    private let service: CVGenerationService
    private let claimChecker: ClaimChecking
    private let validator: CVValidator
    private let sanitizer: CVDataSanitizer
    private let log: DraftLog
    private let tracer: any DiagnosticTracer
    private let clock: any Clock<Duration>
    /// The availability last logged, so that a caller that asks again while the model downloads logs only a change.
    private var loggedAvailability: AIAvailability?

    /// - Parameters:
    ///   - claimChecker: The second check of the personal items a grounded draft keeps (ADR 0028). It can only withdraw.
    ///   - logger: Where the steps of a draft are logged (ADR 0030).
    ///   - clock: What times a draft and each of its stages, from the request to the model to its end.
    ///   - tracer: Where each step of a draft is recorded with its text (ADR 0032).
    public init(
        service: CVGenerationService,
        claimChecker: ClaimChecking,
        logger: any DiagnosticLogger,
        clock: any Clock<Duration>,
        tracer: any DiagnosticTracer,
        validator: CVValidator = DefaultCVValidator(),
        sanitizer: CVDataSanitizer = CVDataSanitizer()
    ) {
        self.service = service
        self.claimChecker = claimChecker
        self.validator = validator
        self.sanitizer = sanitizer
        self.log = DraftLog(logger: logger)
        self.tracer = tracer
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
        let trace = DraftTrace(tracer: tracer)
        // The model service and the logger record by kind: the scope tells them which draft they work for when a cancelled
        // draft and its retry are both in flight.
        return try await trace.within { try await generate(from: request, trace: trace) }
    }

    private func generate(from request: CVGenerationRequest, trace: DraftTrace) async throws -> GeneratedDraft {
        trace.input(request)
        let availability = service.availability()
        trace.availability(availability)
        if case .unavailable(let reason) = availability {
            log.unavailable(reason)
            trace.unavailable(reason)
            throw CVGenerationError.unavailable(reason)
        }

        do {
            try validator.validateRequest(request)
        } catch {
            log.rejected(check: .request, by: error)
            trace.rejected(check: .request, by: error)
            throw error
        }
        let language = sanitizer.languageCheck(of: request.userPrompt)
        log.language(language)
        trace.languageData(language)
        do {
            try language.require()
        } catch {
            log.rejected(check: .language, by: error)
            trace.rejected(check: .language, by: error)
            throw error
        }

        log.started(characters: request.userPrompt.count)
        var timing = DraftTiming(clock: clock)
        var stage = DraftLog.Stage.model
        do {
            let generated = try await service.generateCV(from: request)
            trace.stage(.model, gave: generated, from: nil)
            timing.lap(.model)
            stage = .grounding
            let grounded = try sanitizer.sanitize(generated, against: request.userPrompt)
            trace.stage(.grounding, gave: grounded, from: generated)
            timing.lap(.grounding)
            stage = .claimCheck
            let report = try await ClaimWithdrawal.report(on: grounded, in: request.userPrompt, with: claimChecker)
            let checked = report.draft
            log.claims(of: grounded, checked: checked)
            trace.claims(report)
            trace.stage(.claimCheck, gave: checked.cvData, from: grounded)
            timing.lap(.claimCheck)
            stage = .result
            let cvData = JobOrder.ordered(checked.cvData)
            trace.stage(.result, gave: cvData, from: checked.cvData)

            // A check that gave no answer withdrew every personal item itself, and says so: the person adds them by hand, so the
            // draft is judged on what the rules kept, never on what is left. A check that ran and withdrew everything leaves a draft
            // that says nothing about the writer, and that is an empty result (ADR 0028).
            try validator.validateCVData(checked.personalItemsUnchecked ? grounded : cvData)
            timing.lap(.result)

            let draft = GeneratedDraft(cvData: cvData, personalItemsUnchecked: checked.personalItemsUnchecked)
            log.finished(elapsed: timing.elapsed)
            trace.finished(draft, timing: timing)
            return draft
        } catch {
            log.stopped(at: stage, by: error, elapsed: timing.stop())
            trace.stopped(at: stage, by: error, timing: timing)
            throw error
        }
    }
}
