import Foundation

/// The prompts of a draft written a section at a time (ADR 0031, "A request per section"): a request per job that reads the job's
/// own clauses, a request for the tools of each job and one for the soft skills, then the summary from what the checks kept, and the
/// repairs that read each sentence a check rejected with its reason.
enum SectionPrompts {
    /// A request: the instructions of its session and the text it answers.
    struct Prompt: Equatable {
        let instructions: String
        let text: String
    }

    // MARK: A job

    /// The request of the job at `number`: its title, employer and end, its own clauses and the words its duties avoid.
    static func job(number: Int, of brief: DraftBrief) -> Prompt {
        Prompt(instructions: jobInstructions, text: (jobLines(number: number, of: brief) + [count(of: brief.roles[number])]).joined(separator: "\n"))
    }

    /// How many duties the job's request writes: the person's, then exactly the typical ones the job needs (#354, round 10), after
    /// them (O1, round 13).
    private static func count(of role: DraftBrief.Role) -> String {
        let more = role.adding == 1 ? "1 more duty" : "\(role.adding) more duties"
        switch (role.said, role.adding) {
        // Clauses that pin no duty (a name or a number in each) still say the person's work: the request writes it first, or the
        // model writes typical duties in its place (#354, round 10). Clauses that only say where the person worked name no work:
        // asked for it, the model wrote that they worked there (#354, round 11).
        case (0, _) where !role.clauses.isEmpty && role.clausesNameWork:
            return "Write exactly \(role.adding == 1 ? "1 duty" : "\(role.adding) duties"): first the duties the person said above, then typical ones of this job."
        case (0, _): return "Write exactly \(role.adding == 1 ? "1 duty" : "\(role.adding) duties") typical of this job."
        case (_, 0): return "Write only the \(role.said == 1 ? "duty" : "duties") the person said, and add none."
        default: return "Write exactly \(more) typical of this job, after the \(role.said == 1 ? "duty" : "duties") the person said."
        }
    }

    static let jobInstructions = """
        You write the years and the duties of one job of a CV, from what the person said about it. Write in the language named on \
        the first line.
        - The years: only those the person said for this job.
        - The duties the request asks for, each one whole sentence that starts with a capital letter and ends with a full stop.
        - First the duties the person said for this job; then exactly as many more as the request asks, typical of its title, each \
        a concrete task of that trade, never one that fits any job, and none that says a duty already written.
        - No number, date, name of a company, place or person.
        - Never add a job, study, certification, achievement or result.
        """

    /// The repair of the job at `number`: the duties the check kept, each sentence it rejected with its reason, and exactly the
    /// duties the job still needs to reach `DraftBrief.Role.leastDuties` (O1, round 13).
    static func jobRepair(number: Int, of brief: DraftBrief, kept: [String], rejected: [String]) -> Prompt {
        let role = brief.roles[number]
        var lines = jobLines(number: number, of: brief, avoiding: false)
        if !kept.isEmpty { lines.append("Duties kept:\n" + bullets(kept)) }
        if !rejected.isEmpty { lines.append("Sentences rejected, with the reason:\n" + bullets(rejected)) }
        let missing = max(DraftBrief.Role.leastDuties - kept.count, 1)
        lines.append("Add exactly \(missing == 1 ? "1 more duty" : "\(missing) more duties") typical of this job.")
        if !role.avoid.isEmpty { lines.append("Words to avoid: " + role.avoid.joined(separator: ", ")) }
        return Prompt(instructions: jobRepairInstructions, text: lines.joined(separator: "\n"))
    }

    static let jobRepairInstructions = """
        You fix the duties of one job of a CV. Write in the language named on the first line.
        - Write each rejected sentence again so that its reason no longer holds, or leave it out.
        - Add exactly as many more duties typical of the job as the request asks.
        - Each duty one whole sentence that starts with a capital letter and ends with a full stop, in the same form as the duties kept.
        - Do not repeat a duty kept. No number, date, name of a company, place or person, and none of the words to avoid.
        - Never add a job, study, certification, achievement or result.
        """

