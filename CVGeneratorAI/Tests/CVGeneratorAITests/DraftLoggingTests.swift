import DiagnosticLogging
import DiagnosticLoggingTestSupport
import Foundation
import Testing
@testable import CVGeneratorAI

/// What the AI draft writes to the diagnostic log (ADR 0030): the availability of the model, the language of the description and
/// its data, the generation from its start to its end, the guardrails, the claims withdrawn and the rules that rejected the draft;
/// counts, names and times, and never a word of the description or of the draft.
@MainActor
@Suite("The log of the AI draft")
struct DraftLoggingTests {

    /// Every reading of the clock moves it on by this step: a generation that reads it at its start and at its end takes one.
    private static let step = Duration.milliseconds(9)

    /// An Italian description: its grounding needs no language data of the device, so the tests do not depend on the Mac's.
    private var example: FaithfulExample { faithfulExamples[1] }

    private func generator(
        _ service: FakeCVGenerationService = FakeCVGenerationService(), checker: FakeClaimChecker = FakeClaimChecker(),
        sanitizer: CVDataSanitizer = CVDataSanitizer(), logger: RecordingLogger
    ) -> CVGeneratorUseCase {
        CVGeneratorUseCase(
            service: service, claimChecker: checker, logger: logger, clock: TickingClock(step: Self.step), sanitizer: sanitizer
        )
    }

    private func drafting(_ draft: CVData) -> FakeCVGenerationService {
        let service = FakeCVGenerationService()
        service.generateResult = .success(draft)
        return service
    }

    private func failing(_ error: any Error) -> FakeCVGenerationService {
        let service = FakeCVGenerationService()
        service.generateResult = .failure(error)
        return service
    }

    // MARK: Availability

    @Test("The availability is logged when it changes, with the reason the model cannot run, as a notice")
    func availability() {
        let service = FakeCVGenerationService()
        let logger = RecordingLogger()
        let useCase = generator(service, logger: logger)

        service.availabilityResult = .unavailable(.modelNotReady)
        _ = useCase.availability()
        _ = useCase.availability()
        service.availabilityResult = .available
        _ = useCase.availability()

        let lines = logger.entries("draft.availability")
        #expect(lines.map(\.line) == ["draft.availability available=false reason=modelNotReady", "draft.availability available=true"])
        #expect(lines.map(\.level) == [.notice, .info])
        #expect(lines.allSatisfy { $0.category == LogCategory("draft") })
    }

    @Test("A draft asked for while the model cannot run logs why, as a notice, and nothing else", arguments: [
        (AIAvailability.Reason.deviceNotEligible, "deviceNotEligible"), (.appleIntelligenceNotEnabled, "appleIntelligenceNotEnabled"),
        (.modelNotReady, "modelNotReady"), (.unknown, "unknown"),
    ])
    func unavailable(reason: AIAvailability.Reason, name: String) async {
        let service = FakeCVGenerationService()
        service.availabilityResult = .unavailable(reason)
        let logger = RecordingLogger()

        await #expect(throws: CVGenerationError.unavailable(reason)) {
            try await generator(service, logger: logger).generateCV(from: CVGenerationRequest(userPrompt: example.description))
        }

