import Foundation

/// How the fixed instructions reach the model.
enum InstructionsDelivery: Equatable {
    /// As the session's instructions, which the model weighs above the prompt
    case session
    /// In front of the prompt, for a system where session instructions misbehave
    case promptPrefix
}

/// The text sent to the on-device model for the first pass of a draft (ADR 0031): the fixed instructions plus the person's own
/// description. This pass only extracts the facts; the second one writes around them (`DraftWritingPrompt`).
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
        - Use only what the description says. Never invent or guess a name, email address, phone number, website, employer, school, job title, date, number, percentage, result, certification, skill level or language level.
        - If the description does not say something, leave that field null and that list empty. A short description gives a short CV.
        - Copy names of people, companies, schools, places, certifications and job titles exactly as written. Copy dates exactly as written.
        - Write each achievement by copying the person's own words exactly, starting with the verb and leaving out the name of the employer. Add no word of your own.
        - Write everything you generate (summary, role descriptions, achievements) in the language of the description. Do not translate names, titles or dates.
        - Do not add skills, languages, jobs, studies or hobbies the description does not mention.
        - The summary restates the description in at most three sentences. Add no numbers the person did not give.
        """

    /// The language's name in English, which the model follows more reliably than a bare code.
    static func languageName(forCode code: String) -> String? {
        Locale(identifier: "en").localizedString(forLanguageCode: code)
    }
}
