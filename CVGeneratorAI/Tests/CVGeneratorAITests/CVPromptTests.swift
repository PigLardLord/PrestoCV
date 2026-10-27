import Testing
import Foundation
@testable import CVGeneratorAI

@Suite("CVPrompt Tests")
struct CVPromptTests {
    private let request = CVGenerationRequest(userPrompt: "I'm a nurse.", fallbackLanguageCode: "it")

    @Test("The instructions go to the session and the prompt holds the description")
    func sessionDelivery() {
        let prompt = CVPrompt(request: request, delivery: .session)

        #expect(prompt.instructions == CVPrompt.instructionsText)
        #expect(prompt.text.hasSuffix("Description:\nI'm a nurse."))
        #expect(!prompt.text.contains(CVPrompt.instructionsText))
    }

    @Test("The prompt-prefix fallback puts the same instructions in front of the prompt")
    func promptPrefixDelivery() {
        let prompt = CVPrompt(request: request, delivery: .promptPrefix)

        #expect(prompt.instructions == nil)
        #expect(prompt.text.hasPrefix(CVPrompt.instructionsText))
        #expect(prompt.text.hasSuffix("Description:\nI'm a nurse."))
    }

    @Test("The app language is the fallback for an unclear description")
    func fallbackLanguage() {
        let prompt = CVPrompt(request: request)

        #expect(prompt.text.contains("If the language of the description is unclear, write in Italian."))
    }

    @Test("Without an app language there is no fallback line")
    func noFallbackLanguage() {
        let prompt = CVPrompt(request: CVGenerationRequest(userPrompt: "I'm a nurse."))

        #expect(!prompt.text.contains("unclear"))
        #expect(prompt.text == "Description:\nI'm a nurse.")
    }

    @Test("The instructions forbid invented facts and keep the person's wording")
    func instructionsKeepTheRules() {
        let instructions = CVPrompt.instructionsText

        #expect(instructions.contains("Never invent or guess"))
        #expect(instructions.contains("exactly as written"))
        #expect(instructions.contains("language of the description"))
        #expect(!instructions.contains("metrics"))
        #expect(!instructions.contains("Use only what the description says"))
    }

    @Test("The instructions ask for a summary, the typical duties of each role, technologies and soft skills, with no fact of their own (ADR 0031)")
    func instructionsAskForTheWrittenText() {
        let instructions = CVPrompt.instructionsText

        #expect(instructions.contains("2 to 4 sentences"))
        #expect(instructions.contains("No number, date, company, school, place or person's name"))
        #expect(instructions.contains("no \"experience\", \"years\""), "A summary that claims experience states a fact of its own")
        #expect(instructions.contains("responsibilities typical of"))
        #expect(instructions.contains("technologies (4 to 8)"))
        #expect(instructions.contains("soft skills (3 to 5)"))
        #expect(instructions.contains("nor a skill the person said they lack or want to learn"))
        #expect(instructions.contains("If the description names no role, study or field, leave the summary null and the skills empty"))
    }

    @Test("The instructions ask for achievements copied from the description, from the verb, without the employer")
    func instructionsAskForQuotedAchievements() {
        let instructions = CVPrompt.instructionsText

        #expect(instructions.contains("Write each achievement by copying the person's own words exactly, starting with the verb"))
        #expect(instructions.contains("leaving out the name of the employer"))
    }
}
