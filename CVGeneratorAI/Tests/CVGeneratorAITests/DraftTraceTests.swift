import DiagnosticLogging
import DiagnosticLoggingTestSupport
import DiagnosticTrace
import DiagnosticTraceTestSupport
import Foundation
import Testing
@testable import CVGeneratorAI

/// What the AI draft records in the trace of a test build (ADR 0032): the description, whether the model could run, its language
/// data, the draft the model wrote, what grounding removed, what the requests of the sections wrote around the facts and what the
/// final grounding, the claim check and the result removed, the claim check's verdicts, the time of each stage and the draft the
/// person sees. The trace holds the text; the log still holds none of it.
@MainActor
@Suite("The trace of the AI draft")
struct DraftTraceTests {

    /// Every reading of the clock moves it on by this step: one at the start of the model, one at the end of each stage (grounding
    /// ends twice: once for the facts, once for the facts with the writing around them).
    private static let step = Duration.milliseconds(5)

    /// An Italian description: its grounding needs no language data of the device, so the tests do not depend on the Mac's.
    private var example: FaithfulExample { faithfulExamples[1] }

    private var request: CVGenerationRequest { CVGenerationRequest(userPrompt: example.description) }

    private func generator(
        _ service: any CVGenerationService, checker: FakeClaimChecker = FakeClaimChecker(), sanitizer: CVDataSanitizer = CVDataSanitizer(),
        logger: RecordingLogger = RecordingLogger(), tracer: any DiagnosticTracer
    ) -> CVGeneratorUseCase {
        CVGeneratorUseCase(
            service: service, claimChecker: checker, logger: logger, clock: TickingClock(step: Self.step), tracer: tracer,
            sanitizer: sanitizer
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

    /// Every text of a step with this key, in order: a step names each removed value in a field of its own.
    private func texts(_ key: String, of step: TraceStep?) -> [String] {
        (step?.fields ?? []).filter { $0.key == key }.compactMap { field in
            if case .text(let text) = field.value { return text.text }
            return nil
        }
    }

    /// The removal step of a stage.
    private func removal(_ stage: String, in run: TraceRun) -> TraceStep? {
        run.steps(.removal).first { $0.value("stage") == .token(stage) }
    }

    // MARK: A run that records nothing

    @Test("A run that records nothing is handed no step: the difference and the JSON are never built")
    func closedRunBuildsNothing() async throws {
        let tracer = RefusingTracer()

        let draft = try await generator(drafting(example.draft), tracer: tracer).generateCV(from: request)

        #expect(!draft.cvData.experience.isEmpty)
        #expect(tracer.calls == 0)

        await #expect(throws: CVGenerationError.serviceFailed) {
            try await generator(failing(CVGenerationError.serviceFailed), tracer: tracer).generateCV(from: request)
        }
        #expect(tracer.calls == 0)
    }

    // MARK: Two drafts of one kind in flight

    @Test("A cancelled draft's model steps and log events stay in its run when its retry began and finished first")
    func overlappingDraftsKeepTheirOwnSteps() async throws {
        let tracer = RecordingTracer()
        let service = InterleavingService(tracer: tracer, sample: example.draft)
        let generator = generator(service, tracer: tracer)
        let request = request
        var arrivals = service.arrivals.makeAsyncIterator()

        let older = Task { try await generator.generateCV(from: request) }
        await arrivals.next()
        // The retry begins while the older draft's model call is still out, and ends before it
        _ = try await generator.generateCV(from: request)
        service.releaseFirst()
        _ = try? await older.value

        #expect(tracer.runs.count == 2)
        let first = try #require(tracer.runs.first)
        let second = try #require(tracer.runs.last)
        #expect(first.steps(.request).compactMap { $0.text("prompt") } == ["call 1"])
        #expect(first.steps(.response).compactMap { $0.text("raw") }.contains("answer 1"))
        #expect(second.steps(.request).compactMap { $0.text("prompt") } == ["call 2"])
        #expect(!second.allText.contains("answer 1"))
    }

    @Test("A draft begun behind the closed gate stays unrecorded when the gate opens and a retry runs before its model call returns")
    func suppressedDraftDoesNotReachItsRetry() async throws {
        let recording = RecordingTracer()
        let gate = DistributionGate()
        let tracer = GatedTracer(gate: gate, next: recording)
        let service = InterleavingService(tracer: tracer, sample: example.draft)
        let generator = generator(service, tracer: tracer)
        let request = request
        var arrivals = service.arrivals.makeAsyncIterator()

        let older = Task { try await generator.generateCV(from: request) }
        await arrivals.next()
        await gate.ask(FixedDistribution(.sandbox))
        _ = try await generator.generateCV(from: request)
        service.releaseFirst()
        _ = try? await older.value

        let run = try #require(recording.runs.first)
        #expect(recording.runs.count == 1)
        #expect(run.steps(.request).compactMap { $0.text("prompt") } == ["call 2"])
        #expect(!run.allText.contains("answer 1"))
        #expect(recording.store.sessionEvents.isEmpty)
    }

    // MARK: A finished draft

    @Test("A finished draft records its input, the model's draft, what each stage removed and wrote, the times and the final draft, in order")
    func steps() async throws {
        let tracer = RecordingTracer()
        let draft = try await generator(drafting(example.draft), tracer: tracer).generateCV(from: request)

        let run = try #require(tracer.run(.aiDraft))
        #expect(tracer.runs.count == 1)
        #expect(run.outcome == .finished)
        #expect(run.steps.map(\.name) == [
            .input, .availability, .languageData, .response, .removal, .response, .removal, .check, .removal, .removal, .timing,
            .finalDraft,
        ])
        #expect(run.steps(.removal).map { $0.value("stage") } == ["grounding", "grounding", "claimCheck", "result"].map { .token($0) })
        #expect(run.steps(.response).map { $0.value("stage") } == ["model", "writing"].map { .token($0) })

