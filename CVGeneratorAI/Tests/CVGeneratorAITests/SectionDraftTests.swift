import DiagnosticLogging
import DiagnosticLoggingTestSupport
import Foundation
import Testing
@testable import CVGeneratorAI

/// A draft written a section at a time (ADR 0031, "A request per section"): after the facts, a request per job, then the tools and
/// the soft skills, then the summary, each answer checked inside its step; a request that fails stops the writing, and the draft
/// keeps what the earlier ones gave. The description and every answer are invented.
@MainActor
@Suite("A draft written a section at a time (ADR 0031)")
struct SectionDraftTests {
    /// A sanitizer that reads every text as English and tags the verbs of the description and of the answers as verbs: the checks
    /// then read the same on every platform, with the device's language data or without.
    private let sanitizer = CVDataSanitizer(
        languageOfText: { _ in "en" }, lexicalClasses: ForcedLexicalTagger([.english: .words(Self.verbs)]), wordList: TableWordList()
    )
    private static let verbs: Set<String> = [
        "have", "has", "been", "was", "is", "am", "are", "worked", "work", "started", "rigged", "loaded", "setting", "set", "mixing",
        "mixed", "helping", "plan", "train", "looking", "moved", "kept", "keep", "ran", "run", "looked", "look", "won", "check",
    ]
    private let description = JobClausesTests.english

    /// The jobs of the description as the extraction gives them: the titles, the employers and which job goes on, and no date.
    private static let extracted = CVData(experience: [
        Experience(title: "stagehand", company: "Fenwick Playhouse"),
        Experience(title: "sound technician", company: "Brightwater Events"),
        Experience(title: "sound technician", company: "Copperfield Arena"),
        Experience(title: "head of sound", company: "Orchard Lane Theatre", current: true),
    ])

    /// Invented answers that state no fact of their own, each job in the form of the person's own duties.
    private static let jobs: [Int: RoleWriting] = [
        0: RoleWriting(startDate: "2013", endDate: "2016", duties: "I moved the scenery between scenes. I kept the backstage area clear and safe."),
        1: RoleWriting(startDate: "2016", endDate: "2019", duties: "I ran the sound checks with each band. I looked after the microphones and cables."),
        2: RoleWriting(startDate: "2019", endDate: "2021", duties: "I ran the sound checks before each concert. I looked after the stage monitors."),
        3: RoleWriting(startDate: "2021", endDate: nil, duties: "I run the technical rehearsals. I look after the mixing desks and the stage monitors."),
    ]
    private static let tools = [["scenery flats", "rigging hardware"], ["PA systems", "microphones"], ["stage monitors"], ["mixing desks", "sound design software"]]
    private static let qualities = ["teamwork", "calm under pressure", "attention to detail"]
    private static let summary = """
        I work as head of sound in theatres and on tours. I plan the sound of each production, run the rehearsals and look after the \
        mixing desks and stage monitors.
        """

    private func service() -> FakeCVGenerationService {
        let service = FakeCVGenerationService()
        service.generateResult = .success(Self.extracted)
        service.jobResults = Self.jobs
        service.toolsResult = Self.tools
        service.softSkillsResult = Self.qualities
        service.summaryResult = Self.summary
        return service
    }

    private func generator(
        _ service: FakeCVGenerationService, limits: DraftingLimits = .standard, logger: any DiagnosticLogger = SilentLogger()
    ) -> CVGeneratorUseCase {
        CVGeneratorUseCase(
            service: service, claimChecker: FakeClaimChecker(), logger: logger, clock: ContinuousClock(),
            validator: DefaultCVValidator(), sanitizer: sanitizer, limits: limits
        )
    }

    private func draft(
        _ service: FakeCVGenerationService, limits: DraftingLimits = .standard, logger: any DiagnosticLogger = SilentLogger()
    ) async throws -> CVData {
        try await generator(service, limits: limits, logger: logger).generateCV(from: CVGenerationRequest(userPrompt: description)).cvData
    }

    private func job(_ company: String, in draft: CVData) -> Experience? {
        draft.experience.first { $0.company == company }
    }

