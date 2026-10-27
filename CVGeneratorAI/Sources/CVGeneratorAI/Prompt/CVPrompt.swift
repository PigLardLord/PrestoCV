import Foundation

/// How the fixed instructions reach the model.
enum InstructionsDelivery: Equatable {
    /// As the session's instructions, which the model weighs above the prompt
    case session
    /// In front of the prompt, for a system where session instructions misbehave
    case promptPrefix
}

/// The text sent to the on-device model for one request: the fixed instructions plus the
/// person's own description.
struct CVPrompt: Equatable {
    /// Session instructions, or nil when they travel inside `text`
    let instructions: String?
    let text: String

    init(request: CVGenerationRequest, delivery: InstructionsDelivery = .session) {
        var sections: [String] = []

        if delivery == .promptPrefix {
            sections.append(Self.instructionsText)
        }
        if let languageName = request.fallbackLanguageCode.flatMap(Self.languageName(forCode:)) {
            sections.append("If the language of the description is unclear, write in \(languageName).")
        }
        sections.append("Description:\n\(request.userPrompt)")

        self.instructions = delivery == .session ? Self.instructionsText : nil
        self.text = sections.joined(separator: "\n\n")
    }

    /// Everything the model must never do is stated here, as the sanitizer can only remove
    /// what it can verify against the description.
    static let instructionsText = """
        You turn a person's own description of their background into the fields of a CV.
        - Never invent or guess a name, email address, phone number, website, employer, school, job title, date, number, percentage, result, certification, skill level or language level.
        - Copy names of people, companies, schools, places, certifications and job titles exactly as written. Copy dates exactly as written.
        - Write each achievement by copying the person's own words exactly, starting with the verb and leaving out the name of the employer. Add no word of your own.
        - Write a summary of 2 to 4 sentences about this person, in the description's language, from their roles, studies and field. No number, date, company, school, place or person's name; no "experience", "years", "senior", "expert", "experienced".
        - For every job, write 1 to 2 sentences with the responsibilities typical of that title in that field. No number, no name, no tool name (tools go in the skills).
        - List technologies (4 to 8) and soft skills (3 to 5) that fit the person's roles, studies and field, each with its kind, no level.
        - Never add languages, jobs, studies, certifications or hobbies the description does not mention, nor a skill the person said they lack or want to learn.
        - If the description names no role, study or field, leave the summary null and the skills empty.
        - Write everything you generate (summary, role descriptions, achievements) in the language of the description. Do not translate names, titles or dates.
        """

    /// The language's name in English, which the model follows more reliably than a bare code.
    private static func languageName(forCode code: String) -> String? {
        Locale(identifier: "en").localizedString(forLanguageCode: code)
    }
}