    private static func jobLines(number: Int, of brief: DraftBrief, avoiding: Bool = true) -> [String] {
        let role = brief.roles[number]
        var lines = header(brief)
        if role.title.presentValue == nil, let headline = brief.headline { lines.append("Headline title: \(headline)") }
        // The employer is masked, and so is a name of its own in the job's clauses: asked for duties typical of an accountant at
        // "Transportes Ebro Norte", the model wrote that they calculated the monthly transport costs (#354, round 11).
        var masking = brief
        masking.names = brief.names.filter { $0.first?.isUppercase == true }
        lines.append("Job: " + roleLine(role, employer: true, masked: brief))
        if !role.clauses.isEmpty {
            lines.append("What the person said about this job:\n" + bullets(role.clauses.map { asDuty(masked($0, in: masking)) }))
        }
        if avoiding, !role.avoid.isEmpty { lines.append("Words to avoid: " + role.avoid.joined(separator: ", ")) }
        return lines
    }

    // MARK: The skills

    /// The tools request of one job, or of the jobs that share its title (`roles`, #354, round 6): the title, or the headline
    /// for a job with none; the jobs' own lines; and what their work is done on, which is no tool. Asked for the tools of every job
    /// at once, the request listed the panels a person repairs, activities and everyday objects.
    static func tools(for brief: DraftBrief, roles: [Int], count: ClosedRange<Int>) -> Prompt {
        let jobs = roles.filter(brief.roles.indices.contains).map { brief.roles[$0] }
        let title = jobs.first?.title.presentValue ?? brief.headline ?? DraftWritingPrompt.noTitle
        var lines = header(brief) + ["Job title: \(title)"]
        var clauses: [String] = []
        for clause in jobs.flatMap(\.clauses).map({ asSentence(masked($0, in: brief)) }) where !clauses.contains(clause) {
            clauses.append(clause)
        }
        if !clauses.isEmpty { lines.append("What the person said about this job:\n" + bullets(clauses)) }
        let objects = CVDataSanitizer.workObjects(of: clauses, capitalNouns: brief.language == "German")
        if !objects.isEmpty { lines.append("What the work is done on, which is no tool: " + objects.joined(separator: "; ")) }
        if !brief.own.isEmpty {
            lines.append("What the person says of their work, with no job:\n" + bullets(brief.own.map { asSentence(masked($0, in: brief)) }))
        }
        if !brief.namedSkills.isEmpty { lines.append("Skills already listed: " + brief.namedSkills.joined(separator: "; ")) }
        return Prompt(instructions: toolsInstructions(count: count), text: lines.joined(separator: "\n"))
    }

