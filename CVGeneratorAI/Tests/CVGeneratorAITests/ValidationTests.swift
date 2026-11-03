import Testing
import Foundation
@testable import CVGeneratorAI

@Suite("DefaultCVValidator Tests")
struct DefaultCVValidatorTests {
    let validator = DefaultCVValidator()

    // MARK: - Request Validation Tests

    @Test("A description within the limits passes validation")
    func validRequest() throws {
        let request = CVGenerationRequest(userPrompt: "I am a software engineer with 5 years of experience")

        try validator.validateRequest(request)
    }

    @Test("An empty or blank description is too short", arguments: ["", "   ", "\n\n"])
    func blankPrompt(prompt: String) {
        #expect(throws: CVGenerationError.descriptionTooShort) {
            try validator.validateRequest(CVGenerationRequest(userPrompt: prompt))
        }
    }

    @Test("A description under 10 characters is too short")
    func shortPrompt() {
        #expect(throws: CVGenerationError.descriptionTooShort) {
            try validator.validateRequest(CVGenerationRequest(userPrompt: "Nurse, 5y"))
        }
    }

    @Test("The shortest and longest allowed descriptions pass")
    func boundaryLengthsPass() throws {
        let shortest = String(repeating: "a", count: CVGenerationLimits.minimumDescriptionLength)
        let longest = String(repeating: "a", count: CVGenerationLimits.maximumDescriptionLength)

        try validator.validateRequest(CVGenerationRequest(userPrompt: shortest))
        try validator.validateRequest(CVGenerationRequest(userPrompt: longest))
    }

    @Test("A description over 2,000 characters is too long")
    func longPrompt() {
        let prompt = String(repeating: "a", count: CVGenerationLimits.maximumDescriptionLength + 1)

        #expect(throws: CVGenerationError.descriptionTooLong) {
            try validator.validateRequest(CVGenerationRequest(userPrompt: prompt))
        }
    }

    @Test("Surrounding whitespace does not count towards the length")
    func whitespaceIsNotCounted() {
        let padded = "   short   "

        #expect(throws: CVGenerationError.descriptionTooShort) {
            try validator.validateRequest(CVGenerationRequest(userPrompt: padded))
        }
    }

    // MARK: - CV Data Validation Tests

    @Test("A CV without a name or an email is valid")
    func missingNameAndEmailAreValid() throws {
        let cvData = CVData(experience: [Experience(title: "Nurse")])

        try validator.validateCVData(cvData)
    }

    @Test("A CV with a well-formed email is valid")
    func wellFormedEmailIsValid() throws {
        let cvData = CVData(personalInfo: PersonalInfo(email: "john@example.com"))

        try validator.validateCVData(cvData)
    }

    @Test("A blank email is treated as absent")
    func blankEmailIsAbsent() throws {
        let cvData = CVData(
            personalInfo: PersonalInfo(email: "  "),
            skills: [Skill(name: "Swift")]
        )

        try validator.validateCVData(cvData)
    }

    @Test("A malformed email fails")
    func malformedEmail() {
        let cvData = CVData(
            personalInfo: PersonalInfo(email: "notanemail"),
            skills: [Skill(name: "Swift")]
        )

        #expect(throws: CVGenerationError.generationFailed) {
            try validator.validateCVData(cvData)
        }
    }

    @Test("A CV with nothing in it is an empty result")
    func noContent() {
        #expect(throws: CVGenerationError.emptyResult) {
            try validator.validateCVData(CVData())
        }
    }

    @Test("Blank personal fields do not count as content")
    func blankFieldsAreNoContent() {
        let cvData = CVData(personalInfo: PersonalInfo(name: " ", title: ""), summary: "  ")

        #expect(throws: CVGenerationError.emptyResult) {
            try validator.validateCVData(cvData)
        }
    }

    @Test("A summary alone is no content: the model writes it, and a draft with no fact about the person is none (ADR 0031)")
    func summaryAloneIsNoContent() {
        #expect(throws: CVGenerationError.emptyResult) {
            try validator.validateCVData(CVData(summary: "A dedicated professional who works well with others."))
        }
    }

    @Test("Any single section of facts is enough content")
    func anySectionIsContent() throws {
        let cvs = [
            CVData(personalInfo: PersonalInfo(name: "Mario Rossi")),
            CVData(personalInfo: PersonalInfo(title: "Nurse"), summary: "A nurse."),
            CVData(experience: [Experience(company: "Hospital")]),
            CVData(education: [Education(degree: "Nursing")]),
            CVData(skills: [Skill(name: "Care")]),
            CVData(languages: [Language(name: "Italian")]),
            CVData(certifications: [Certification(name: "BLS")]),
            CVData(interests: ["Chess"]),
        ]

        for cvData in cvs {
            try validator.validateCVData(cvData)
        }
    }
}
