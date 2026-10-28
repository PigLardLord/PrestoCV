import DiagnosticLogging
import DiagnosticLoggingTestSupport
import Foundation
import Testing
@testable import CVGeneratorAI

/// The two passes of a draft (ADR 0031): the first extracts the facts with the instructions of #202, the second writes the summary,
/// the duties of each role and the role's skills from the facts the rules kept, never from the description; each within its time, and
/// tried once more when it fails below the model.
@MainActor
@Suite("The two passes of the AI draft")
struct TwoPassDraftTests {
    private let sanitizer = CVDataSanitizer(lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())
    private var english: FaithfulExample { faithfulExamples[0] }

    /// Invented wording that states no fact of its own: no number, date, name, length, rank or level.
    private let plainSummary = "A caring teacher who plans lessons and works closely with families."
    private let plainDuties = "Plans lessons, teaches reading and writing, and keeps in touch with families."

    /// What a pass under test counts, from the main actor that runs it.
    @MainActor
    private final class Calls {
        var count = 0
        var retries: [String] = []
    }

    private func writing(
        summary: String? = nil, duties: [String?] = [], technologies: [String] = [], softSkills: [String] = []
    ) -> DraftWriting {
        DraftWriting(summary: summary, roleDescriptions: duties, technologies: technologies, softSkills: softSkills)
    }

    private func generator(_ service: FakeCVGenerationService, limits: DraftingLimits = .standard,
                           logger: any DiagnosticLogger = SilentLogger()) -> CVGeneratorUseCase {
        CVGeneratorUseCase(
            service: service, claimChecker: FakeClaimChecker(), logger: logger, clock: ContinuousClock(),
            validator: DefaultCVValidator(), sanitizer: sanitizer, limits: limits
        )
    }

    private func drafting(_ example: FaithfulExample) -> FakeCVGenerationService {
        let service = FakeCVGenerationService()
        service.generateResult = .success(example.draft)
        return service
    }

    // MARK: The brief

