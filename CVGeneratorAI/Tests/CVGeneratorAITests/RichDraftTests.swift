import Testing
@testable import CVGeneratorAI

/// The draft of iOS 27's model (`DraftDepth`; #354, probe rounds 3 and 4): more duties, tools and summary sentences, a summary slot
/// for the tools, and rules that ask for the tools by name. iOS 26's model keeps the plain draft, which the other suites pin. Every
/// name and trade is invented.
@MainActor
@Suite("A rich draft, of iOS 27's model (probe rounds 3 and 4)", .richDraft)
struct RichDraftTests {
    private static let brief = DraftBrief(
        language: "English", headline: "head of sound",
        roles: [
            .init(title: "stagehand", hasEnded: true), .init(title: "sound technician", hasEnded: true),
            .init(title: "head of sound", hasEnded: false),
        ],
        studies: [], namedSkills: []
    )
    private static let duties = [["I rigged the lights."], [], ["I train the junior technicians.", "I plan the rehearsals.", "I mix the shows."]]
    private static let tools = ["Pro Tools", "DiGiCo SD7", "in-ear monitors", "XLR cables", "Dante"]

    // MARK: The amounts

    @Test("Each job gets 5 to 6 duties, the person's first, at least one typical one below 6; the tools, the tokens and the summary sentences grow with them")
    func amounts() {
        #expect(DraftBrief.Role.leastDuties == 5)
        #expect(DraftBrief.Role.mostDuties == 6)
        #expect([0, 1, 4, 5, 6, 8].map(DraftBrief.Role.adding(said:)) == [5, 4, 1, 1, 0, 0])
        #expect(DraftBrief.Role(title: "stagehand", hasEnded: true).adding == 5)
        #expect(SectionDraft.technologies == 10)
        #expect(FoundationModelsService.jobTokens == 340)
        #expect(FoundationModelsService.jobRepairTokens == 280)
        #expect(FoundationModelsService.jobRepairDuties == 5)
        #expect(SectionDraft.summaryRequests == 8)
        #expect(SectionDraft.summaryEnough.sentences == 4)
        #expect(SectionDraft.summaryEnough.characters == 300)
    }

    // MARK: The summary's slots

