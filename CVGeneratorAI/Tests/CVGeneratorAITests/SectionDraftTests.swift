import DiagnosticLogging
import DiagnosticLoggingTestSupport
import DiagnosticTrace
import Foundation
import Testing
@testable import CVGeneratorAI

/// A draft written a section at a time (ADR 0031, "A request per section"): after the facts, a request per job, then the tools and
/// the soft skills, then the summary, each answer checked inside its step; the first request that fails leaves its part unwritten,
/// the second stops the writing, and the draft keeps what the earlier ones gave. The description and every answer are invented.
@MainActor
@Suite("A draft written a section at a time (ADR 0031)", .plainDraft)
struct SectionDraftTests {
    /// A sanitizer that reads every text as English and tags the verbs of the description and of the answers as verbs: the checks
    /// then read the same on every platform, with the device's language data or without.
    private let sanitizer = CVDataSanitizer(
        languageOfText: { _ in "en" }, lexicalClasses: ForcedLexicalTagger([.english: .words(Self.verbs)]), wordList: TableWordList()
    )
    static let verbs: Set<String> = [
        "have", "has", "been", "was", "is", "am", "are", "worked", "work", "started", "rigged", "loaded", "setting", "set", "mixing",
        "mixed", "helping", "plan", "train", "looking", "moved", "kept", "keep", "ran", "run", "looked", "look", "won", "check",
    ]
    /// The jobs of `JobClausesTests.english`, each said in a short duty or none, so each job's request writes the typical duties
    /// that reach three (ADR 0031, O1).
    static let briefly = """
        I have worked in live sound for theatres and touring shows for thirteen years.
        I started in 2013 as a stagehand at the Fenwick Playhouse in Norwich, where I rigged the lights until 2016.
        Then I was a sound technician at Brightwater Events from 2016 to 2019, then at Copperfield Arena from 2019 to 2021, \
        setting up the PA systems.
        Since 2021 I have been head of sound at the Orchard Lane Theatre, where I train the junior technicians.
        I am now looking for a technical manager role at a larger venue.
        """
    private let description = Self.briefly

    /// The jobs of the description as the extraction gives them: the titles, the employers and which job goes on, and no date.
    static let extracted = CVData(experience: [
        Experience(title: "stagehand", company: "Fenwick Playhouse"),
        Experience(title: "sound technician", company: "Brightwater Events"),
        Experience(title: "sound technician", company: "Copperfield Arena"),
        Experience(title: "head of sound", company: "Orchard Lane Theatre", current: true),
    ])