    @Test("The brief holds the language, the titles, which roles have ended, the studies and the named skills, and no employer, school or place")
    func briefOfTheFacts() throws {
        let facts = try sanitizer.sanitize(english.draft, against: english.description)

        let brief = try #require(DraftBrief(facts, language: .english))

        #expect(brief.language == "English")
        #expect(brief.headline == "primary school teacher")
        #expect(brief.roles == [
            DraftBrief.Role(title: "primary school teacher", hasEnded: false), DraftBrief.Role(title: "assistant", hasEnded: true),
        ])
        #expect(brief.studies == ["Education Sciences"])
        let text = DraftWritingPrompt(brief: brief).text
        for name in ["Don Milani", "nursery", "Bologna", "Maria", "2016", "2012"] {
            #expect(!text.contains(name), "The second pass never sees \(name): it has nothing to copy")
        }
    }

    @Test("There is no brief without a title, a job title or a degree, nor without a language of the six")
    func noBriefWithoutARole() {
        let interestsOnly = CVData(personalInfo: PersonalInfo(name: "Anna"), interests: ["chess"])
        let employerOnly = CVData(experience: [Experience(title: "", company: "Acme")])

        #expect(DraftBrief(interestsOnly, language: .english) == nil)
        #expect(DraftBrief(employerOnly, language: .english) == nil)
        #expect(DraftBrief(english.draft, language: nil) == nil)
        #expect(DraftBrief(CVData(education: [Education(degree: "Nursing")]), language: .italian)?.language == "Italian")
    }

    // MARK: The prompt of the second pass

    @Test("The prompt numbers the titled roles by their place in the brief, marks the ended ones and lists the skills already named")
    func promptOfTheBrief() {
        let brief = DraftBrief(
            language: "Italian", headline: "infermiera",
            roles: [.init(title: "infermiera", hasEnded: false), .init(title: "", hasEnded: true), .init(title: "barista", hasEnded: true)],
            studies: ["Scienze infermieristiche"], namedSkills: ["HACCP"]
        )

        let prompt = DraftWritingPrompt(brief: brief)

        #expect(prompt.instructions == DraftWritingPrompt.instructionsText)
        #expect(prompt.text == """
            Language: Italian
            Headline title: infermiera
            Roles:
            1. infermiera
            3. barista (ended)
            Studies: Scienze infermieristiche
            Skills already listed: HACCP
            """)
    }

    @Test("Each description goes to the role of its number; a number of no role and a second answer for a number are ignored")
    func descriptionsByNumber() {
        let brief = DraftBrief(
            language: "English", headline: nil,
            roles: [.init(title: "nurse", hasEnded: false), .init(title: "", hasEnded: false), .init(title: "waiter", hasEnded: true)],
            studies: [], namedSkills: []
        )

        let descriptions = DraftWritingPrompt.descriptions(
            [(number: 3, text: "Served tables."), (number: 2, text: "Untitled."), (number: 7, text: "None."), (number: 3, text: "Again."),
             (number: 0, text: "Zero.")],
            of: brief
        )

        #expect(descriptions == [nil, nil, "Served tables."])
    }

    @Test("The instructions of the second pass ask for a summary, the typical duties of each role, technologies and soft skills, with no fact of their own (ADR 0031)")
    func instructionsAskForTheWrittenText() {
        let instructions = DraftWritingPrompt.instructionsText

        #expect(instructions.contains("2 to 4 sentences"))
        #expect(instructions.contains("No number, date, company, school, place or person's name"))
        #expect(instructions.contains("no \"experience\", \"years\""), "A summary that claims experience states a fact of its own")
        #expect(instructions.contains("responsibilities typical of that title"))
        #expect(instructions.contains("For a role marked ended, write in the past tense"))
        #expect(instructions.contains("Technologies: 4 to 8"))
        #expect(instructions.contains("Soft skills: 3 to 5"))
        #expect(instructions.contains("no level, none of the skills already listed"))
        #expect(instructions.contains("Never add a language, job, study, certification, hobby, achievement or result"))
    }

    // MARK: Grounding what the second pass wrote

    @Test("What the second pass writes stays only when it states no fact: a number, a name or a level goes, the plain text stays")
    func writtenTextIsGrounded() throws {
        let written = writing(
            summary: plainSummary + " She has taught for ten years at Acme.",
            duties: [plainDuties + " Trained 12 teachers.", "Looked after the children during play."],
            technologies: ["Lesson planning", "Classroom management", "Advanced Excel", "Business English"],
            softSkills: ["Patience", "Teamwork"]
        )

        let result = try sanitizer.sanitize(english.draft, writing: written, against: english.description)
        let facts = try sanitizer.sanitize(english.draft, against: english.description)

        #expect(result.summary == plainSummary)
        #expect(result.experience.map(\.description) == [plainDuties, "Looked after the children during play."])
        #expect(result.skills == [
            Skill(name: "Lesson planning", kind: .technology), Skill(name: "Classroom management", kind: .technology),
            Skill(name: "Patience", kind: .softSkill), Skill(name: "Teamwork", kind: .softSkill),
        ])
        #expect(result.personalInfo == facts.personalInfo, "The written text changes no fact")
        #expect(result.experience.map(\.title) == facts.experience.map(\.title))
        #expect(result.experience.map(\.achievements) == facts.experience.map(\.achievements))
        #expect(result.education == facts.education)
        #expect(result.languages == facts.languages)
        #expect(result.interests == facts.interests)
    }

    @Test("A written summary that keeps no sentence leaves the first pass's summary, and a role the second pass skipped keeps its own text")
    func firstPassTextRemains() throws {
        let written = writing(summary: "Taught for 12 years at Acme.", duties: [nil])

        let result = try sanitizer.sanitize(english.draft, writing: written, against: english.description)

        #expect(result.summary == english.draft.summary)
        #expect(result.experience.map(\.description) == [nil, nil])
    }

    @Test("A sentence of the duties that the role's own text holds already is not written twice")
    func dutiesAreNotRepeated() throws {
        let school = english.draft.experience[0]
        let draft = CVData(personalInfo: english.draft.personalInfo, experience: [Experience(
            title: school.title, company: school.company, location: school.location, startDate: school.startDate,
            endDate: school.endDate, current: school.current, description: plainDuties, achievements: school.achievements
        )])
        let written = writing(duties: [plainDuties + " Looks after the children during play."])

        let result = try sanitizer.sanitize(draft, writing: written, against: english.description)

        #expect(result.experience.first?.description == plainDuties + " Looks after the children during play.")
    }

    @Test("With no title, job or school there is nothing to write around: the written summary and skills go")
    func noFactNoWriting() throws {
        let description = "This is a test of the app, I like chess."
        let draft = CVData(interests: ["chess"])
        let written = writing(summary: plainSummary, technologies: ["Lesson planning"], softSkills: ["Patience"])

        let result = try sanitizer.sanitize(draft, writing: written, against: description)

        #expect(result.summary == nil)
        #expect(result.skills.isEmpty)
    }

    // MARK: One call of a pass

    @Test("A pass that runs past its time fails with generationFailed, and is not tried again")
    func timeout() async {
        let calls = Calls()

        await #expect(throws: CVGenerationError.generationFailed) {
            try await DraftAttempt.run(within: .milliseconds(20)) {
                calls.count += 1
                try await Task.sleep(for: .seconds(30))
                return 1
            }
        }
        #expect(calls.count == 1)
    }

    @Test("A pass that fails below the model is tried once more, and the retry is told the error")
    func retryOnServiceFailure() async throws {
        let calls = Calls()

        let value = try await DraftAttempt.run(within: .seconds(30), retried: { calls.retries.append(String(describing: $0)) }) {
            calls.count += 1
            if calls.count == 1 { throw CVGenerationError.serviceFailed }
            return 7
        }

        #expect(value == 7)
        #expect(calls.count == 2)
        #expect(calls.retries == [String(describing: CVGenerationError.serviceFailed)])
    }

    @Test("A pass that fails below the model twice fails, after two calls")
    func secondServiceFailureFails() async {
        let calls = Calls()

        await #expect(throws: CVGenerationError.serviceFailed) {
            try await DraftAttempt.run(within: .seconds(30)) { () async throws -> Int in
                calls.count += 1
                throw CVGenerationError.serviceFailed
            }
        }
        #expect(calls.count == 2)
    }

    @Test("A pass that the model refuses or that fails for its answer is not tried again", arguments: [
        CVGenerationError.generationFailed, .contentNotAllowed, .busy, .emptyResult,
    ])
    func noRetryOnOtherErrors(error: CVGenerationError) async {
        let calls = Calls()

        await #expect(throws: error) {
            try await DraftAttempt.run(within: .seconds(30)) { () async throws -> Int in
                calls.count += 1
                throw error
            }
        }
        #expect(calls.count == 1)
    }

    @Test("A cancelled pass throws the cancellation, not a timeout")
    func cancellation() async {
        let task = Task { @MainActor in
            try await DraftAttempt.run(within: .seconds(30)) {
                try await Task.sleep(for: .seconds(30))
                return 1
            }
        }
        task.cancel()

        await #expect(throws: CancellationError.self) { try await task.value }
    }

    // MARK: The use case

    @Test("The second pass is asked with the brief of the grounded facts, and what it wrote reaches the draft once grounded")
    func secondPassReachesTheDraft() async throws {
        let service = drafting(english)
        service.writeResult = .success(writing(
            summary: plainSummary, duties: [plainDuties, nil], technologies: ["Lesson planning", "Advanced Excel"], softSkills: ["Patience"]
        ))

        let draft = try await generator(service).generateCV(from: CVGenerationRequest(userPrompt: english.description))

        let facts = try sanitizer.sanitize(english.draft, against: english.description)
        #expect(service.writeBriefs == [DraftBrief(facts, language: .english)].compactMap { $0 })
        #expect(draft.cvData.summary == plainSummary)
        #expect(draft.cvData.experience.first { $0.current }?.description == plainDuties)
        #expect(draft.cvData.skills == [Skill(name: "Lesson planning", kind: .technology), Skill(name: "Patience", kind: .softSkill)])
    }

    @Test("A second pass that fails, twice below the model, or runs out of time leaves the draft its facts", arguments: [
        "failed", "serviceFailed", "timedOut",
    ])
    func failedSecondPassKeepsTheFacts(how: String) async throws {
        let plain = try await generator(drafting(english)).generateCV(from: CVGenerationRequest(userPrompt: english.description))
        let service = drafting(english)
        service.writeResult = .success(writing(summary: plainSummary, technologies: ["Lesson planning"]))
        switch how {
        case "failed": service.writeFailures = [CVGenerationError.generationFailed]
        case "serviceFailed": service.writeFailures = [CVGenerationError.serviceFailed, CVGenerationError.serviceFailed]
        default: service.writeDelay = .seconds(30)
        }
        let limits = DraftingLimits(extraction: .seconds(30), writing: .milliseconds(20))

        let draft = try await generator(service, limits: limits).generateCV(from: CVGenerationRequest(userPrompt: english.description))

        #expect(draft == plain)
        #expect(service.writeBriefs.count == (how == "serviceFailed" ? 2 : 1))
    }

    @Test("A first pass that runs out of time fails the draft with generationFailed, and the second pass is not asked")
    func firstPassTimeout() async {
        let service = drafting(english)
        service.generateDelay = .seconds(30)
        let limits = DraftingLimits(extraction: .milliseconds(20), writing: .seconds(30))

        await #expect(throws: CVGenerationError.generationFailed) {
            try await generator(service, limits: limits).generateCV(from: CVGenerationRequest(userPrompt: english.description))
        }
        #expect(service.generateRequests.count == 1)
        #expect(service.writeBriefs.isEmpty)
    }

    @Test("A first pass that fails below the model once is tried again and the draft goes on")
    func firstPassRetry() async throws {
        let service = drafting(english)
        service.generateFailures = [CVGenerationError.serviceFailed]

        let draft = try await generator(service).generateCV(from: CVGenerationRequest(userPrompt: english.description))

        #expect(service.generateRequests.count == 2)
        #expect(!draft.cvData.experience.isEmpty)
    }

    @Test("A draft of no role does not ask the second pass")
    func noRoleNoSecondPass() async {
        let service = FakeCVGenerationService()
        service.generateResult = .success(CVData(interests: ["chess"]))

        _ = try? await generator(service).generateCV(from: CVGenerationRequest(userPrompt: "This is a test of the app, I like chess."))

        #expect(service.writeBriefs.isEmpty)
    }

    // MARK: The log

    @Test("The log says what the second pass wrote, in counts, and why a pass was tried again or wrote nothing")
    func log() async throws {
        let logger = RecordingLogger()
        let service = drafting(english)
        service.generateFailures = [CVGenerationError.serviceFailed]
        service.writeResult = .success(writing(
            summary: plainSummary, duties: [plainDuties, nil], technologies: ["Lesson planning", "Phonics"], softSkills: ["Patience"]
        ))
        _ = try await generator(service, logger: logger).generateCV(from: CVGenerationRequest(userPrompt: english.description))

        let failing = drafting(english)
        failing.writeFailures = [CVGenerationError.generationFailed]
        _ = try await generator(failing, logger: logger).generateCV(from: CVGenerationRequest(userPrompt: english.description))

        #expect(logger.entry("draft.retried")?.line == "draft.retried stage=model error=CVGenerationError.serviceFailed")
        #expect(logger.entry("draft.retried")?.level == .notice)
        #expect(logger.entry("draft.written")?.line == "draft.written summary=true roles=1 technologies=2 softSkills=1")
        #expect(logger.entry("draft.written")?.level == .info)
        #expect(logger.entry("draft.unwritten")?.line == "draft.unwritten error=CVGenerationError.generationFailed")
        #expect(logger.entry("draft.unwritten")?.level == .notice)
        for line in logger.entries("draft.written").map(\.line) + logger.entries("draft.unwritten").map(\.line) {
            #expect(!line.contains("teacher") && !line.contains("Lesson"), "The log holds no word of the draft")
        }
    }
}