    // MARK: The order of the requests

    @Test("After the facts, a request per job in order, then the tools, the soft skills and the summary, each reading the brief")
    func order() async throws {
        let service = service()

        _ = try await draft(service)

        #expect(service.generateRequests.count == 1)
        #expect(service.sectionCalls == ["job 0", "job 1", "job 2", "job 3", "tools", "softSkills", "summary"])
        let brief = try #require(service.sectionBriefs.first)
        #expect(service.sectionBriefs.allSatisfy { $0 == brief })
        #expect(brief.roles.map(\.title) == ["stagehand", "sound technician", "sound technician", "head of sound"])
        #expect(brief.roles[0].clauses.contains { $0.contains("rigged the lights") })
        #expect(!brief.roles[0].clauses.contains { $0.contains("Orchard Lane") })
        #expect(brief.roles[3].clauses.contains { $0.contains("sound design") })
    }

    @Test("The summary request reads the duties and the skills the checks kept, one for one with the jobs")
    func summaryInputs() async throws {
        let service = service()

        _ = try await draft(service)

        let request = try #require(service.summaryRequests.first)
        #expect(request.duties.count == 4)
        #expect(request.duties[3]?.contains("I run the technical rehearsals.") == true)
        #expect(request.skills.contains("mixing desks"))
        #expect(request.skills.contains("teamwork"))
    }

    // MARK: What reaches the draft

    @Test("The years each job's request read fill the dates the extraction left empty on every job, and a current job gets no end")
    func datesFromYears() async throws {
        let draft = try await draft(service())

        #expect(job("Fenwick Playhouse", in: draft).map { [$0.startDate, $0.endDate] } == ["2013", "2016"])
        #expect(job("Copperfield Arena", in: draft).map { [$0.startDate, $0.endDate] } == ["2019", "2021"])
        #expect(job("Orchard Lane Theatre", in: draft).map { [$0.startDate, $0.endDate] } == ["2021", nil])
        #expect(job("Orchard Lane Theatre", in: draft)?.current == true)
    }

    @Test("A job named after another in a run-on sentence keeps its title (H1), and the duties the person said reach the draft (H3)")
    func ownTitleAndDuties() async throws {
        let draft = try await draft(service())

        #expect(job("Copperfield Arena", in: draft)?.title == "sound technician")
        let head = try #require(job("Orchard Lane Theatre", in: draft)?.description)
        #expect(head.hasPrefix("I plan the sound design for each production and train the junior technicians."))
        #expect(head.contains("I run the technical rehearsals."))
        #expect(job("Fenwick Playhouse", in: draft)?.location == "Norwich")
    }

    @Test("What the checks keep reaches the draft: the duties of each job, the technologies, the soft skills and the summary")
    func sectionsReachTheDraft() async throws {
        let draft = try await draft(service())

        #expect(draft.experience.allSatisfy { $0.description?.isEmpty == false })
        #expect(draft.skills.contains(Skill(name: "mixing desks", kind: .technology)))
        #expect(draft.skills.contains(Skill(name: "teamwork", kind: .softSkill)))
        #expect(draft.summary == Self.summary)
    }

    @Test("An invented fact goes from each section that writes text: a duty, a technology, a soft skill and a summary sentence")
    func inventedRowsGo() async throws {
        let service = service()
        service.jobResults[3] = RoleWriting(
            startDate: "2021", endDate: nil,
            duties: "I run the technical rehearsals. I mixed 40 shows at the Royal Albert Hall. I look after the mixing desks."
        )
        service.toolsResult = Self.tools + [["Dante Level 3 certification"]]
        service.softSkillsResult = Self.qualities + ["leadership of 12 technicians"]
        service.summaryResult = Self.summary + " I won the Best Venue award in 2019."

        let draft = try await draft(service)

        let text = ([draft.summary] + draft.experience.map(\.description)).compactMap { $0 }.joined(separator: " ")
            + draft.skills.map(\.name).joined(separator: " ")
        for invented in ["Royal Albert", "40 shows", "Level 3", "12 technicians", "award", "2019."] {
            #expect(!text.contains(invented), "\(invented)")
        }
        #expect(job("Orchard Lane Theatre", in: draft)?.description?.contains("I look after the mixing desks.") == true)
    }

