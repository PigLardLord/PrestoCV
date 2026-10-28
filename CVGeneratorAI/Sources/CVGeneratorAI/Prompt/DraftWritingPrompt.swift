import Foundation

/// The text sent to the on-device model for the second pass of a draft (ADR 0031): fixed instructions, and the facts of the brief.
/// The model never sees the description here, so it has nothing to copy, and only the roles to write around.
struct DraftWritingPrompt: Equatable {
    let instructions: String
    let text: String

    init(brief: DraftBrief) {
        var lines = ["Language: \(brief.language)"]
        if let headline = brief.headline { lines.append("Headline title: \(headline)") }
        let roles = Self.numberedRoles(of: brief).map { number, role in
            "\(number). \(role.title)" + (role.hasEnded ? " (ended)" : "")
        }
        if !roles.isEmpty { lines.append("Roles:\n" + roles.joined(separator: "\n")) }
        if !brief.studies.isEmpty { lines.append("Studies: " + brief.studies.joined(separator: "; ")) }
        if !brief.namedSkills.isEmpty { lines.append("Skills already listed: " + brief.namedSkills.joined(separator: "; ")) }

        self.instructions = Self.instructionsText
        self.text = lines.joined(separator: "\n")
    }

    /// The roles the model describes, by the number the prompt gives them: the position in the brief, from 1, of each role with a
    /// title. A role kept by its employer alone has nothing to describe.
    static func numberedRoles(of brief: DraftBrief) -> [(number: Int, role: DraftBrief.Role)] {
        brief.roles.enumerated().compactMap { index, role in
            role.title.presentValue == nil ? nil : (number: index + 1, role: role)
        }
    }

    /// The descriptions an answer gives, one for one with the roles of `brief`: each goes to the role the prompt gave its number, the
    /// first one for a number written twice; a number of no role is ignored, and a role the answer skips has none.
    static func descriptions(_ answers: [(number: Int, text: String)], of brief: DraftBrief) -> [String?] {
        let numbers = Set(numberedRoles(of: brief).map(\.number))
        var descriptions = [String?](repeating: nil, count: brief.roles.count)
        for answer in answers where numbers.contains(answer.number) && descriptions[answer.number - 1] == nil {
            descriptions[answer.number - 1] = answer.text
        }
        return descriptions
    }

    /// What the model writes, and what it never adds: the rules keep only the text that states no fact of its own.
    static let instructionsText = """
        You write the parts of a CV that describe a person's work, from the facts below. Write in the language named on the first line.
        - Summary: 2 to 4 sentences on the person's profession and strengths, from their titles and studies. No number, date, company, school, place or person's name; no "experience", "years", "senior", "expert", "experienced".
        - For each numbered role: 1 to 2 sentences with the responsibilities typical of that title. No number, no name, no tool name. For a role marked ended, write in the past tense.
        - Technologies: 4 to 8 tools, methods or knowledge of the trade that fit the roles. Soft skills: 3 to 5 ways of working with people and tasks that fit the roles. 1 to 4 words each, no level, none of the skills already listed.
        - Never add a language, job, study, certification, hobby, achievement or result.
        """
}
