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
    /// The jobs of `JobClausesTests.english`, each said in fewer than 40 characters, so each job's request writes duties of its own
    /// (ADR 0031, D6).
    private static let briefly = """
        I have worked in live sound for theatres and touring shows for thirteen years.
        I started in 2013 as a stagehand at the Fenwick Playhouse in Norwich, where I rigged the lights until 2016.
        Then I was a sound technician at Brightwater Events from 2016 to 2019, then at Copperfield Arena from 2019 to 2021, \
        setting up the PA systems.
        Since 2021 I have been head of sound at the Orchard Lane Theatre, where I train the junior technicians.
        I am now looking for a technical manager role at a larger venue.
        """
    private let description = Self.briefly

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
    private static let tools = [["scenery flats", "rigging hardware"], ["PA systems", "microphones"], ["stage monitors"], ["mixing desks", "QLab"]]
    private static let qualities = ["teamwork", "calm under pressure", "attention to detail"]
    /// An invented answer to the summary request, which follows the opening code writes.
    private static let summary = """
        I plan the sound of each production, run the rehearsals and look after the mixing desks and stage monitors.
        """
    /// The opening code writes for the jobs of `extracted`.
    private static let opening = "I work as a head of sound."

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
        _ service: FakeCVGenerationService, limits: DraftingLimits = .standard, logger: any DiagnosticLogger = SilentLogger(),
        of text: String? = nil
    ) async throws -> CVData {
        let request = CVGenerationRequest(userPrompt: text ?? description)
        return try await generator(service, limits: limits, logger: logger).generateCV(from: request).cvData
    }

    private func job(_ company: String, in draft: CVData) -> Experience? {
        draft.experience.first { $0.company == company }
    }

    // MARK: The order of the requests

    @Test("After the facts, a request per job in order, then the tools, the soft skills and the summary, each reading the brief, the summary with its opening and work")
    func order() async throws {
        let service = service()

        _ = try await draft(service)

        #expect(service.generateRequests.count == 1)
        #expect(service.sectionCalls == ["job 0", "job 1", "job 2", "job 3", "tools", "softSkills", "summary"])
        let brief = try #require(service.sectionBriefs.first)
        #expect(service.sectionBriefs.dropLast().allSatisfy { $0 == brief })
        var summaryBrief = try #require(service.sectionBriefs.last)
        summaryBrief.opening = nil
        for number in summaryBrief.roles.indices { summaryBrief.roles[number].work = [] }
        #expect(summaryBrief == brief)
        #expect(brief.roles.map(\.title) == ["stagehand", "sound technician", "sound technician", "head of sound"])
        #expect(brief.roles[0].clauses.contains { $0.contains("rigged the lights") })
        #expect(!brief.roles[0].clauses.contains { $0.contains("Orchard Lane") })
        #expect(brief.roles[3].clauses.contains { $0.contains("junior technicians") })
    }

    @Test("The summary request reads the opening code wrote, the topics of each job's kept duties, and the tools and the qualities the checks kept, apart (#354, round 3)")
    func summaryInputs() async throws {
        let service = service()

        _ = try await draft(service)

        let brief = try #require(service.sectionCalls.firstIndex(of: "summary").map { service.sectionBriefs[$0] })
        #expect(brief.opening == Self.opening)
        #expect(brief.roles[3].work.contains("the technical rehearsals"))
        #expect(!brief.roles.flatMap(\.work).contains { $0.hasPrefix("I ") })
        let request = try #require(service.summaryRequests.first)
        #expect(request.tools.contains("mixing desks"))
        #expect(!request.tools.contains("teamwork"))
        #expect(request.qualities.contains("teamwork"))
        #expect(!request.qualities.contains("mixing desks"))
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
        #expect(head.hasPrefix("I train the junior technicians."))
        #expect(head.contains("I run the technical rehearsals."))
        #expect(job("Fenwick Playhouse", in: draft)?.location == "Norwich")
    }

    @Test("What the checks keep reaches the draft: the duties of each job, the technologies, the soft skills and the summary")
    func sectionsReachTheDraft() async throws {
        let draft = try await draft(service())

        #expect(draft.experience.allSatisfy { $0.description?.isEmpty == false })
        #expect(draft.skills.contains(Skill(name: "mixing desks", kind: .technology)))
        #expect(draft.skills.contains(Skill(name: "teamwork", kind: .softSkill)))
        #expect(draft.summary == Self.opening + " " + Self.summary)
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

    // MARK: D6

    @Test("d6: a job whose stated duties run to 40 characters keeps them alone: its request asks for no typical duty, a typical duty goes, and no repair is asked (#354, round 1)")
    func d6DescribedJobsKeepTheirOwnDuties() async throws {
        let service = service()
        service.jobResults[1] = RoleWriting(startDate: "2016", endDate: "2019", duties: "Mixing at 3 festivals.")

        let draft = try await draft(service, of: JobClausesTests.english)

        #expect(service.sectionBriefs.first?.roles.allSatisfy(\.described) == true)
        #expect(service.jobRepairs.isEmpty)
        #expect(job("Orchard Lane Theatre", in: draft)?.description
            == "I plan the sound design for each production and train the junior technicians.")
        #expect(job("Fenwick Playhouse", in: draft)?.description == "I rigged the lights and loaded the trucks.")
        let text = draft.experience.compactMap(\.description).joined(separator: " ")
        for typical in ["scenery", "backstage", "sound checks", "microphones", "technical rehearsals"] {
            #expect(!text.contains(typical), "\(typical)")
        }
    }

    @Test("d6: a job whose stated duties are under 40 characters keeps a typical duty after them (#354, round 1)")
    func d6ShortJobsKeepTypicalDuties() async throws {
        let draft = try await draft(service())

        #expect(job("Fenwick Playhouse", in: draft)?.description
            == "I rigged the lights. I moved the scenery between scenes. I kept the backstage area clear and safe.")
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

    @Test("Too few skills kept ask once for those missing and one more, none of the kept ones, with those dropped and why")
    func moreSkills() async throws {
        let service = service()
        service.toolsResult = [["mixing desks", "frequency calibration"], [], [], []]
        service.softSkillsResult = ["teamwork"]
        service.moreSkillsResult = DraftWriting(
            summary: nil, roleDescriptions: [], technologies: ["stage monitors", "PA systems", "microphones"],
            softSkills: ["reliability", "patience"]
        )

        let draft = try await draft(service)

        #expect(service.sectionCalls.filter { $0 == "moreSkills" }.count == 1)
        let request = try #require(service.moreSkillsRequests.first)
        // One more of each kind short than missing, as a rule may drop one of them.
        #expect(request.tools == 4 && request.qualities == 3)
        #expect(request.listedTools == ["mixing desks"] && request.listedQualities == ["teamwork"])
        #expect(request.rejected == ["\"frequency calibration\": an activity, not a tool"])
        #expect(draft.skills.contains(Skill(name: "PA systems", kind: .technology)))
        #expect(draft.skills.contains(Skill(name: "patience", kind: .softSkill)))
    }

    @Test("A written tool of the kind of a tool the person names goes; the named one stays (#354, round 2)")
    func toolOfAStatedKind() async throws {
        let service = service()
        service.generateResult = .success(CVData(experience: Self.extracted.experience, skills: [Skill(name: "PA systems", kind: .technology)]))
        service.toolsResult = [["scenery flats"], ["line array systems", "microphones"], ["stage monitors"], ["mixing desks", "QLab"]]

        let draft = try await draft(service)

        #expect(draft.skills.contains { $0.name == "PA systems" })
        #expect(!draft.skills.contains { $0.name == "line array systems" })
        #expect(draft.skills.contains { $0.name == "microphones" })
    }

    @Test("A kind of tool with a word of its trade stays when the CV would list too few tools; a bare kind goes (#354, round 4)")
    func tradeKindFillsTooFewTools() async throws {
        let service = service()
        service.toolsResult = [["software"], ["stage monitors"], ["cue playback software"], []]

        let draft = try await draft(service)

        #expect(draft.skills.contains(Skill(name: "cue playback software", kind: .technology)))
        #expect(!draft.skills.contains { $0.name == "software" })
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
        #expect(repair.kept == ["I keep every show running smoothly."])
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
        #expect(draft.summary == Self.opening + " " + Self.summary)
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

    // MARK: A stated technology

    @Test("A technology the person states with its verb keeps its object; one of more than four words is a clause and goes (jobs-en, #354)")
    func statedClauseIsNoTechnology() async throws {
        let service = service()
        service.generateResult = .success(Self.extracted.with(skills: [
            Skill(name: "mix on digital desks"), Skill(name: "edit the voice tracks for the podcasts"),
        ]))
        let description = self.description + "\nI mix on digital desks and edit the voice tracks for the podcasts."

        let draft = try await generator(service).generateCV(from: CVGenerationRequest(userPrompt: description)).cvData

        let names = draft.skills.filter { $0.kind == .technology }.map(\.name)
        #expect(names.contains("digital desks"), "\(names)")
        #expect(!names.contains { $0.contains("voice tracks") }, "\(names)")
    }

    @Test("D8: the work the person says they like doing is a soft skill in their own words; a pastime they like is none (#354, round 3)",
          arguments: [
              ("I stay calm under pressure and I like working closely with choreographers.", "working closely with choreographers"),
              ("I stay calm under pressure and I like baking rye bread.", nil),
          ])
    func likedWorkIsASoftSkill(sentence: String, quality: String?) async throws {
        let draft = try await generator(service()).generateCV(from: CVGenerationRequest(userPrompt: description + "\n" + sentence)).cvData

        let qualities = draft.skills.filter { $0.kind == .softSkill }.map(\.name)
        if let quality {
            #expect(qualities.contains(quality), "\(qualities)")
        } else {
            #expect(!qualities.contains { $0.contains("baking") || $0.contains("bread") }, "\(qualities)")
        }
    }
}

/// The task of a draft under test, which a request of the fake service cancels.
@MainActor
private final class TaskHolder {
    var task: Task<GeneratedDraft, any Error>?
}