    /// Invented answers that state no fact of their own, each job in the form of the person's own duties.
    static let jobs: [Int: RoleWriting] = [
        0: RoleWriting(startDate: "2013", endDate: "2016", duties: "I moved the scenery between scenes. I kept the backstage area clear and safe."),
        1: RoleWriting(startDate: "2016", endDate: "2019", duties: "I ran the sound checks with each band. I looked after the microphones and cables."),
        2: RoleWriting(startDate: "2019", endDate: "2021", duties: "I ran the sound checks before each concert. I looked after the stage monitors."),
        3: RoleWriting(startDate: "2021", endDate: nil, duties: "I run the technical rehearsals. I look after the mixing desks and the stage monitors."),
    ]
    static let tools = [["scenery flats", "rigging hardware"], ["PA systems", "microphones"], ["stage monitors"], ["mixing desks", "QLab"]]
    static let qualities = ["teamwork", "calm under pressure", "attention to detail"]
    /// An invented answer to the summary request, which follows the opening code writes.
    static let summary = """
        I plan the sound of each production and keep the mixing desks and monitors ready for every show.
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
        _ service: FakeCVGenerationService, limits: DraftingLimits = .onTestClock(), logger: any DiagnosticLogger = SilentLogger()
    ) -> CVGeneratorUseCase {
        CVGeneratorUseCase(
            service: service, claimChecker: FakeClaimChecker(), logger: logger, clock: ContinuousClock(),
            tracer: NoTracer(), validator: DefaultCVValidator(), sanitizer: sanitizer, limits: limits
        )
    }

    private func draft(
        _ service: FakeCVGenerationService, limits: DraftingLimits = .onTestClock(), logger: any DiagnosticLogger = SilentLogger(),
        of text: String? = nil
    ) async throws -> CVData {
        let request = CVGenerationRequest(userPrompt: text ?? description)
        return try await generator(service, limits: limits, logger: logger).generateCV(from: request).cvData
    }

    private func job(_ company: String, in draft: CVData) -> Experience? {
        draft.experience.first { $0.company == company }
    }

    // MARK: The order of the requests

    @Test("After the facts, a request per job in order, then the tools, the soft skills and the summary, each reading the brief, the summary with its opening")
    func order() async throws {
        let service = service()

        _ = try await draft(service)

        #expect(service.generateRequests.count == 1)
        #expect(service.sectionCalls == ["job 0", "job 1", "job 2", "job 3", "tools", "tools", "tools", "softSkills", "summary"])
        // The two jobs of sound technician ask for their tools once (#354).
        // The headline title's first: the current job's (#354).
        #expect(service.toolsRequests == [[3], [0], [1, 2]])
        #expect(service.toolsCounts == [2...3, 2...3, 2...3])
        let brief = try #require(service.sectionBriefs.first)
        #expect(service.sectionBriefs.dropLast().allSatisfy { $0 == brief })
        var summaryBrief = try #require(service.sectionBriefs.last)
        summaryBrief.opening = nil
        // The summary reads a job as ended by the years its own request read (#354).
        #expect(summaryBrief.roles.map(\.hasEnded) == [true, true, true, false])
        for number in summaryBrief.roles.indices {
            summaryBrief.roles[number].hasEnded = brief.roles[number].hasEnded
        }
        #expect(summaryBrief == brief)
        #expect(brief.roles.map(\.title) == ["stagehand", "sound technician", "sound technician", "head of sound"])
        #expect(brief.roles[0].clauses.contains { $0.contains("rigged the lights") })
        #expect(!brief.roles[0].clauses.contains { $0.contains("Orchard Lane") })
        #expect(brief.roles[3].clauses.contains { $0.contains("junior technicians") })
    }

    @Test("A career of more titles than the draft writes jobs for asks the tools of ten titles at most, the current title first")
    func toolsRequestsAreCapped() async throws {
        let titles = [
            "baker", "cook", "waiter", "porter", "driver", "cleaner", "gardener", "painter", "welder", "tailor", "cashier", "clerk",
        ]
        let employers = [
            "Alpha Bakery", "Bravo Kitchen", "Cedar Cafe", "Delta Depot", "Echo Express", "Foxtrot Cleaning", "Garden House",
            "Harbour Paints", "Iron Works", "Jolly Tailors", "Kilo Shop", "Lima Office",
        ]
        let service = service()
        service.generateResult = .success(CVData(experience: zip(titles, employers).map { Experience(title: $0, company: $1) }))
        service.toolsResult = titles.indices.map { ["tool \($0)"] }
        let text = zip(titles, employers).map { "I worked as a \($0) at \($1)." }.joined(separator: "\n")

        _ = try await draft(service, of: text)

        #expect(service.sectionCalls.filter { $0 == "tools" }.count == SectionDraft.writtenJobs)
        // The current job's title (the fourth, by the years of the jobs' answers) first, the others in their order, the last two none.
        let asked = [3] + (0..<SectionDraft.writtenJobs).filter { $0 != 3 }
        #expect(service.toolsRequests == asked.map { [$0] })
        #expect(service.toolsCounts == Array(repeating: 2...3, count: SectionDraft.writtenJobs))
    }

    @Test("A job whose clauses only say where the person worked is marked so, and its request asks for typical duties alone (#354)")
    func jobThatNamesNoWork() async throws {
        let service = service()
        service.generateResult = .success(CVData(experience: [
            Experience(title: "sound technician", company: "Brightwater Events"),
            Experience(title: "head of sound", company: "Orchard Lane Theatre", current: true),
        ]))
        service.jobResults = [
            0: RoleWriting(startDate: "2016", endDate: "2021", duties: "I ran the sound checks with each band. I looked after the microphones."),
            1: RoleWriting(startDate: "2021", endDate: nil, duties: "I run the technical rehearsals."),
        ]
        let text = """
            From 2016 to 2021 I worked at Brightwater Events.
            Since 2021 I have been head of sound at the Orchard Lane Theatre, where I train the junior technicians.
            """

        _ = try await draft(service, of: text)

        let brief = try #require(service.sectionBriefs.first)
        #expect(brief.roles[0].clauses.contains { $0.contains("Brightwater") })
        #expect(brief.roles.map(\.clausesNameWork) == [false, true])
    }

    @Test("A single title asks its tools all at once, as many as the CV needs and one more; titles among others ask 2 or 3 each (#354), but a rich draft's headline title",
          arguments: [
              (0, 1, false, 4...5, 10...11), (0, 1, true, 3...4, 6...7), (0, 2, false, 2...3, 10...11), (1, 2, false, 2...3, 2...3),
              (2, 3, false, 2...3, 2...3),
          ] as [(Int, Int, Bool, ClosedRange<Int>, ClosedRange<Int>)])
    func toolCount(group: Int, groups: Int, sparse: Bool, count: ClosedRange<Int>, rich: ClosedRange<Int>) {
        // One title asked 2 or 3: the CV was always short, and the request for those missing named activities and bare kinds.
        DraftDepth.$pinned.withValue(false) { #expect(SectionDraft.toolCount(group: group, groups: groups, sparse: sparse) == count) }
        DraftDepth.$pinned.withValue(true) { #expect(SectionDraft.toolCount(group: group, groups: groups, sparse: sparse) == rich) }
    }

    @Test("A past title's answer adds only its first kept tool, and only while the CV is short of tools of the trade (#354)")
    func mergedTools() {
        // Each tool counts as one of the trade but "trailer", which the check drops.
        let count = { (tools: [String]) in tools.filter { $0 != "trailer" }.count }
        let none = { (_: String) in false }
        // The headline title's answer is short of 4: the past title's adds its first kept tool, not the 2 after it.
        #expect(SectionDraft.mergedTools([["SAP", "Excel", "barcode scanner"], ["trailer", "forklift", "GPS"]], fewest: 4, isKind: none, tradeTools: count)
            == ["SAP", "Excel", "barcode scanner", "forklift"])
        // The headline title's answer already reaches the floor: the past title's adds nothing.
        #expect(SectionDraft.mergedTools(
            [["digital console", "QLab", "stage monitors", "wireless microphones"], ["truck loading equipment", "rigging hardware"]],
            fewest: 4, isKind: none, tradeTools: count
        ) == ["digital console", "QLab", "stage monitors", "wireless microphones"])
        // Two past titles each add one, the second only while the first left the CV short.
        #expect(SectionDraft.mergedTools([["SAP"], ["forklift", "GPS"], ["pallet jack", "RF gun"], ["shrink wrapper"]], fewest: 3, isKind: none, tradeTools: count)
            == ["SAP", "forklift", "pallet jack"])
        // A single title's answer stays as it was.
        #expect(SectionDraft.mergedTools([["SAP", "trailer", "GPS"]], fewest: 4, isKind: none, tradeTools: count) == ["SAP", "trailer", "GPS"])
        #expect(SectionDraft.mergedTools([], fewest: 4, isKind: none, tradeTools: count).isEmpty)

        // A past title's answer adds a tool before a kind of system it lists first ("Montagesystem"), and the kind when it has no
        // other.
        let kind = { (tool: String) in CVDataSanitizer.endsInAKindOfTool(tool, language: "de") }
        #expect(SectionDraft.mergedTools([["KNX"], ["Montagesystem", "Werkzeugkasten", "Sicherheitsgurte"]], fewest: 4, isKind: kind, tradeTools: count)
            == ["KNX", "Werkzeugkasten"])
        #expect(SectionDraft.mergedTools([["KNX"], ["Montagesystem"]], fewest: 4, isKind: kind, tradeTools: count) == ["KNX", "Montagesystem"])
    }

    @Test("The headline title's tools are asked first: the job of the headline title, else the latest job (#354)")
    func headlineFirst() {
        let roles: [DraftBrief.Role] = [
            .init(title: "stagehand", hasEnded: true), .init(title: "sound technician", hasEnded: true),
            .init(title: "sound technician", hasEnded: true), .init(title: "Head of Sound", hasEnded: false),
        ]
        let titled = DraftBrief(language: "English", headline: "head of sound", roles: roles, studies: [], namedSkills: [])
        let untitled = DraftBrief(language: "English", headline: nil, roles: roles, studies: [], namedSkills: [])
        let groups = [[0], [1, 2], [3]]
        #expect(SectionDraft.headlineRole(of: titled, order: [0, 1, 2, 3]) == 3)
        #expect(SectionDraft.headlineRole(of: untitled, order: [2, 1, 0, 3]) == 2)
        #expect(SectionDraft.headlineFirst(groups, headline: 3) == [[3], [0], [1, 2]])
        #expect(SectionDraft.headlineFirst(groups, headline: 2) == [[1, 2], [0], [3]])
        #expect(SectionDraft.headlineFirst(groups, headline: nil) == groups)
        #expect(SectionDraft.headlineFirst([[0]], headline: 0) == [[0]])
    }

    @Test("o1: each summary request reads the opening code wrote, the sentences kept so far and one slot: the role, the current job's work, two qualities, then the ended jobs (#354)")
    func summaryInputs() async throws {
        let service = service()
        // No sentence kept: the summary asks a slot each time, up to its most requests.
        service.summaryResult = nil

        let draft = try await draft(service)

        let brief = try #require(service.sectionCalls.firstIndex(of: "summary").map { service.sectionBriefs[$0] })
        #expect(brief.opening == Self.opening)
        let topics = service.summaryRequests.map(\.topic)
        #expect(topics.count == SectionDraft.summaryRequests)
        #expect(service.summaryRequests.allSatisfy { $0.written == [Self.opening] })
        #expect(topics.prefix(3).allSatisfy { $0.title == "head of sound" && !$0.hasEnded })
        #expect(topics.first.map { $0.work.isEmpty && $0.qualities.isEmpty } == true)
        // O1: the work of the current job's kept duties, typical ones too (D16 withdrawn).
        #expect(topics.dropFirst().first.map { !$0.work.isEmpty && $0.qualities.isEmpty } == true)
        let qualities = Array(draft.skills.filter { $0.kind == .softSkill }.map(\.name).prefix(2))
        #expect(qualities.count == 2)
        #expect(topics.dropFirst(2).first?.qualities == qualities)
        #expect(topics.dropFirst(3).allSatisfy { $0.hasEnded && $0.work.count == 1 })
    }

    @Test("o1: the summary's slots are the current job's role and field, the topics of its first two kept duties, two qualities, then the first kept duty of each other job (#354)")
    func summaryTopics() {
        let brief = DraftBrief(
            language: "English", headline: "head of sound",
            roles: [
                .init(title: "stagehand", hasEnded: true), .init(title: "sound technician", hasEnded: true),
                .init(title: "head of sound", hasEnded: false),
            ],
            studies: [], namedSkills: []
        )
        let duties = [["I rigged the lights."], [], ["I train the junior technicians.", "I plan the rehearsals.", "I mix the shows."]]

        // The current job's duties are all its own: its work slot falls back on them.
        let topics = SectionDraft.summaryTopics(
            of: brief, duties: duties, typical: [[], [], []], qualities: ["teamwork", "calm", "care"], field: "live sound", order: [2, 1, 0]
        )

        #expect(topics == [
            SummaryTopic(title: "head of sound", field: "live sound", hasEnded: false),
            SummaryTopic(title: "head of sound", work: ["the junior technicians", "the rehearsals"], hasEnded: false),
            SummaryTopic(title: "head of sound", qualities: ["teamwork", "calm"], hasEnded: false),
            SummaryTopic(title: "stagehand", work: ["the lights"], hasEnded: true),
        ])
        // With typical duties, the work slot reads them, never the duty the person said and the job already shows.
        let typical = SectionDraft.summaryTopics(
            of: brief, duties: duties, typical: [[], [], ["I plan the rehearsals.", "I mix the shows."]], qualities: [],
            field: nil, order: [2, 1, 0]
        )
        #expect(typical.dropFirst().first == SummaryTopic(title: "head of sound", work: ["the rehearsals", "the shows"], hasEnded: false))
        // The pair: no duty and no quality leave the role alone; no role leaves the qualities with the headline.
        #expect(SectionDraft.summaryTopics(of: brief, duties: [[], [], []], typical: [], qualities: [], field: nil, order: [2, 1, 0]) == [
            SummaryTopic(title: "head of sound", hasEnded: false),
        ])
        #expect(SectionDraft.summaryTopics(of: brief, duties: [], typical: [], qualities: ["teamwork", "calm"], field: nil, order: []) == [
            SummaryTopic(title: "head of sound", qualities: ["teamwork", "calm"], hasEnded: false),
        ])
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
            duties: "I mixed 40 shows at the Royal Albert Hall. I look after the mixing desks."
        )
        service.toolsResult = Self.tools.dropLast() + [Self.tools[3] + ["Dante Level 3 certification"]]
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

    // MARK: O1, three to four duties a job (#354; D6 withdrawn)

    @Test("o1: a job whose stated duties run to 40 characters keeps them first, then the typical duties that reach three")
    func describedJobsGetTypicalDuties() async throws {
        let service = service()
        service.jobResults[1] = RoleWriting(startDate: "2016", endDate: "2019", duties: "Mixing at 3 festivals.")

        let draft = try await draft(service, of: JobClausesTests.english)

        #expect(service.sectionBriefs.first?.roles.allSatisfy { $0.adding > 0 } == true)
        let orchard = try #require(job("Orchard Lane Theatre", in: draft)?.description)
        #expect(orchard.hasPrefix("I plan the sound design for each production and train the junior technicians."))
        #expect(orchard.contains("I run the technical rehearsals."))
        let fenwick = try #require(job("Fenwick Playhouse", in: draft)?.description)
        #expect(fenwick.hasPrefix("I rigged the lights and loaded the trucks."))
        #expect(fenwick.contains("I moved the scenery between scenes."))
    }

    @Test("o1: a job whose years the extraction read still gets a request for the typical duties it needs")
    func jobsWithTheirYearsStillAsk() async throws {
        let service = service()
        service.generateResult = .success(CVData(experience: [
            Experience(title: "stagehand", company: "Fenwick Playhouse", startDate: "2013", endDate: "2016"),
            Experience(title: "sound technician", company: "Brightwater Events", startDate: "2016", endDate: "2019"),
            Experience(title: "sound technician", company: "Copperfield Arena", startDate: "2019", endDate: "2021"),
            Experience(title: "head of sound", company: "Orchard Lane Theatre", startDate: "2021", current: true),
        ]))

        let draft = try await draft(service, of: JobClausesTests.english)

        #expect(service.sectionCalls.filter { $0.hasPrefix("job ") } == ["job 0", "job 1", "job 2", "job 3"])
        #expect(job("Fenwick Playhouse", in: draft)?.description?.hasPrefix("I rigged the lights and loaded the trucks.") == true)
        #expect(job("Fenwick Playhouse", in: draft)?.startDate == "2013")
        #expect(job("Orchard Lane Theatre", in: draft)?.current == true)
    }

    @Test("o1: a job keeps its stated duty and the typical duties it needs to reach three, no more (#354)")
    func shortJobsKeepTypicalDutiesToThree() async throws {
        let service = service()
        service.jobResults[0] = RoleWriting(
            startDate: "2013", endDate: "2016",
            duties: "I rigged the lights. I moved the scenery between scenes. I kept the backstage area clear and safe. I checked the fly lines."
        )

        let draft = try await draft(service)

        let role = try #require(service.sectionBriefs.first?.roles.first)
        #expect(role.said == 1 && role.adding == 2)
        #expect(job("Fenwick Playhouse", in: draft)?.description
            == "I rigged the lights. I moved the scenery between scenes. I kept the backstage area clear and safe.")
    }

    @Test("o1: a job with no title and no duty of its own gets three duties typical of the headline title, and no title")
    func untitledJobGetsTheHeadlineDuties() async throws {
        // As es-traps: the headline and a current job of that title, then an earlier job the person only named.
        let text = """
            I am a sound technician in Leeds. Since 2019 I have worked at the Orchard Lane Theatre, where I run the sound checks.
            Before, from 2014 to 2019, I worked at Brightwater Events.
            """
        let service = service()
        service.generateResult = .success(CVData(
            personalInfo: PersonalInfo(title: "sound technician"),
            experience: [
                Experience(title: "sound technician", company: "Orchard Lane Theatre", startDate: "2019", current: true),
                Experience(title: "", company: "Brightwater Events", startDate: "2014", endDate: "2019"),
            ]
        ))
        service.jobResults = [
            0: RoleWriting(startDate: "2019", endDate: nil, duties: "I run the sound checks. I look after the mixing desks. I set up the stage monitors."),
            1: RoleWriting(
                startDate: "2014", endDate: "2019",
                duties: "I ran the sound checks with each band. I looked after the microphones and cables. I set up the stage monitors."
            ),
        ]

        let draft = try await draft(service, of: text)

        let brief = try #require(service.sectionBriefs.first)
        #expect(brief.roles.map(\.title) == ["sound technician", ""])
        #expect(brief.roles.last?.said == 0 && brief.roles.last?.adding == 3)
        #expect(SectionPrompts.job(number: 1, of: brief).text.contains("Headline title: sound technician"))
        let job = try #require(job("Brightwater Events", in: draft))
        #expect(job.title.isEmpty)
        #expect(job.description
            == "I ran the sound checks with each band. I looked after the microphones and cables. I set up the stage monitors.")
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
        // The job needs typical duties to reach three, and the repair asked for exactly those missing: both stay (O1).
        let duties = try #require(job("Brightwater Events", in: draft)?.description)
        #expect(duties.contains("I ran the sound checks with each band."))
        #expect(duties.contains("I looked after the microphones and cables."))
    }

    @Test("Too few skills kept ask for those missing and one more, the tools apart from the qualities, none of the kept ones, with those dropped and why (#354)")
    func moreSkills() async throws {
        let service = service()
        service.toolsResult = [[], [], [], ["mixing desks", "equipment"]]
        service.softSkillsResult = ["teamwork"]
        service.moreSkillsResult = DraftWriting(
            summary: nil, roleDescriptions: [], technologies: ["stage monitors", "PA systems", "document management system", "microphones"],
            softSkills: ["reliability", "patience"]
        )

        let draft = try await draft(service)

        #expect(service.sectionCalls.filter { $0 == "moreSkills" }.count == 2)
        // One more of each kind short than missing, as a rule may drop one of them; asked with the qualities, the tools came back as
        // a bare kind and a bare record, asked alone as a system (a method is a technical skill).
        #expect(service.moreSkillsRequests.map { [$0.tools, $0.qualities] } == [[4, 0], [0, 3]])
        for request in service.moreSkillsRequests {
            #expect(request.listedTools == ["mixing desks"] && request.listedQualities == ["teamwork"])
            #expect(request.rejected == ["\"equipment\": a general kind, not a named tool"])
        }
        #expect(draft.skills.contains(Skill(name: "PA systems", kind: .technology)))
        #expect(draft.skills.contains(Skill(name: "patience", kind: .softSkill)))
        // The tools of the headline title, the latest job's here; a general kind of the work they wrote goes (#354).
        #expect(service.moreSkillsRequests.map(\.title) == ["head of sound", "head of sound"])
        #expect(!draft.skills.contains { $0.name == "document management system" })
    }

    @Test("A written tool of the kind of a tool the person names goes; the named one stays, and so does one of a generic kind (#354)")
    func toolOfAStatedKind() async throws {
        let service = service()
        service.generateResult = .success(CVData(experience: Self.extracted.experience, skills: [Skill(name: "digital consoles", kind: .technology)]))
        // The headline title's answer: a past title's adds only one while the CV is short (#354).
        service.toolsResult = [["scenery flats"], ["stage monitors"], [], ["audio mixing console", "microphones", "line array systems"]]

        let draft = try await draft(service, of: description + "\nI mix on digital consoles.")

        #expect(draft.skills.contains { $0.name == "digital consoles" })
        #expect(!draft.skills.contains { $0.name == "audio mixing console" })
        #expect(draft.skills.contains { $0.name == "microphones" })
        // "systems" is a generic kind, so the PA systems the person sets up are no kind of their own.
        #expect(draft.skills.contains { $0.name == "line array systems" })
    }

    @Test("A kind of tool with a word of its trade stays though the CV lists enough tools; a bare kind goes (#354)")
    func tradeKindStays() async throws {
        let service = service()
        service.toolsResult = [
            ["scenery flats", "rigging hardware"], ["PA systems", "microphones"], ["stage monitors"],
            ["mixing desks", "QLab", "software", "cue playback software"],
        ]

        let draft = try await draft(service)

        #expect(draft.skills.contains(Skill(name: "cue playback software", kind: .technology)))
        #expect(!draft.skills.contains { $0.name == "software" })
    }

    @Test("A summary sentence of clauses each opened by the person, joined by semicolons, is cut into sentences, at most four with the opening (#354)")
    func chainedSummaryIsCut() async throws {
        let service = service()
        service.summaryResult = """
            I plan the sound of each production with the mixing desks; I check the stage monitors for every singer; I train the \
            technicians before the tours; I keep the microphones ready.
            """

        let draft = try await draft(service)

        let summary = try #require(draft.summary)
        #expect(!summary.contains(";"))
        #expect(summary.contains("I plan the sound of each production with the mixing desks. I check the stage monitors for every singer."))
        #expect(SentenceSplitter.sentences(in: summary).count == 4)
    }

    @Test("A semicolon the person's own clause does not follow stays in its sentence (#354)", arguments: [
        ("I look after the mixing desks; cables, stands and cases too.", "I look after the mixing desks; cables, stands and cases too."),
        ("I run the sound checks; I train the crew.", "I run the sound checks. I train the crew."),
        ("Je règle les consoles ; j'accompagne les tournées.", "Je règle les consoles. J'accompagne les tournées."),
        ("Ich prüfe die Pulte; ich schule das Team.", "Ich prüfe die Pulte. Ich schule das Team."),
        ("Preparo i banchi; i cavi restano in ordine.", "Preparo i banchi; i cavi restano in ordine."),
    ])
    func semicolonBeforeAClause(text: String, cut: String) {
        #expect(SentenceSplitter.unchained(text) == cut)
    }

    @Test("A request's text is cut at each semicolon the person's clause follows, a German separable verb split at a clause's end is joined, a sentence loses the relative word it opens with, and a verb loses the noun of its own action before its object (#354)", arguments: [
        ("Ich prüfe die Pulte; ich schule das Team, damit es die Mikrofone richtig an schließt.", "Ich prüfe die Pulte. Ich schule das Team, damit es die Mikrofone richtig anschließt."),
        ("Ich schule das Team und stelle die Pulte ein.", "Ich schule das Team und stelle die Pulte ein."),
        ("Je soigne les chevaux du haras. Où j'ai dressé 4 poulains.", "Je soigne les chevaux du haras. J'ai dressé 4 poulains."),
        ("Curo i cavalli. Dove serve, ferro gli zoccoli.", "Curo i cavalli. Dove serve, ferro gli zoccoli."),
        ("Lavoro in cantina. Controllo il controllo delle botti con cura.", "Lavoro in cantina. Controllo le botti con cura."),
        ("I schedule the scheduling of the night shifts.", "I schedule the night shifts."),
        ("Planifico la planificación de las rutas del reparto.", "Planifico las rutas del reparto."),
        ("Organizo a organização dos turnos da loja.", "Organizo os turnos da loja."),
        ("J'organise l'organisation du stock.", "J'organise le stock."),
        ("Controllo il controllo con cura.", "Controllo il controllo con cura."),
        ("Insegno agli insegnanti nuovi.", "Insegno agli insegnanti nuovi."),
        ("Riparo la riparazione dell'impianto.", "Riparo l'impianto."),
    ])
    func mended(text: String, expected: String) {
        #expect(SectionDraft.mended(text) == expected)
    }

    @Test("A job's duties written as clauses joined by semicolons are cut into sentences (#354)")
    func chainedDutiesAreCut() async throws {
        let service = service()
        service.jobResults[1] = RoleWriting(
            startDate: "2016", endDate: "2019", duties: "I ran the sound checks with each band; I looked after the microphones and cables."
        )

        let draft = try await draft(service)

        let duties = try #require(job("Brightwater Events", in: draft)?.description)
        #expect(!duties.contains(";"))
        #expect(duties.contains("I ran the sound checks with each band."))
    }

    @Test("A summary whose every sentence and repair went is written by code from the titles and two qualities after its most requests, and the draft keeps it (#354)")
    func summaryFloor() async throws {
        let service = service()
        service.summaryResult = "He is a sound engineer."
        service.summaryRepairResult = "She runs the desk."

        let draft = try await draft(service)

        #expect(service.sectionCalls.filter { $0.hasSuffix("ummary") } == ["summary", "repairSummary", "summary", "repairSummary"])
        // O1: a floor still short ends with the person's strengths, from the title and two qualities (#354).
        #expect(draft.summary == "I work as a head of sound. Before that, I worked as a sound technician and a stagehand. "
            + "As a head of sound, I work with teamwork and calm under pressure.")
    }

    @Test("A rejected summary sentence gets one repair on the same topic that reads it and why it went, and the repair is kept (#354)")
    func summaryRepair() async throws {
        let service = service()
        service.summaryResults = ["He is a sound engineer."]
        service.summaryRepairResult = Self.summary

        let draft = try await draft(service)

        #expect(service.sectionCalls.suffix(2) == ["summary", "repairSummary"])
        let repair = try #require(service.summaryRepairs.first)
        #expect(repair.topic == service.summaryRequests.first?.topic)
        #expect(repair.written == [Self.opening])
        #expect(repair.rejected.hasPrefix("\"He is a sound engineer.\": it speaks of the person in the third person"))
        #expect(draft.summary == Self.opening + " " + Self.summary)
    }

    @Test("The current job's work slot reads its typical duties, and a sentence on it that says a duty again gets one repair (#354)")
    func summaryNearCopy() async throws {
        let service = service()
        let first = "I keep the sound of every show clear and balanced."
        let copy = "I train junior technicians on tour."
        service.summaryResults = [first, copy]
        service.summaryRepairResult = Self.summary

        let draft = try await draft(service)

        let work = try #require(service.summaryRequests.dropFirst().first?.topic.work)
        #expect(!work.isEmpty && !work.contains("the junior technicians"))
        #expect(service.sectionCalls.filter { $0.hasSuffix("ummary") } == ["summary", "summary", "repairSummary"])
        let repair = try #require(service.summaryRepairs.first)
        #expect(repair.rejected == "\"\(copy)\": \(CVDataSanitizer.copiesADutyReason)")
        #expect(draft.summary == [Self.opening, first, Self.summary].joined(separator: " "))
    }

    @Test("The summary asks one sentence at a time, each after those kept, until it has 2 sentences and 120 characters (#354)")
    func summaryOneSentenceAtATime() async throws {
        let service = service()
        let first = "I keep the sound of every show clear and balanced."
        service.summaryResults = [first, Self.summary, "I keep the stage calm."]

        let draft = try await draft(service)

        #expect(service.summaryRepairs.isEmpty)
        #expect(service.sectionCalls.filter { $0.hasSuffix("ummary") } == ["summary", "summary"])
        #expect(service.summaryRequests.map(\.written) == [[Self.opening], [Self.opening, first]])
        #expect(draft.summary == [Self.opening, first, Self.summary].joined(separator: " "))
    }

    @Test("A rich summary sentence written with no full stop gets one, and stays a sentence of its own")
    func richSentenceEnded() async throws {
        let service = service()
        let first = "I keep the sound of every show clear and balanced"
        service.summaryResults = [first]

        let draft = try await DraftDepth.$pinned.withValue(true) { try await draft(service) }

        let summary = try #require(draft.summary)
        #expect(SentenceSplitter.sentences(in: summary).contains(first + "."), "\(summary)")
        #expect(service.summaryRequests.dropFirst().first?.written.contains(first + ".") == true, "\(service.summaryRequests)")
    }

    // MARK: Failures

    @Test("The first request that fails leaves its part unwritten and the writing goes on, and the log names the step", arguments: [
        ("job 1", "jobs"), ("tools", "skills"), ("softSkills", "skills"), ("summary", "summary"),
    ])
    func failingStep(request: String, step: String) async throws {
        let logger = RecordingLogger()
        let service = service()
        service.sectionFailures[request] = [CVGenerationError.generationFailed]

        let draft = try await draft(service, logger: logger)

        #expect(logger.entries("draft.unwritten").map(\.line) == ["draft.unwritten step=\(step) error=CVGenerationError.generationFailed"])
        #expect(logger.entry("draft.unwritten")?.level == .notice)
        #expect(service.sectionCalls.last == "summary")
        #expect(job("Fenwick Playhouse", in: draft)?.description?.contains("I moved the scenery between scenes.") == true)
        #expect(job("Fenwick Playhouse", in: draft)?.startDate == "2013")
        #expect(!draft.skills.isEmpty)
        #expect(draft.summary?.hasPrefix(Self.opening) == true)
        // A job whose request failed gets no repair, which could fail a second time and stop the writing.
        #expect(!service.sectionCalls.contains("repairJob 1"))
        #expect(job("Brightwater Events", in: draft)?.description?.contains("I ran the sound checks with each band.") != (step == "jobs"))
    }

    @Test("A request that runs out of time, or fails twice below the model, leaves its part unwritten like a failure", arguments: [
        "timedOut", "serviceFailed",
    ])
    func timeoutAndRetries(how: String) async throws {
        let logger = RecordingLogger()
        let service = service()
        let clock = TestCallClock()
        if how == "timedOut" {
            service.sectionDelays["job 0"] = .seconds(30)
            service.onSection = { if $0 == "job 0" { clock.runOut() } }
        } else {
            service.sectionFailures["job 0"] = [CVGenerationError.serviceFailed, CVGenerationError.serviceFailed]
        }
        let limits = DraftingLimits.onTestClock(clock)

        let draft = try await draft(service, limits: limits, logger: logger)

        let asked = how == "timedOut" ? ["job 0", "job 1"] : ["job 0", "job 0", "job 1"]
        #expect(Array(service.sectionCalls.prefix(asked.count)) == asked)
        let error = how == "timedOut" ? "generationFailed" : "serviceFailed"
        #expect(logger.entries("draft.unwritten").map(\.line) == ["draft.unwritten step=jobs error=CVGenerationError.\(error)"])
        #expect(logger.entries("draft.retried").map(\.line) == (how == "timedOut" ? [] : [
            "draft.retried stage=writing error=CVGenerationError.serviceFailed",
        ]))
        #expect(draft.experience.count == 4)
        #expect(draft.summary != nil && !draft.skills.isEmpty)
    }

    @Test("A second request that fails or runs out of time stops the writing: the draft keeps what the earlier ones gave", arguments: [
        "failed", "timedOut",
    ])
    func secondFailure(how: String) async throws {
        let logger = RecordingLogger()
        let service = service()
        let clock = TestCallClock()
        if how == "timedOut" {
            service.sectionDelays["job 1"] = .seconds(30)
            service.sectionDelays["tools"] = .seconds(30)
            service.onSection = { if $0 == "job 1" || $0 == "tools" { clock.runOut() } }
        } else {
            service.sectionFailures["job 1"] = [CVGenerationError.generationFailed]
            service.sectionFailures["tools"] = [CVGenerationError.generationFailed]
        }
        let limits = DraftingLimits.onTestClock(clock)

        let draft = try await draft(service, limits: limits, logger: logger)

        #expect(service.sectionCalls == ["job 0", "job 1", "job 2", "job 3", "tools"])
        #expect(logger.entries("draft.unwritten").map(\.line) == [
            "draft.unwritten step=jobs error=CVGenerationError.generationFailed",
            "draft.unwritten step=skills error=CVGenerationError.generationFailed",
        ])
        #expect(job("Fenwick Playhouse", in: draft)?.description?.contains("I moved the scenery between scenes.") == true)
        #expect(draft.experience.count == 4)
        #expect(draft.skills.isEmpty)
        #expect(draft.summary == nil)
    }

    @Test("A request that fails once below the model is tried again, and the draft goes on")
    func retriedOnce() async throws {
        let service = service()
        service.sectionFailures["tools"] = [CVGenerationError.serviceFailed]

        let draft = try await draft(service)

        #expect(service.sectionCalls.filter { $0 == "tools" }.count == 4)
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

        // The headline title's 2 tools, then a past title's first while the CV is short of 4 (#354).
        #expect(logger.entry("draft.written")?.line == "draft.written summary=true roles=4 technologies=4 softSkills=3")
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
            tracer: NoTracer(), validator: DefaultCVValidator(), sanitizer: spanish, limits: .onTestClock()
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

    @Test("D8: the work the person says they like doing is a soft skill in their own words; a pastime they like is none (#354)",
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