    /// `text` with each of the brief's names, and each word of 4 letters or more of one that has a capital, written as "the company"
    /// in the brief's language (#354, round 7): the request read "Kestrel Logistics" and wrote a "Kestrel forklift". In German,
    /// whose nouns all take a capital, only the whole names go.
    static func masked(_ text: String, in brief: DraftBrief) -> String {
        let company = companyWords[brief.language] ?? "the company"
        var masked = text
        for name in brief.names.filter({ !$0.isEmpty }).sorted(by: { $0.count > $1.count }) {
            masked = masked.replacingOccurrences(of: name, with: company, options: .caseInsensitive)
        }
        guard brief.language != "German" else { return masked }
        let words = Set(brief.names.flatMap { $0.split { !$0.isLetter } }.map(String.init).filter {
            $0.count >= 4 && $0.first?.isUppercase == true && !legalForms.contains($0.lowercased())
        })
        for word in words.sorted(by: { $0.count > $1.count }) {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word))\\b"
            masked = masked.replacingOccurrences(of: pattern, with: company, options: .regularExpression)
        }
        return masked
    }

    private static let companyWords = [
        "English": "the company", "Italian": "l'azienda", "German": "die Firma", "French": "l'entreprise", "Spanish": "la empresa",
        "Portuguese": "a empresa",
    ]

    /// The legal forms of a company of 4 letters or more, lowercased: no name of its own.
    private static let legalForms: Set<String> = ["gmbh", "sarl", "ltda"]

    /// The tools request's rules, asking `count` tools. Asked for objects only, the request named household and room objects
    /// ("frigorifero", "microonde", "classe"); asked for methods and fields of knowledge too, it named fields instead of products
    /// ("linguagens de programação" for Python and Java) and the job's own duties: a standard or method is asked only by its own
    /// name, as a CV of the trade lists it (`SkillKind`, ADR 0031; O1; probe round 11). Asked the tools a job ad of the title
    /// asks, a rich draft named the ad's words for the work ("shift", "pallet") and its fields ("Stromversorgung"; probe round 17).
    static func toolsInstructions(count: ClosedRange<Int>) -> String {
        """
        You name the tools of one job for a CV: \(count.lowerBound) or \(count.upperBound) software, equipment, machines or \
        instruments that a person with the job's title uses at work, each of another kind, as a CV of that trade names them; \
        a standard or method of the trade known by its own name counts as one. Write in the language named on the first line.
        - First the equipment, machines and software the job's own lines name, as written; then the tools the person names in \
        what they say of their work with no job, when they fit this job; then those of the trade, only when they fit the job's \
        title and the tools the person names.
        - A kind of tool with a word of its trade is a tool; a bare kind, with no word of its trade, is not.
        - 1 to 3 words each. Not a tool: what the work is done on; an activity or task, also when written as a noun; a document; \
        a material, part or supply; stationery, furniture or protective wear; an everyday object a person of any trade uses, a \
        household appliance or a room; a personal quality; a level; a skill already listed.
        """
    }

    /// The soft skills request.
    static func softSkills(for brief: DraftBrief) -> Prompt {
        Prompt(
            instructions: softSkillsInstructions, text: (header(brief) + headline(brief) + [jobList(brief)] + said(brief)).joined(separator: "\n")
        )
    }

    /// The soft skills instructions: 4 to 6 qualities of a rich draft (`DraftDepth`; probe round 13), 3 to 5 of the others. Asked
    /// for nouns, a rich draft still wrote adjectives of the person ("reliable", "organizzata"): it is told the noun of the
    /// quality (probe round 18).
    static var softSkillsInstructions: String {
        let nouns = DraftDepth.isRich ? "each the noun that names the quality, never an adjective that describes the person, of 1 to 3 words" : "as nouns of 1 to 3 words"
        return """
        You name \(DraftDepth.isRich ? "4 to 6" : "3 to 5") personal qualities at work that fit the person's jobs, \(nouns). Write \
        in the language named on the first line. No tool, no technique, no level. First the qualities the person says of \
        themselves, as nouns; then those that fit the jobs.
        """
    }

    /// The request for the skills a draft still misses: `tools` more tools, of the trade of the tools kept or, with none kept, of the
    /// jobs (#354, round 4), and `qualities` more qualities in the CV's language; none of those kept and none of `rejected`
    /// ("skill": reason).
    static func moreSkills(
        for brief: DraftBrief, title: String?, tools: Int, qualities: Int, listedTools: [String], listedQualities: [String],
        rejected: [String]
    ) -> Prompt {
        var lines = header(brief) + headline(brief) + [jobList(brief)] + said(brief)
        if !listedTools.isEmpty { lines.append("Tools listed, do not repeat: " + listedTools.joined(separator: "; ")) }
        if !listedQualities.isEmpty { lines.append("Qualities listed, do not repeat: " + listedQualities.joined(separator: "; ")) }
        if tools > 0 {
            // Asked for the tools of the jobs, the request wrote the tools of a past trade; asked for "named software products, named
            // devices", it wrote devices of any trade ("scanner portable", "Tableta táctil"). The general kinds of the work it
            // writes go by code (`repairedTools`; #354, round 15). Asked "each of another kind" of software, systems, machines or
            // instruments, it wrote kinds an office or a school has none of ("Termostatos", "Blockchain"): it is asked the tools a
            // CV of the trade typically lists, the most common first, machines only when the trade uses any (probe round 9). Asked
            // for its methods and fields of knowledge too, it named fields instead of products ("linguagens de programação"): only
            // a standard or method known by its own name is asked, after the products (probe round 11).
            let who = title.map { "a person working as \($0)" } ?? "a person with these jobs"
            let trade = listedTools.isEmpty ? "the trade" : "the trade of the tools listed"
            let new = listedTools.isEmpty && rejected.isEmpty ? "" : " none of the tools listed or rejected;"
            lines.append(
                "The CV lists too few tools for \(who): name \(tools) more tools that a CV of \(who) typically lists, the most "
                    + "common first: the software, as a kind with a word of the trade or a widely used product of \(trade), then the "
                    + "equipment, machines or instruments, when the trade uses any, then a standard or method of the trade known by "
                    + "its own name;\(new) each a different tool" + (listedTools.isEmpty ? "." : ", not another name of one listed.")
            )
        }
        if qualities > 0 {
            lines.append("Name \(qualities) more personal qualities at work that fit these jobs, as nouns in the language named on the first line.")
        }
        if !rejected.isEmpty { lines.append("Rejected, with the reason; write none of them again:\n" + bullets(rejected)) }
        return Prompt(instructions: moreSkillsInstructions, text: lines.joined(separator: "\n"))
    }

    static let moreSkillsInstructions = """
        You add skills to a CV, for the person's trade. Write in the language named on the first line.
        - Nouns of 1 to 3 words; no level, no activity or task, also when written as a noun, none of those already listed.
        - First those the person names in what they say of their work with no job; then those of the trade.
        """

    // MARK: The summary

    /// One sentence of the summary, written last on one slot (#354, round 13, O1): the job's title and its tense, past when it ended
    /// and present otherwise (told only the past, a current job's sentence came in the past), with the
    /// field, the topics of its kept duties or two qualities, after the summary so far, the opening code wrote first. Asked for the
    /// whole summary from every job, the request ran short.
    static func summarySentence(for brief: DraftBrief, topic: SummaryTopic, written: [String]) -> Prompt {
        var lines = header(brief)
        lines.append("Job: " + (topic.title ?? DraftWritingPrompt.noTitle) + (topic.hasEnded ? "; ended, write in the past" : "; write in the present"))
        if let field = topic.field { lines.append("Field: " + field) }
        if !topic.work.isEmpty { lines.append("Topics: " + topic.work.joined(separator: "; ")) }
        if !topic.qualities.isEmpty { lines.append("Qualities: " + topic.qualities.joined(separator: "; ")) }
        if !topic.tools.isEmpty { lines.append("Tools: " + topic.tools.joined(separator: "; ")) }
        if !written.isEmpty { lines.append("Summary so far:\n" + bullets(written)) }
        // The first verbs said, by name, of a rich draft (`DraftDepth`): told only not to start as an earlier sentence, the
        // sentences kept starting with the same verb and the check rejected them (#354, probe round 3).
        var seen = Set<String>()
        let verbs = written.compactMap(CVDataSanitizer.leadingVerb(of:)).filter { seen.insert($0).inserted }
        if DraftDepth.isRich, !verbs.isEmpty { lines.append("Do not start with: " + verbs.joined(separator: "; ")) }
        return Prompt(instructions: summarySentenceInstructions, text: lines.joined(separator: "\n"))
    }

    /// What every summary sentence keeps to (S2): typical duties and tools are draft content (O1); no fact the person did not say.
    /// A rich draft (`DraftDepth`) also has a tools slot, whose sentences named no tool (probe round 4).
    static var summarySentenceRules: String {
        (DraftDepth.isRich ? richWorkRule : plainWorkRule) + summarySentenceLimits
    }

    static let plainWorkRule = """
        - Say what the person does as the job, with the topics or the field when given, in the past when the job ended; with \
        qualities, say how the person works, the person as the subject. Typical duties and tools of the job are fine, in your own \
        words.

        """

    static let richWorkRule = """
        - Say what the person does as the job, with the topics or the field when given, in the past when the job ended; with \
        tools, say what the person does with one or two of them, by name, each for the work it is made for; with qualities, say \
        how the person works, the person as the subject. Name a tool only when a Tools line is given. Typical duties of the job \
        are fine, in your own words, concrete: no bare "tools", "software", "systems", "equipment", "techniques" or "methods".

        """

    static let summarySentenceLimits = """
        - Do not start with the first verb of a sentence of the summary so far. Start with a capital letter, end with a full stop; \
        no list.
        - Never add a number, company, customer, product, school, place, person, language, study, certification or achievement; \
        no "experience", "years", "senior", "expert", "experienced", and never guarantee a result.
        """

    static var summarySentenceInstructions: String {
        """
        You write one more sentence of the summary of a CV, after the summary so far. Write in the language named on the first line.
        - Exactly 1 sentence, as the person: in the first person, never "he", "she" or "the person".

        """ + summarySentenceRules
    }

    /// The sentence's repair: the request again, then the sentence the check rejected and why.
    static func summarySentenceRepair(for brief: DraftBrief, topic: SummaryTopic, written: [String], rejected: String) -> Prompt {
        let lines = [summarySentence(for: brief, topic: topic, written: written).text, "Rejected, with the reason: " + rejected]
        return Prompt(instructions: summarySentenceRepairInstructions, text: lines.joined(separator: "\n"))
    }

    static var summarySentenceRepairInstructions: String {
        """
        You fix one sentence of the summary of a CV, after the summary so far. Write in the language named on the first line.
        - Write the rejected sentence again as exactly 1 sentence that fixes the reason, as the person: in the first person, never \
        "he", "she" or "the person".

        """ + summarySentenceRules
    }

    // MARK: The parts of a request

    /// A clause of the description as a whole sentence: a capital first letter and a full stop, its joining punctuation gone.
    static func asSentence(_ clause: String) -> String {
        let trimmed = clause.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ",;:")))
        guard let first = trimmed.first else { return trimmed }
        let capital = first.uppercased() + trimmed.dropFirst()
        return capital.last.map { ".!?".contains($0) } == true ? capital : capital + "."
    }

    /// A clause a job request reads, which the model writes back as a duty: a whole sentence without the relative word that tied
    /// it to the employer (`CVDataSanitizer.withoutRelativeOpening`): the model wrote "Où j'ai formé…" back as a duty (#354, round
    /// 12). Only the job requests drop it: the skills requests copy no clause, and there the dropped word changed the tools.
    static func asDuty(_ clause: String) -> String {
        asSentence(CVDataSanitizer.withoutRelativeOpening(asSentence(clause)))
    }

    private static func header(_ brief: DraftBrief) -> [String] {
        ["Language: \(brief.language)"] + [DraftWritingPrompt.writeIn[brief.language]].compactMap { $0 }
    }

    private static func headline(_ brief: DraftBrief) -> [String] {
        brief.headline.map { ["Headline title: \($0)"] } ?? []
    }

    /// A role's line: its title, or `standIn` for a role with none, then its employer when asked, masked with the names of
    /// `masked` when given, and whether it ended.
    private static func roleLine(_ role: DraftBrief.Role, employer: Bool, standIn: String? = nil, masked brief: DraftBrief? = nil) -> String {
        let named = role.employer.map { name in brief.map { masked(name, in: $0) } ?? name }
        return ([role.title.presentValue ?? standIn ?? DraftWritingPrompt.noTitle] + (employer ? named.map { ["employer: \($0)"] } ?? [] : [])
            + (role.hasEnded ? ["ended"] : [])).joined(separator: "; ")
    }

    /// The jobs of the skills requests: a job with no title reads the headline title, the person's trade, so that its tools are of
    /// that trade and not of the trade its employer's name suggests (#354). The draft's job keeps no title.
    private static func jobList(_ brief: DraftBrief) -> String {
        "Jobs:\n" + brief.roles.enumerated().map { index, role in
            "\(index + 1). " + roleLine(role, employer: false, standIn: brief.headline)
                + (role.clauses.isEmpty ? "" : "\n   " + role.clauses.map(asSentence).joined(separator: " "))
        }.joined(separator: "\n")
    }

    /// What the person says of their work with no job (`DraftBrief.own`), which the skills requests read: none when they say none.
    private static func said(_ brief: DraftBrief) -> [String] {
        brief.own.isEmpty ? [] : ["What the person says of their work, with no job:\n" + bullets(brief.own.map(asSentence))]
    }

    private static func bullets(_ lines: [String]) -> String {
        lines.map { "- " + $0 }.joined(separator: "\n")
    }
}