    @Test("The summary's slots: the role, the first work, three tools, the next work, two qualities, the ended jobs, then the rest of the tools and qualities for a summary still short")
    func summaryTopics() {
        let topics = SectionDraft.summaryTopics(
            of: Self.brief, duties: Self.duties, typical: [[], [], []], qualities: ["teamwork", "calm", "care"], field: "live sound",
            order: [2, 1, 0], tools: Self.tools
        )

        // The field goes: the job has a title.
        #expect(topics == [
            SummaryTopic(title: "head of sound", hasEnded: false),
            SummaryTopic(title: "head of sound", work: ["the junior technicians", "the rehearsals"], hasEnded: false),
            SummaryTopic(title: "head of sound", tools: ["Pro Tools", "DiGiCo SD7", "in-ear monitors"], hasEnded: false),
            SummaryTopic(title: "head of sound", work: ["the shows"], hasEnded: false),
            SummaryTopic(title: "head of sound", qualities: ["teamwork", "calm"], hasEnded: false),
            SummaryTopic(title: "stagehand", work: ["the lights"], hasEnded: true),
            SummaryTopic(title: "head of sound", tools: ["XLR cables", "Dante"], hasEnded: false),
            SummaryTopic(title: "head of sound", qualities: ["care"], hasEnded: false),
        ])
        // The opening says the title: no role slot.
        let opened = SectionDraft.summaryTopics(
            of: Self.brief, duties: Self.duties, typical: [[], [], []], qualities: ["teamwork", "calm", "care"], field: "live sound",
            order: [2, 1, 0], tools: Self.tools, hasOpening: true
        )
        #expect(opened == Array(topics.dropFirst()))
    }

    @Test("The first qualities slot says them with the third pair of work when the job has one, and that work gets no slot of its own (probe round 10)")
    func qualitiesWithWork() {
        let duties = [[], [], [
            "I train the junior technicians.", "I plan the rehearsals.", "I mix the shows.", "I tune the rooms.", "I patch the stage boxes.",
        ]]
        let topics = SectionDraft.summaryTopics(
            of: Self.brief, duties: duties, typical: [[], [], []], qualities: ["teamwork", "calm", "care"], field: nil,
            order: [2, 1, 0], tools: Array(Self.tools.prefix(3)), hasOpening: true
        )

        #expect(topics == [
            SummaryTopic(title: "head of sound", work: ["the junior technicians", "the rehearsals"], hasEnded: false),
            SummaryTopic(title: "head of sound", tools: ["Pro Tools", "DiGiCo SD7", "in-ear monitors"], hasEnded: false),
            SummaryTopic(title: "head of sound", work: ["the shows", "the rooms"], hasEnded: false),
            SummaryTopic(title: "head of sound", work: ["the stage boxes"], qualities: ["teamwork", "calm"], hasEnded: false),
            SummaryTopic(title: "head of sound", qualities: ["care"], hasEnded: false),
        ])
        // With no qualities the third pair keeps its own slot.
        #expect(SectionDraft.summaryTopics(
            of: Self.brief, duties: duties, typical: [[], [], []], qualities: [], field: nil, order: [2, 1, 0], hasOpening: true
        ).last == SummaryTopic(title: "head of sound", work: ["the stage boxes"], hasEnded: false))
    }

    @Test("A job with no title reads the headline, and its field comes first, or last after an opening; a field that reads as a clause goes")
    func summaryField() {
        let brief = DraftBrief(
            language: "English", headline: "head of sound", roles: [.init(title: "", hasEnded: false)], studies: [], namedSkills: []
        )
        let role = SummaryTopic(title: "head of sound", field: "live sound", hasEnded: false)
        let calm = SummaryTopic(title: "head of sound", qualities: ["calm"], hasEnded: false)
        let topics = { (field: String, hasOpening: Bool) in
            SectionDraft.summaryTopics(
                of: brief, duties: [[]], typical: [[]], qualities: ["calm"], field: field, order: [0], hasOpening: hasOpening
            )
        }

        #expect(topics("live sound", false) == [role, calm])
        #expect(topics("live sound", true) == [calm, role])
        #expect(topics("I know my way around a mixing desk", false) == [SummaryTopic(title: "head of sound", hasEnded: false), calm])
        #expect(topics("I know my way around a mixing desk", true) == [calm])
        #expect(SectionDraft.cleanField("live sound") == "live sound")
        #expect(SectionDraft.cleanField("front-of-house sound") == "front-of-house sound")
        #expect(SectionDraft.cleanField("Ich kenne mich mit KNX aus") == nil)
        #expect(SectionDraft.cleanField("sound, light") == nil)
        #expect(SectionDraft.cleanField(" ") == nil)
        #expect(SectionDraft.cleanField(nil) == nil)
    }

    @Test("The work slots read the current job's kept duties two at a time, up to three pairs")
    func workTopics() {
        let topics = SectionDraft.workTopics(of: Self.brief, current: 2, duties: Self.duties, typical: [[], [], []])

        #expect(topics.map(\.work) == [["the junior technicians", "the rehearsals"], ["the shows"]])
    }

    // MARK: The summary's request

    @Test("A summary sentence's request reads the tools of its slot and the first verbs said, and its rules ask for the tools by name and for concrete work")
    func summarySentencePrompt() {
        let topic = SummaryTopic(title: "head of sound", tools: ["Pro Tools", "DiGiCo SD7"], hasEnded: false)
        let written = ["I work as head of sound.", "I train the junior technicians.", "I work through every show calmly."]

        let prompt = SectionPrompts.summarySentence(for: Self.brief, topic: topic, written: written)

        #expect(prompt.text == """
            Language: English
            Write in English.
            Job: head of sound; write in the present
            Tools: Pro Tools; DiGiCo SD7
            Summary so far:
            - I work as head of sound.
            - I train the junior technicians.
            - I work through every show calmly.
            Do not start with: work; train
            """)
        for instructions in [SectionPrompts.summarySentenceInstructions, SectionPrompts.summarySentenceRepairInstructions] {
            #expect(instructions.contains(
                "with tools, say what the person does with one or two of them, by name, each for the work it is made for"
            ))
            #expect(instructions.contains("Name a tool only when a Tools line is given."))
            #expect(instructions.contains(
                "concrete: no bare \"tools\", \"software\", \"systems\", \"equipment\", \"techniques\" or \"methods\""
            ))
            #expect(instructions.contains("Typical duties of the job are fine, in your own words"))
            #expect(instructions.contains("never guarantee a result"))
        }
        // iOS 26's model keeps the plain request: no list of verbs, no rule on the tools.
        DraftDepth.$pinned.withValue(false) {
            #expect(!SectionPrompts.summarySentence(for: Self.brief, topic: topic, written: written).text.contains("Do not start with:"))
            #expect(!SectionPrompts.summarySentenceInstructions.contains("by name"))
            #expect(SectionPrompts.summarySentenceInstructions.contains("Typical duties and tools of the job are fine, in your own words."))
        }
    }
}