    // MARK: Repairs

    @Test("A job whose check keeps too little gets one repair that reads what it kept and what it rejected, and why")
    func jobRepair() async throws {
        let service = service()
        service.jobResults[1] = RoleWriting(startDate: "2016", endDate: "2019", duties: "Mixing at 3 festivals.")
        service.jobRepairResults[1] = ["I ran the sound checks with each band.", "I looked after the microphones and cables."]

        let draft = try await draft(service)

        #expect(service.sectionCalls.prefix(3) == ["job 0", "job 1", "repairJob 1"])
        let repair = try #require(service.jobRepairs.first)
        // The duty in -ing is put in the person's own form first, so the repair reads the sentence as the draft would have it.
        #expect(repair.rejected == ["\"I was mixing at 3 festivals.\": it holds a number"])
        #expect(job("Brightwater Events", in: draft)?.description?.contains("I looked after the microphones and cables.") == true)
    }

    @Test("Too few skills kept ask once for those missing, none of the kept ones")
    func moreSkills() async throws {
        let service = service()
        service.toolsResult = [["mixing desks"], [], [], []]
        service.softSkillsResult = ["teamwork"]
        service.moreSkillsResult = DraftWriting(
            summary: nil, roleDescriptions: [], technologies: ["stage monitors", "PA systems", "microphones"],
            softSkills: ["reliability", "patience"]
        )

        let draft = try await draft(service)

        #expect(service.sectionCalls.filter { $0 == "moreSkills" }.count == 1)
        let request = try #require(service.moreSkillsRequests.first)
        #expect(request.tools == 3 && request.qualities == 2)
        #expect(request.excluding == ["mixing desks", "teamwork"])
        #expect(draft.skills.contains(Skill(name: "PA systems", kind: .technology)))
        #expect(draft.skills.contains(Skill(name: "patience", kind: .softSkill)))
    }

    @Test("A summary that keeps a sentence but is short gets an opening from the facts, and one repair for what else it misses")
    func summaryRepair() async throws {
        let service = service()
        service.summaryResult = "He is a sound engineer. I keep every show running smoothly."
        service.summaryRepairResult = """
            I work as a head of sound. I keep every show running smoothly. I plan the sound of each production and look after the \
            mixing desks. I train the technicians. I check the stage monitors.
            """

        let draft = try await draft(service)

        #expect(service.sectionCalls.suffix(2) == ["summary", "repairSummary"])
        let repair = try #require(service.summaryRepairs.first)
        #expect(repair.kept.first == "I work as a head of sound.")
        #expect(repair.rejected.contains { $0.hasPrefix("\"He is a sound engineer.\": it speaks of the person in the third person") })
        let summary = try #require(draft.summary)
        #expect(SentenceSplitter.sentences(in: summary).count <= 4)
        #expect(summary.hasPrefix("I work as a head of sound."))
    }

    // MARK: Failures

    @Test("A request that fails stops the writing: the draft keeps what the earlier ones gave, and the log names the step", arguments: [
        ("job 1", "jobs"), ("tools", "skills"), ("softSkills", "skills"), ("summary", "summary"),
    ])
    func failingStep(request: String, step: String) async throws {
        let logger = RecordingLogger()
        let service = service()
        service.sectionFailures[request] = [CVGenerationError.generationFailed]

        let draft = try await draft(service, logger: logger)

        #expect(service.sectionCalls.last == request)
        #expect(logger.entry("draft.unwritten")?.line == "draft.unwritten step=\(step) error=CVGenerationError.generationFailed")
        #expect(logger.entry("draft.unwritten")?.level == .notice)
        #expect(job("Fenwick Playhouse", in: draft)?.description?.contains("I moved the scenery between scenes.") == true)
        #expect(job("Fenwick Playhouse", in: draft)?.startDate == "2013")
        #expect(draft.skills.isEmpty == (step != "summary"))
        #expect(draft.summary == nil)
    }