        let input = try #require(run.steps(.input).first)
        #expect(input.text("description") == example.description)
        #expect(input.value("characters") == .count(example.description.count))
        #expect(input.value("fallbackLanguage") == .token("none"))
        #expect(run.steps(.availability).first?.value("available") == .flag(true))
        let language = try #require(run.steps(.languageData).first)
        #expect(language.fields == [.flag("supported", true), .token("language", "it"), .token("data", "notNeeded")])

        let model = try #require(run.steps(.response).first { $0.value("stage") == .token("model") })
        let written = try JSONDecoder().decode(CVData.self, from: Data(try #require(model.text("cv")).utf8))
        #expect(written == example.draft)

        let final = try #require(run.steps(.finalDraft).first)
        let shown = try JSONDecoder().decode(TracedDraft.self, from: Data(try #require(final.text("draft")).utf8))
        #expect(shown.cvData == draft.cvData)
        #expect(shown.personalItemsUnchecked == false)
        #expect(final.value("personalItemsUnchecked") == .flag(false))
    }

    @Test("The time of each stage is the clock between its start and its end, grounding's is both of its runs, and the draft's is the sum")
    func timing() async throws {
        let tracer = RecordingTracer()
        _ = try await generator(drafting(example.draft), tracer: tracer).generateCV(from: request)

        let timing = try #require(tracer.run(.aiDraft)?.steps(.timing).first)
        #expect(timing.fields == [
            .duration("model", Self.step), .duration("grounding", Self.step * 2), .duration("writing", Self.step),
            .duration("claimCheck", Self.step), .duration("result", Self.step), .duration("elapsed", Self.step * 6),
        ])
    }

    @Test("Grounding removes an employer the description never names, and the trace names the job and the value")
    func groundingRemoval() async throws {
        let invented = Experience(title: "magazziniere", company: "Zentrix Logistica", startDate: "2008", endDate: "2010")
        let base = example.draft
        let draft = CVData(
            personalInfo: base.personalInfo, summary: base.summary, experience: base.experience + [invented], education: base.education,
            skills: base.skills, languages: base.languages, certifications: base.certifications, interests: base.interests
        )
        let index = base.experience.count
        let tracer = RecordingTracer()

        let result = try await generator(drafting(draft), tracer: tracer).generateCV(from: request)

        #expect(!result.cvData.experience.contains { $0.company == "Zentrix Logistica" })
        let run = try #require(tracer.run(.aiDraft))
        let grounding = try #require(removal("grounding", in: run))
        let removed = texts("removed", of: grounding)
        #expect(removed.contains("experience[\(index)].company: Zentrix Logistica"))
        #expect(grounding.value("removals") == .count(removed.count))
        // The facts keep the first pass's summary when its words are the person's own, and the writing around them replaces it
        #expect(!removed.contains { $0.hasPrefix("summary: ") })
        #expect(texts("changed", of: run.steps(.removal).filter { $0.value("stage") == .token("grounding") }.last).contains { $0.hasPrefix("summary: ") })
    }

    // MARK: The writing

    @Test("The sections' writing is a response of its own: the summary, the duties of each job and the skills their checks kept, between the two groundings")
    func writing() async throws {
        let service = FakeCVGenerationService()
        service.generateResult = .success(SectionDraftTests.extracted)
        service.jobResults = SectionDraftTests.jobs
        service.toolsResult = SectionDraftTests.tools
        service.softSkillsResult = SectionDraftTests.qualities
        service.summaryResult = SectionDraftTests.summary
        let english = CVDataSanitizer(
            languageOfText: { _ in "en" }, lexicalClasses: ForcedLexicalTagger([.english: .words(SectionDraftTests.verbs)]),
            wordList: TableWordList()
        )
        let tracer = RecordingTracer()
        let logger = RecordingLogger()

        _ = try await generator(service, sanitizer: english, logger: logger, tracer: tracer)
            .generateCV(from: CVGenerationRequest(userPrompt: SectionDraftTests.briefly))

        let run = try #require(tracer.run(.aiDraft))
        let stages = run.steps.compactMap { $0.value("stage") }
        #expect(stages == ["model", "grounding", "writing", "grounding", "claimCheck", "claimCheck", "result"].map { .token($0) })
        let writing = try #require(run.steps(.response).first { $0.value("stage") == .token("writing") })
        #expect(writing.value("wrote") == .flag(true))
        let duties = texts("duties", of: writing)
        let tools = texts("technology", of: writing)
        let qualities = texts("softSkill", of: writing)
        #expect(!duties.isEmpty && !tools.isEmpty && !qualities.isEmpty)
        #expect(writing.value("roles") == .count(duties.count))
        #expect(writing.value("technologies") == .count(tools.count))
        #expect(writing.value("softSkills") == .count(qualities.count))
        #expect(duties.allSatisfy { $0.hasPrefix("role ") })
        #expect(writing.text("summary") != nil)

        // The final grounding reads the facts with the writing around them, and the step shows what that changed or added
        let groundings = run.steps(.removal).filter { $0.value("stage") == .token("grounding") }
        #expect(groundings.count == 2)
        let final = try #require(groundings.last)
        #expect(final.value("changes") != .count(0) || final.value("additions") != .count(0))

        // The trace holds what was written; the log holds none of it
        let summary = try #require(writing.text("summary"))
        let dutyTexts = duties.map { String($0.drop(while: { $0 != ":" }).dropFirst(2)) }
        #expect(run.allText.contains(summary))
        for entry in logger.entries {
            #expect(!entry.line.contains(summary), "\(entry.line)")
            #expect(!dutyTexts.contains { entry.line.contains($0) }, "\(entry.line)")
        }
    }

    // MARK: The requests of the sections

    @Test("A request of a section is recorded under its call's name with its limit, instructions and prompt; its answer, or why it had none, under the same name")
    func sectionCall() {
        let prompt = SectionPrompts.Prompt(instructions: "the rules", text: "the brief")
        let job = SectionCallTrace(call: "job", role: 2, tokens: 300)
        let tools = SectionCallTrace(call: "tools", role: nil, tokens: 200)

        #expect(job.request(prompt) == [
            .token("call", "job"), .count("role", 2), .count("maximumTokens", 300), .flag("schemaInPrompt", true),
            .token("sampling", "greedy"), .text("instructions", "the rules"), .text("prompt", "the brief"),
        ])
        #expect(tools.request(prompt).first == .token("call", "tools"))
        #expect(!tools.request(prompt).contains { $0.key == "role" })
        #expect(job.answered(raw: "{}", complete: true) == [
            .token("call", "job"), .count("role", 2), .flag("answered", true), .flag("complete", true), .text("raw", "{}"),
        ])
        #expect(tools.answered(raw: "[]", complete: nil) == [.token("call", "tools"), .flag("answered", true), .text("raw", "[]")])
        #expect(job.unanswered() == [.token("call", "job"), .count("role", 2), .flag("answered", false), .token("error", "noAnswer")])
        #expect(tools.failed(error: "busy", framework: "rate limited") == [
            .token("call", "tools"), .flag("answered", false), .token("error", "busy"), .text("framework", "rate limited"),
        ])
    }

    // MARK: The claim check

    @Test("The claim check records a verdict for each personal item, and its removal names what it withdrew")
    func claimCheck() async throws {
        let checker = FakeClaimChecker(stances: ["scacchi": .wish])
        let tracer = RecordingTracer()

        _ = try await generator(drafting(example.draft), checker: checker, tracer: tracer).generateCV(from: request)

        let run = try #require(tracer.run(.aiDraft))
        let check = try #require(run.steps(.check).first)
        let candidates = await checker.calls.flatMap(\.candidates)
        #expect(check.value("candidates") == .count(candidates.count))
        #expect(check.value("answered") == .flag(true))
        #expect(check.value("cause") == nil)
        let verdicts = texts("verdict", of: check)
        #expect(verdicts.count == candidates.count)
        #expect(verdicts.contains("interest: scacchi → wish \"\""))
        let removed = texts("removed", of: removal("claimCheck", in: run))
        #expect(removed.contains { $0.hasPrefix("interests[") && $0.hasSuffix(": scacchi") })
    }

    @Test("A claim check that gave no answer records why, and the final draft says its personal items went unchecked")
    func claimCheckUnanswered() async throws {
        let tracer = RecordingTracer()

        let draft = try await generator(
            drafting(example.draft), checker: FakeClaimChecker(failure: CVGenerationError.generationFailed), tracer: tracer
        ).generateCV(from: request)

        let run = try #require(tracer.run(.aiDraft))
        let check = try #require(run.steps(.check).first)
        #expect(check.value("answered") == .flag(false))
        #expect(check.value("cause") == .token("CVGenerationError"))
        #expect(check.text("causeText") == "generationFailed")
        #expect(texts("verdict", of: check).isEmpty)
        #expect(draft.personalItemsUnchecked)
        #expect(run.steps(.finalDraft).first?.value("personalItemsUnchecked") == .flag(true))
        #expect(run.outcome == .finished)
    }

    // MARK: A draft that stops

    @Test("A draft asked for while the model cannot run records why, and fails as unavailable")
    func unavailable() async throws {
        let service = FakeCVGenerationService()
        service.availabilityResult = .unavailable(.modelNotReady)
        let tracer = RecordingTracer()

        await #expect(throws: CVGenerationError.unavailable(.modelNotReady)) {
            try await generator(service, tracer: tracer).generateCV(from: request)
        }

        let run = try #require(tracer.run(.aiDraft))
        #expect(run.steps.map(\.name) == [.input, .availability, .failure])
        #expect(run.steps(.availability).first?.fields == [.flag("available", false), .token("reason", "modelNotReady")])
        #expect(run.steps(.failure).first?.value("check") == .token("availability"))
        #expect(run.outcome == .failed(code: "unavailable"))
    }

    @Test("A description the rules refuse records the rule, before the model is asked")
    func rejectedRequest() async throws {
        let tracer = RecordingTracer()

        await #expect(throws: CVGenerationError.descriptionTooShort) {
            try await generator(FakeCVGenerationService(), tracer: tracer).generateCV(from: CVGenerationRequest(userPrompt: "   "))
        }

        let run = try #require(tracer.run(.aiDraft))
        #expect(run.steps.map(\.name) == [.input, .availability, .failure])
        #expect(run.steps(.failure).first?.fields == [.token("check", "request"), .token("error", "descriptionTooShort")])
        #expect(run.outcome == .failed(code: "descriptionTooShort"))
    }

    @Test("Language data the device lacks is recorded, then the refusal of the language check")
    func missingLanguageData() async throws {
        let tracer = RecordingTracer()
        let missing = CVDataSanitizer(lexicalClasses: ForcedLexicalTagger([.german: .noAssets]))

        await #expect(throws: CVGenerationError.languageDataUnavailable(languageCode: "de")) {
            try await generator(FakeCVGenerationService(), sanitizer: missing, tracer: tracer)
                .generateCV(from: CVGenerationRequest(userPrompt: faithfulExamples[2].description))
        }

        let run = try #require(tracer.run(.aiDraft))
        #expect(run.steps.map(\.name) == [.input, .availability, .languageData, .failure])
        #expect(run.steps(.languageData).first?.value("data") == .token("missing"))
        #expect(run.steps(.failure).first?.value("check") == .token("language"))
        #expect(run.outcome == .failed(code: "languageDataUnavailable"))
    }

    @Test("A description the model refuses records the stage and the refusal, and the time it ran")
    func refused() async throws {
        let tracer = RecordingTracer()

        await #expect(throws: CVGenerationError.contentNotAllowed) {
            try await generator(failing(CVGenerationError.contentNotAllowed), tracer: tracer).generateCV(from: request)
        }

        let run = try #require(tracer.run(.aiDraft))
        #expect(run.steps.map(\.name) == [.input, .availability, .languageData, .failure, .timing])
        #expect(run.steps(.failure).first?.fields == [.token("stage", "model"), .token("error", "contentNotAllowed")])
        #expect(run.steps(.timing).first?.fields == [.duration("elapsed", Self.step)])
        #expect(run.outcome == .failed(code: "contentNotAllowed"))
    }

    @Test("A failure with no code of its own is recorded by its type and its own words")
    func unmappedFailure() async throws {
        let tracer = RecordingTracer()

        await #expect(throws: UnmappedFailure.self) {
            try await generator(failing(UnmappedFailure()), tracer: tracer).generateCV(from: request)
        }

        let failure = try #require(tracer.run(.aiDraft)?.steps(.failure).first)
        #expect(failure.value("error") == .token("UnmappedFailure"))
        #expect(failure.text("description") == "UnmappedFailure()")
        #expect(tracer.run(.aiDraft)?.outcome == .failed(code: "UnmappedFailure"))
    }

    @Test("A draft the rules leave empty records what the result kept, then the rejection, and the times of the stages it finished")
    func rejectedResult() async throws {
        let tracer = RecordingTracer()

        await #expect(throws: CVGenerationError.emptyResult) {
            try await generator(drafting(CVData(personalInfo: PersonalInfo(name: "Someone Else"))), tracer: tracer).generateCV(from: request)
        }

        let run = try #require(tracer.run(.aiDraft))
        #expect(Array(run.steps.map(\.name).suffix(3)) == [.removal, .failure, .timing])
        #expect(run.steps(.failure).first?.fields == [.token("stage", "result"), .token("error", "emptyResult")])
        #expect(run.steps(.timing).first?.fields == [
            .duration("model", Self.step), .duration("grounding", Self.step * 2), .duration("writing", Self.step),
            .duration("claimCheck", Self.step), .duration("elapsed", Self.step * 6),
        ])
        // With nothing to write around, nothing was written, and the groundings stay one step
        #expect(run.steps(.response).last?.fields == [.token("stage", "writing"), .flag("wrote", false)])
        #expect(run.steps(.removal).filter { $0.value("stage") == .token("grounding") }.count == 1)
        #expect(run.outcome == .failed(code: "emptyResult"))
    }

    @Test("A draft cancelled in the claim check records the stage, the times up to it, and finishes as cancelled")
    func cancelled() async throws {
        let tracer = RecordingTracer()

        await #expect(throws: CancellationError.self) {
            try await generator(drafting(example.draft), checker: FakeClaimChecker(failure: CancellationError()), tracer: tracer)
                .generateCV(from: request)
        }

        let run = try #require(tracer.run(.aiDraft))
        #expect(run.outcome == .cancelled)
        #expect(Array(run.steps.map(\.name).suffix(2)) == [.failure, .timing])
        #expect(run.steps(.failure).first?.fields == [.token("stage", "claimCheck"), .token("error", "cancelled")])
        #expect(run.steps(.timing).first?.fields == [
            .duration("model", Self.step), .duration("grounding", Self.step * 2), .duration("writing", Self.step),
            .duration("elapsed", Self.step * 5),
        ])
    }

    // MARK: Text in the trace, never in the log

    @Test("A word of the description is in the trace and in no log entry")
    func marker() async throws {
        let marker = "Quorvex"
        let description = "Sono Maria \(marker), insegnante di scuola primaria a Bologna. Dal 2016 insegno alla scuola \(marker)."
        let draft = CVData(
            personalInfo: PersonalInfo(name: "Maria \(marker)", title: "insegnante di scuola primaria"),
            experience: [Experience(title: "insegnante", company: "scuola \(marker)", startDate: "2016")]
        )
        let tracer = RecordingTracer()
        let logger = RecordingLogger()

        _ = try? await generator(drafting(draft), logger: logger, tracer: tracer).generateCV(from: CVGenerationRequest(userPrompt: description))

        #expect(try #require(tracer.run(.aiDraft)).allText.contains(marker))
        #expect(!logger.entries.isEmpty)
        for entry in logger.entries {
            #expect(!entry.line.localizedCaseInsensitiveContains(marker), "\(entry.line)")
        }
    }

    @Test("Without a trace, a draft records nothing and comes out the same")
    func noTracer() async throws {
        let traced = try await generator(drafting(example.draft), tracer: RecordingTracer()).generateCV(from: request)
        let silent = try await generator(drafting(example.draft), tracer: NoTracer()).generateCV(from: request)
        #expect(traced == silent)
    }

    // MARK: Names

    @Test("The model's and the writing's stages are responses; every other stage is a removal")
    func stepOfEachStage() {
        #expect([DraftLog.Stage.model, .writing].map(DraftTrace.step(for:)) == [.response, .response])
        #expect([DraftLog.Stage.grounding, .claimCheck, .result].map(DraftTrace.step(for:)) == [.removal, .removal, .removal])
    }

    @Test("The request to the model is its instructions and its prompt, as the service sends them", arguments: [
        InstructionsDelivery.session, .promptPrefix,
    ])
    func promptFields(delivery: InstructionsDelivery) {
        let prompt = CVPrompt(request: request, delivery: delivery)
        #expect(prompt.traceFields == [
            .token("call", "draft"), .flag("schemaInPrompt", true), .token("sampling", "greedy"),
            .text("instructions", prompt.instructions ?? ""), .text("prompt", prompt.text),
        ])
    }
}