        #expect(logger.events == ["draft.unavailable"])
        #expect(logger.entry("draft.unavailable")?.line == "draft.unavailable reason=\(name)")
        #expect(logger.entry("draft.unavailable")?.level == .notice)
    }

    // MARK: Language

    @Test("The language of the description is logged, with whether grounding it needs the device's language data and has it")
    func language() async throws {
        let logger = RecordingLogger()
        let present = CVDataSanitizer(lexicalClasses: ForcedLexicalTagger([.english: .words([])]))
        let other = CVDataSanitizer(languageOfText: { _ in "ja" })

        _ = try? await generator(drafting(example.draft), logger: logger).generateCV(from: CVGenerationRequest(userPrompt: example.description))
        _ = try? await generator(sanitizer: present, logger: logger)
            .generateCV(from: CVGenerationRequest(userPrompt: faithfulExamples[0].description))
        _ = try? await generator(sanitizer: other, logger: logger).generateCV(from: CVGenerationRequest(userPrompt: example.description))

        let lines = logger.entries("draft.language")
        #expect(lines.map(\.line) == [
            "draft.language supported=true language=it data=notNeeded",
            "draft.language supported=true language=en data=present",
            "draft.language supported=false data=notNeeded",
        ])
        #expect(lines.allSatisfy { $0.level == .info })
    }

    @Test("Language data the device has not got is logged as a notice, before the model is asked")
    func missingLanguageData() async {
        let logger = RecordingLogger()
        let missing = CVDataSanitizer(lexicalClasses: ForcedLexicalTagger([.german: .noAssets]))

        await #expect(throws: CVGenerationError.languageDataUnavailable(languageCode: "de")) {
            try await generator(sanitizer: missing, logger: logger).generateCV(from: CVGenerationRequest(userPrompt: faithfulExamples[2].description))
        }

        #expect(logger.events == ["draft.language"])
        #expect(logger.entry("draft.language")?.line == "draft.language supported=true language=de data=missing")
        #expect(logger.entry("draft.language")?.level == .notice)
    }

    // MARK: Generation

    @Test("A draft logs its start with the length of the description, the claims checked and its end with the time it took")
    func finished() async throws {
        let logger = RecordingLogger()
        let request = CVGenerationRequest(userPrompt: example.description)

        _ = try await generator(drafting(example.draft), logger: logger).generateCV(from: request)

        #expect(logger.events == ["draft.language", "draft.started", "draft.claims", "draft.finished"])
        #expect(logger.entry("draft.started")?.fields == [.count("characters", request.userPrompt.count)])
        #expect(logger.entry("draft.started")?.level == .info)
        #expect(logger.entry("draft.finished")?.fields == [.duration("elapsed", Self.step)])
        #expect(logger.entry("draft.finished")?.level == .info)
    }

    @Test("A cancelled draft logs the step it stopped at and the time it ran, and lets the cancellation through")
    func cancelled() async {
        let logger = RecordingLogger()
        let request = CVGenerationRequest(userPrompt: example.description)

        await #expect(throws: CancellationError.self) {
            try await generator(failing(CancellationError()), logger: logger).generateCV(from: request)
        }
        await #expect(throws: CancellationError.self) {
            try await generator(drafting(example.draft), checker: FakeClaimChecker(failure: CancellationError()), logger: logger)
                .generateCV(from: request)
        }

        let lines = logger.entries("draft.cancelled")
        #expect(lines.map(\.line) == ["draft.cancelled stage=model elapsed=9.0ms", "draft.cancelled stage=claimCheck elapsed=9.0ms"])
        #expect(lines.allSatisfy { $0.level == .info })
        #expect(!logger.events.contains("draft.finished"))
    }

    @Test("A description the model's guardrails refuse is logged as a refusal, as a notice")
    func refused() async {
        let logger = RecordingLogger()

        await #expect(throws: CVGenerationError.contentNotAllowed) {
            try await generator(failing(CVGenerationError.contentNotAllowed), logger: logger)
                .generateCV(from: CVGenerationRequest(userPrompt: example.description))
        }

        #expect(logger.events == ["draft.language", "draft.started", "draft.refused"])
        #expect(logger.entry("draft.refused")?.fields == [.duration("elapsed", Self.step)])
        #expect(logger.entry("draft.refused")?.level == .notice)
    }

    @Test("Any other failure of the model is logged by its kind, as an error")
    func failed() async {
        let logger = RecordingLogger()

        await #expect(throws: CVGenerationError.busy) {
            try await generator(failing(CVGenerationError.busy), logger: logger).generateCV(from: CVGenerationRequest(userPrompt: example.description))
        }

        let failed = logger.entry("draft.failed")
        #expect(failed?.line == "draft.failed stage=model error=CVGenerationError.busy elapsed=9.0ms")
        #expect(failed?.level == .error)
    }

    // MARK: Claims

    @Test("The claims checked and withdrawn are counted, as a notice when the check withdrew one")
    func claimsWithdrawn() async throws {
        let stances: [String: ClaimStance] = ["Bologna": .otherPerson, "inglese": .wish, "scacchi": .denied]
        let checker = FakeClaimChecker(stances: stances)
        let logger = RecordingLogger()

        _ = try await generator(drafting(example.draft), checker: checker, logger: logger).generateCV(from: CVGenerationRequest(userPrompt: example.description))

        let candidates = await checker.calls.flatMap(\.candidates)
        let withdrawn = candidates.count { stances[$0.value] != nil }
        #expect(withdrawn == 3)
        let claims = try #require(logger.entry("draft.claims"))
        #expect(claims.fields == [.count("checked", candidates.count), .count("withdrawn", withdrawn), .flag("unchecked", false)])
        #expect(claims.level == .notice)
    }

    @Test("A check that keeps every claim is counted as information")
    func claimsKept() async throws {
        let checker = FakeClaimChecker()
        let logger = RecordingLogger()

        _ = try await generator(drafting(example.draft), checker: checker, logger: logger).generateCV(from: CVGenerationRequest(userPrompt: example.description))

        let checked = await checker.calls.flatMap(\.candidates).count
        #expect(logger.entry("draft.claims")?.fields == [.count("checked", checked), .count("withdrawn", 0), .flag("unchecked", false)])
        #expect(logger.entry("draft.claims")?.level == .info)
    }

    @Test("A check that gave no answer withdrew every claim, and the log says the claims went unchecked")
    func claimsUnchecked() async throws {
        let checker = FakeClaimChecker(failure: CVGenerationError.generationFailed)
        let logger = RecordingLogger()

        _ = try await generator(drafting(example.draft), checker: checker, logger: logger).generateCV(from: CVGenerationRequest(userPrompt: example.description))

        let checked = await checker.calls.flatMap(\.candidates).count
        #expect(checked > 0)
        #expect(logger.entry("draft.claims")?.fields == [.count("checked", checked), .count("withdrawn", checked), .flag("unchecked", true)])
        #expect(logger.entry("draft.claims")?.level == .notice)
    }

    // MARK: Validation

    @Test("A description the rules reject is logged by the rule, as a notice, before the model is asked", arguments: [
        ("   ", CVGenerationError.descriptionTooShort, "descriptionTooShort"),
        (String(repeating: "a", count: CVGenerationLimits.maximumDescriptionLength + 1), .descriptionTooLong, "descriptionTooLong"),
    ])
    func rejectedRequest(description: String, error: CVGenerationError, code: String) async {
        let logger = RecordingLogger()

        await #expect(throws: error) {
            try await generator(logger: logger).generateCV(from: CVGenerationRequest(userPrompt: description))
        }

        #expect(logger.events == ["draft.rejected"])
        #expect(logger.entry("draft.rejected")?.line == "draft.rejected check=request error=CVGenerationError.\(code)")
        #expect(logger.entry("draft.rejected")?.level == .notice)
    }

    @Test("A draft the rules leave empty is logged as rejected by the check of the result, as a notice")
    func rejectedResult() async {
        let logger = RecordingLogger()

        await #expect(throws: CVGenerationError.emptyResult) {
            try await generator(drafting(CVData(personalInfo: PersonalInfo(name: "Someone Else"))), logger: logger)
                .generateCV(from: CVGenerationRequest(userPrompt: example.description))
        }

        #expect(logger.entry("draft.rejected")?.line == "draft.rejected check=result error=CVGenerationError.emptyResult elapsed=9.0ms")
        #expect(logger.entry("draft.rejected")?.level == .notice)
        #expect(!logger.events.contains("draft.failed"))
        #expect(!logger.events.contains("draft.finished"))
    }

    // MARK: Names

    @Test("Every failure, reason and language is logged by its name")
    func names() {
        let errors: [CVGenerationError] = [
            .unavailable(.unknown), .descriptionTooShort, .descriptionTooLong, .contentNotAllowed, .unsupportedLanguage, .busy,
            .generationFailed, .serviceFailed, .emptyResult, .languageDataUnavailable(languageCode: "en"),
        ]
        #expect(errors.map(\.logCode.description) == [
            "unavailable", "descriptionTooShort", "descriptionTooLong", "contentNotAllowed", "unsupportedLanguage", "busy",
            "generationFailed", "serviceFailed", "emptyResult", "languageDataUnavailable",
        ])
        let reasons: [AIAvailability.Reason] = [.deviceNotEligible, .appleIntelligenceNotEnabled, .modelNotReady, .unknown]
        #expect(reasons.map(\.logName.description) == reasons.map { String(describing: $0) })
        #expect(Vocabulary.Language.allCases.map(\.logName.description) == Vocabulary.Language.allCases.map(\.rawValue))
    }

    // MARK: No CV content

    @Test("No word of the description or of the draft reaches the log, whatever the draft does with it")
    func noCVContent() async throws {
        let marker = "Quorvex"
        let description = "Sono Maria \(marker), insegnante di scuola primaria a \(marker). Dal 2016 insegno alla scuola \(marker). "
            + "Parlo italiano e \(marker.lowercased()). Nel tempo libero mi piacciono gli scacchi e \(marker)."
        let draft = CVData(
            personalInfo: PersonalInfo(name: "Maria \(marker)", email: "\(marker)@example.com", location: marker, title: "insegnante \(marker)"),
            summary: "\(marker) \(marker)",
            experience: [Experience(title: "insegnante", company: "scuola \(marker)", startDate: "2016")],
            skills: [Skill(name: marker)], languages: [Language(name: marker.lowercased())], interests: ["scacchi", marker]
        )
        let logger = RecordingLogger()
        let request = CVGenerationRequest(userPrompt: description)

        _ = try await generator(drafting(draft), checker: FakeClaimChecker(stances: [marker: .wish]), logger: logger).generateCV(from: request)
        _ = try? await generator(failing(CVGenerationError.contentNotAllowed), logger: logger).generateCV(from: request)
        _ = try? await generator(logger: logger).generateCV(from: CVGenerationRequest(userPrompt: String(repeating: "\(marker) ", count: 400)))

        #expect(logger.events.contains("draft.finished"))
        #expect(logger.events.contains("draft.refused"))
        #expect(logger.events.contains("draft.rejected"))
        for entry in logger.entries {
            #expect(!entry.line.localizedCaseInsensitiveContains(marker), "\(entry.line)")
        }
    }
}