    @Test("A request that runs out of time, or fails twice below the model, stops the writing like a failure", arguments: [
        "timedOut", "serviceFailed",
    ])
    func timeoutAndRetries(how: String) async throws {
        let logger = RecordingLogger()
        let service = service()
        if how == "timedOut" {
            service.sectionDelays["job 0"] = .seconds(30)
        } else {
            service.sectionFailures["job 0"] = [CVGenerationError.serviceFailed, CVGenerationError.serviceFailed]
        }
        let limits = DraftingLimits(extraction: .seconds(30), section: .milliseconds(20))

        let draft = try await draft(service, limits: limits, logger: logger)

        #expect(service.sectionCalls == (how == "timedOut" ? ["job 0"] : ["job 0", "job 0"]))
        let error = how == "timedOut" ? "generationFailed" : "serviceFailed"
        #expect(logger.entry("draft.unwritten")?.line == "draft.unwritten step=jobs error=CVGenerationError.\(error)")
        #expect(logger.entries("draft.retried").map(\.line) == (how == "timedOut" ? [] : [
            "draft.retried stage=writing error=CVGenerationError.serviceFailed",
        ]))
        #expect(draft.experience.count == 4)
        #expect(draft.summary == nil && draft.skills.isEmpty)
    }

    @Test("A request that fails once below the model is tried again, and the draft goes on")
    func retriedOnce() async throws {
        let service = service()
        service.sectionFailures["tools"] = [CVGenerationError.serviceFailed]

        let draft = try await draft(service)

        #expect(service.sectionCalls.filter { $0 == "tools" }.count == 2)
        #expect(service.sectionCalls.last == "summary")
        #expect(draft.summary == Self.summary)
    }

    @Test("A draft cancelled while a section is written throws the cancellation, and nothing more is asked")
    func cancellation() async throws {
        let service = service()
        let holder = TaskHolder()
        service.sectionDelays["job 1"] = .seconds(30)
        service.onSection = { if $0 == "job 1" { holder.task?.cancel() } }
        let generator = generator(service)
        let description = description
        holder.task = Task { @MainActor in try await generator.generateCV(from: CVGenerationRequest(userPrompt: description)) }

        await #expect(throws: CancellationError.self) { try await holder.task?.value }
        #expect(service.sectionCalls == ["job 0", "job 1"])
    }

    @Test("A draft of no role asks no section")
    func noRoleNoSection() async {
        let service = FakeCVGenerationService()
        service.generateResult = .success(CVData(interests: ["chess"]))

        _ = try? await generator(service).generateCV(from: CVGenerationRequest(userPrompt: "This is a test of the app, I like chess."))

        #expect(service.sectionCalls.isEmpty)
    }

    // MARK: The log

    @Test("The log says what the sections kept, in counts, with no word of the draft")
    func log() async throws {
        let logger = RecordingLogger()

        _ = try await draft(service(), logger: logger)

        #expect(logger.entry("draft.written")?.line == "draft.written summary=true roles=4 technologies=7 softSkills=3")
        #expect(logger.entry("draft.written")?.level == .info)
        #expect(logger.entry("draft.unwritten") == nil)
        for line in logger.entries("draft.written").map(\.line) {
            #expect(!line.contains("sound") && !line.contains("mixing"), "The log holds no word of the draft")
        }
    }

    // MARK: The place after an employer

    @Test("The place after an employer is the capitalised words after its preposition, in any of the six languages")
    func placeAfterEmployer() {
        #expect(CVDataSanitizer.place(after: "Fenwick Playhouse", in: description) == "Norwich")
        #expect(CVDataSanitizer.place(after: "Conserve Albarella", in: JobClausesTests.italian) == "Termoli")
        #expect(CVDataSanitizer.place(after: "birrificio valtrigno", in: JobClausesTests.italian) == "Campobasso")
        #expect(CVDataSanitizer.place(after: "Brightwater Events", in: description) == nil)
        #expect(CVDataSanitizer.place(after: "Atelier Morel", in: "J'ai travaillé chez Atelier Morel, à Saint-Étienne Nord.") == "Saint-Étienne Nord")
        #expect(CVDataSanitizer.place(after: "Atelier Morel", in: "Atelier Morel, à lyon, puis Atelier Morel à Lyon.") == "Lyon")
        #expect(CVDataSanitizer.place(after: " ", in: description) == nil)
    }

    // MARK: The employer with the noun of its kind

    private static let spanish = """
        Soy Lucía Ferrer, contable en Huesca. Desde 2019 trabajo en Talleres Cinca, donde llevo las cuentas. Antes, de 2015 a \
        2019, trabajé en la gestoría Sarrablo y Pons.
        """

    @Test("An employer written after the noun of its kind and an article takes the noun; one written otherwise stays as it is")
    func employerWithItsKind() {
        #expect(CVDataSanitizer.employer("Sarrablo y Pons", in: Self.spanish, language: .spanish) == "gestoría Sarrablo y Pons")
        #expect(CVDataSanitizer.employer("Pixel Gaúcho", in: "Antes, de 2015 a 2019, trabalhei na agência Pixel Gaúcho.",
                                         language: .portuguese) == "agência Pixel Gaúcho")
        #expect(CVDataSanitizer.employer("Talleres Cinca", in: Self.spanish, language: .spanish) == "Talleres Cinca")
        #expect(CVDataSanitizer.employer("gestoría Sarrablo y Pons", in: Self.spanish, language: .spanish) == "gestoría Sarrablo y Pons")
        #expect(CVDataSanitizer.employer("Sarrablo y Pons", in: "Trabajé gestionando Sarrablo y Pons.", language: .spanish) == "Sarrablo y Pons")
        #expect(CVDataSanitizer.employer("Sarrablo y Pons", in: "Trabajé en la 2 Sarrablo y Pons.", language: .spanish) == "Sarrablo y Pons")
        #expect(CVDataSanitizer.employer("Sarrablo y Pons", in: Self.spanish, language: nil) == "Sarrablo y Pons")
    }

    @Test("A job the extraction names without the noun of its kind keeps the years its request read (es-traps, #354)")
    func employerWithItsKindKeepsItsYears() async throws {
        let service = FakeCVGenerationService()
        service.generateResult = .success(CVData(
            personalInfo: PersonalInfo(name: "Lucía Ferrer", title: "contable"),
            experience: [
                Experience(title: "contable", company: "Talleres Cinca", current: true),
                Experience(title: "contable", company: "Sarrablo y Pons"),
            ]
        ))
        service.jobResults = [
            0: RoleWriting(startDate: "2019", endDate: nil, duties: "Llevo las cuentas. Reviso las facturas."),
            1: RoleWriting(startDate: "2015", endDate: "2019", duties: "Llevé las cuentas. Revisé las facturas."),
        ]
        service.toolsResult = [["hojas de cálculo"], ["hojas de cálculo"]]
        service.softSkillsResult = ["precisión", "organización"]
        service.summaryResult = "Trabajo como contable."
        let spanish = CVDataSanitizer(languageOfText: { _ in "es" }, lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())
        let generator = CVGeneratorUseCase(
            service: service, claimChecker: FakeClaimChecker(), logger: SilentLogger(), clock: ContinuousClock(),
            validator: DefaultCVValidator(), sanitizer: spanish, limits: .standard
        )

        let draft = try await generator.generateCV(from: CVGenerationRequest(userPrompt: Self.spanish)).cvData

        let earlier = try #require(job("gestoría Sarrablo y Pons", in: draft))
        #expect([earlier.startDate, earlier.endDate] == ["2015", "2019"])
        #expect(job("Talleres Cinca", in: draft)?.startDate == "2019")
    }
}

/// The task of a draft under test, which a request of the fake service cancels.
@MainActor
private final class TaskHolder {
    var task: Task<GeneratedDraft, any Error>?
}
