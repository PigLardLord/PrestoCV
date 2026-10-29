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
        Prompt(instructions: jobInstructions, text: jobLines(number: number, of: brief).joined(separator: "\n"))
    }

    static let jobInstructions = """
        You write the years and the duties of one job of a CV, from what the person said about it. Write in the language named on \
        the first line.
        - The years: only those the person said for this job.
        - 2 to 4 duties, each one whole sentence that starts with a capital letter and ends with a full stop.
        - First the duties the person said for this job; then, to reach at least 2, unless the request says to add none, duties \
        typical of its title at that employer, each a concrete task of that trade, never one that fits any job.
        - No number, date, name of a company, place or person.
        - Never add a job, study, certification, achievement or result.
        """

    /// The repair of the job at `number`: the duties the check kept, and each sentence it rejected with its reason.
    static func jobRepair(number: Int, of brief: DraftBrief, kept: [String], rejected: [String]) -> Prompt {
        let role = brief.roles[number]
        var lines = jobLines(number: number, of: brief, avoiding: false)
        if !kept.isEmpty { lines.append("Duties kept:\n" + bullets(kept)) }
        if !rejected.isEmpty { lines.append("Sentences rejected, with the reason:\n" + bullets(rejected)) }
        lines.append("Add one more duty typical of this job.")
        if !role.avoid.isEmpty { lines.append("Words to avoid: " + role.avoid.joined(separator: ", ")) }
        return Prompt(instructions: jobRepairInstructions, text: lines.joined(separator: "\n"))
    }

    static let jobRepairInstructions = """
        You fix the duties of one job of a CV. Write in the language named on the first line.
        - Write each rejected sentence again so that its reason no longer holds, or leave it out.
        - When asked, add one more duty typical of the job.
        - Each duty one whole sentence that starts with a capital letter and ends with a full stop, in the same form as the duties kept.
        - Do not repeat a duty kept. No number, date, name of a company, place or person, and none of the words to avoid.
        - Never add a job, study, certification, achievement or result.
        """

    private static func jobLines(number: Int, of brief: DraftBrief, avoiding: Bool = true) -> [String] {
        let role = brief.roles[number]
        var lines = header(brief)
        if role.title.presentValue == nil, let headline = brief.headline { lines.append("Headline title: \(headline)") }
        lines.append("Job: " + roleLine(role, employer: true))
        if !role.clauses.isEmpty {
            lines.append("What the person said about this job:\n" + bullets(role.clauses.map(asSentence)))
        }
        if role.described { lines.append("The person said enough of this job: write only the duties they said, and add none.") }
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

    /// The tools request's rules, asking `count` tools.
    static func toolsInstructions(count: ClosedRange<Int>) -> String {
        """
        You name the tools of one job for a CV: \(count.lowerBound) or \(count.upperBound) software, equipment, machines or \
        instruments that a person with the job's title uses at work, each of another kind, as a CV of that trade names them. \
        Write in the language named on the first line.
        - First the equipment, machines and software the job's own lines name, as written; then the tools the person names in \
        what they say of their work with no job, when they fit this job; then those of the trade, only when they fit the job's \
        title and the tools the person names.
        - A kind of tool with a word of its trade is a tool; a bare kind, with no word of its trade, is not.
        - 1 to 3 words each. Not a tool: what the work is done on; an activity or task, also when written as a noun; a document; \
        a material, part or supply; stationery, furniture or protective wear; an everyday object a person of any trade uses; a \
        personal quality; a level; a skill already listed.
        """
    }

    /// The soft skills request.
    static func softSkills(for brief: DraftBrief) -> Prompt {
        Prompt(
            instructions: softSkillsInstructions, text: (header(brief) + headline(brief) + [jobList(brief)] + said(brief)).joined(separator: "\n")
        )
    }

    static let softSkillsInstructions = """
        You name 3 to 5 personal qualities at work that fit the person's jobs, as nouns of 1 to 3 words. Write in the language named \
        on the first line. No tool, no technique, no level. First the qualities the person says of themselves, as nouns; then \
        those that fit the jobs.
        """

    /// The request for the skills a draft still misses: `tools` more tools, of the trade of the tools kept or, with none kept, of the
    /// jobs (#354, round 4), and `qualities` more qualities in the CV's language; none of those kept and none of `rejected`
    /// ("skill": reason).
    static func moreSkills(
        for brief: DraftBrief, tools: Int, qualities: Int, listedTools: [String], listedQualities: [String], rejected: [String]
    ) -> Prompt {
        var lines = header(brief) + headline(brief) + [jobList(brief)] + said(brief)
        if !listedTools.isEmpty { lines.append("Tools listed, do not repeat: " + listedTools.joined(separator: "; ")) }
        if !listedQualities.isEmpty { lines.append("Qualities listed, do not repeat: " + listedQualities.joined(separator: "; ")) }
        if tools > 0 {
            let trade = listedTools.isEmpty ? "jobs above" : "tools listed"
            lines.append(
                "The CV lists too few tools for its trade: name \(tools) more software, systems, machines or instruments of the trade of "
                    + "the \(trade), that a person with these jobs uses, each of another kind"
                    + (listedTools.isEmpty ? "." : " than those listed.")
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

    /// The summary, written last from the brief's job titles, the topics of the duties the checks kept, and the tools and qualities
    /// they kept, after the opening code wrote. It reads no whole duty: a duty it read came back word for word, and the check drops
    /// a copied duty (#354, round 2); with no work at all it wrote lists of qualities (round 3).
    static func summary(for brief: DraftBrief, tools: [String], qualities: [String]) -> Prompt {
        var lines = header(brief) + headline(brief)
        // Each topic of a role's work on its own line: written on one line with semicolons, the topics came back as one summary
        // sentence of clauses joined by semicolons (#354, round 3).
        let roles = brief.roles.map { role in
            "- " + roleLine(role, employer: false) + (role.work.isEmpty ? "" : ", work:" + role.work.map { "\n  - " + $0 }.joined())
        }
        if !roles.isEmpty { lines.append("Roles:\n" + roles.joined(separator: "\n")) }
        if !brief.studies.isEmpty { lines.append("Studies: " + brief.studies.joined(separator: "; ")) }
        if !tools.isEmpty { lines.append("Tools: " + tools.joined(separator: "; ")) }
        if !qualities.isEmpty { lines.append("Qualities: " + qualities.joined(separator: "; ")) }
        if let opening = brief.opening { lines.append("Opening, already written: " + opening) }
        return Prompt(instructions: summaryInstructions, text: lines.joined(separator: "\n"))
    }

    static let summaryInstructions = """
        You write the summary of a CV after the opening, which is written, from the roles and skills below. Write in the language \
        named on the first line.
        - 2 to 3 sentences, at least 120 characters in all, on the work of the roles and how the person does it, with a tool or a \
        quality of the lists in it; no list of tools or qualities, and never the opening or its first verb again.
        - Each sentence starts with a capital letter and ends with a full stop; write as the person, never "he", "she" or "the person".
        - No number, date, company, school, place or person's name; no "experience", "years", "senior", "expert", "experienced".
        - Never add a language, job, study, certification, hobby, achievement or result.
        """

    /// The summary's repair: what the check kept, what it rejected and why, and what the summary misses.
    static func summaryRepair(
        for brief: DraftBrief, tools: [String], qualities: [String], kept: [String], rejected: [String], problems: [String]
    ) -> Prompt {
        var lines = [summary(for: brief, tools: tools, qualities: qualities).text]
        if !kept.isEmpty { lines.append("Summary sentences kept:\n" + bullets(kept)) }
        if !rejected.isEmpty { lines.append("Summary sentences rejected, with the reason:\n" + bullets(rejected)) }
        if !problems.isEmpty { lines.append("What the summary misses: " + problems.joined(separator: "; ")) }
        return Prompt(instructions: summaryRepairInstructions, text: lines.joined(separator: "\n"))
    }

    static let summaryRepairInstructions = """
        You fix the summary of a CV after the opening, which is written. Write in the language named on the first line.
        - Write the summary again: 2 to 3 sentences, at least 120 characters in all, that keep the sentences kept and fix each \
        reason, on the work of the roles; no list of tools or qualities, and never the opening or its first verb again.
        - Each sentence starts with a capital letter and ends with a full stop; write as the person, never "he", "she" or "the person".
        - No number, date, company, school, place or person's name; no "experience", "years", "senior", "expert", "experienced".
        - Never add a language, job, study, certification, hobby, achievement or result.
        """

    // MARK: The parts of a request

    /// A clause of the description as a whole sentence: a capital first letter and a full stop, its joining punctuation gone.
    static func asSentence(_ clause: String) -> String {
        let trimmed = clause.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ",;:")))
        guard let first = trimmed.first else { return trimmed }
        let capital = first.uppercased() + trimmed.dropFirst()
        return capital.last.map { ".!?".contains($0) } == true ? capital : capital + "."
    }

    private static func header(_ brief: DraftBrief) -> [String] {
        ["Language: \(brief.language)"] + [DraftWritingPrompt.writeIn[brief.language]].compactMap { $0 }
    }

    private static func headline(_ brief: DraftBrief) -> [String] {
        brief.headline.map { ["Headline title: \($0)"] } ?? []
    }

    /// A role's line: its title, or `standIn` for a role with none, then its employer when asked and whether it ended.
    private static func roleLine(_ role: DraftBrief.Role, employer: Bool, standIn: String? = nil) -> String {
        ([role.title.presentValue ?? standIn ?? DraftWritingPrompt.noTitle] + (employer ? role.employer.map { ["employer: \($0)"] } ?? [] : [])
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