/// A failure of the model that is none of the app's errors.
private struct UnmappedFailure: Error {}

/// The final draft of the trace, as a script reads it.
private struct TracedDraft: Decodable {
    let cvData: CVData
    let personalItemsUnchecked: Bool
}

/// A model service whose first call waits until it is released, so that a second draft can begin and end in the meantime. Each
/// call records its prompt and its answer by kind, as the real service does, and returns the sample.
@MainActor
private final class InterleavingService: CVGenerationService {
    private let tracer: any DiagnosticTracer
    private let sample: CVData
    private var calls = 0
    private var release: CheckedContinuation<Void, Never>?
    private let arrived: AsyncStream<Void>.Continuation
    /// Yields once, when the first call is waiting
    let arrivals: AsyncStream<Void>

    init(tracer: any DiagnosticTracer, sample: CVData) {
        self.tracer = tracer
        self.sample = sample
        (arrivals, arrived) = AsyncStream.makeStream(of: Void.self)
    }

    func availability() -> AIAvailability { .available }

    func releaseFirst() {
        release?.resume()
        release = nil
    }

    func generateCV(from request: CVGenerationRequest) async throws -> CVData {
        calls += 1
        let call = calls
        tracer.record(.request, into: .aiDraft) { [.text("prompt", "call \(call)")] }
        if call == 1 {
            await withCheckedContinuation { release = $0; arrived.yield() }
        }
        tracer.record(.response, into: .aiDraft) { [.text("raw", "answer \(call)")] }
        return sample
    }
}
