import Testing
import Foundation
@testable import CVGeneratorAI

@Suite("DefaultCVValidator Tests")
struct DefaultCVValidatorTests {
    let validator = DefaultCVValidator()

    // MARK: - Request Validation Tests

    @Test("Valid request passes validation")
    func validRequest() throws {
        let request = CVGenerationRequest(
            userPrompt: "I am a software engineer with 5 years of experience",
            personalInfo: PersonalInfo(name: "Test", email: "test@example.com")
        )

        try validator.validateRequest(request)
        // Should not throw
    }

    @Test("Empty prompt fails validation")
    func emptyPrompt() {
        let request = CVGenerationRequest(userPrompt: "   ")

        do {
            try validator.validateRequest(request)
            Issue.record("Should have thrown invalidPrompt")
        } catch CVGenerationError.invalidPrompt {
            // Expected error
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Short prompt fails validation")
    func shortPrompt() {
        let request = CVGenerationRequest(userPrompt: "Test")

        do {
            try validator.validateRequest(request)
            Issue.record("Should have thrown validationFailed")
        } catch CVGenerationError.validationFailed(let message) {
            #expect(message.contains("at least 10 characters"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Invalid personal info in request fails")
    func invalidPersonalInfoInRequest() {
        let personalInfo = PersonalInfo(name: "", email: "test@example.com")
        let request = CVGenerationRequest(
            userPrompt: "Valid prompt here with enough characters",
            personalInfo: personalInfo
        )

        do {
            try validator.validateRequest(request)
            Issue.record("Should have thrown validationFailed")
        } catch CVGenerationError.validationFailed(let message) {
            #expect(message.contains("Name"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    // MARK: - CV Data Validation Tests

    @Test("Valid CV data passes validation")
    func validCVData() throws {
        let personalInfo = PersonalInfo(name: "John Doe", email: "john@example.com")
        let experience = Experience(
            title: "Engineer",
            company: "Tech Corp",
            startDate: "2020",
            description: "Building things"
        )
        let cvData = CVData(personalInfo: personalInfo, experience: [experience])

        try validator.validateCVData(cvData)
        // Should not throw
    }

    @Test("CV with empty name fails")
    func emptyName() {
        let personalInfo = PersonalInfo(name: "   ", email: "test@example.com")
        let cvData = CVData(personalInfo: personalInfo)

        do {
            try validator.validateCVData(cvData)
            Issue.record("Should have thrown validationFailed")
        } catch CVGenerationError.validationFailed(let message) {
            #expect(message.contains("Name"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("CV with invalid email fails")
    func invalidEmail() {
        let personalInfo = PersonalInfo(name: "Test", email: "notanemail")
        let experience = Experience(
            title: "Engineer",
            company: "Company",
            startDate: "2020",
            description: "Work"
        )
        let cvData = CVData(personalInfo: personalInfo, experience: [experience])

        do {
            try validator.validateCVData(cvData)
            Issue.record("Should have thrown validationFailed")
        } catch CVGenerationError.validationFailed(let message) {
            #expect(message.contains("email"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("CV without content fails")
    func noContent() {
        let personalInfo = PersonalInfo(name: "Test", email: "test@example.com")
        let cvData = CVData(personalInfo: personalInfo)

        do {
            try validator.validateCVData(cvData)
            Issue.record("Should have thrown validationFailed")
        } catch CVGenerationError.validationFailed(let message) {
            #expect(message.contains("at least one section"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Experience with empty title fails")
    func experienceEmptyTitle() {
        let personalInfo = PersonalInfo(name: "Test", email: "test@example.com")
        let experience = Experience(
            title: "   ",
            company: "Company",
            startDate: "2020",
            description: "Work"
        )
        let cvData = CVData(personalInfo: personalInfo, experience: [experience])

        do {
            try validator.validateCVData(cvData)
            Issue.record("Should have thrown validationFailed")
        } catch CVGenerationError.validationFailed(let message) {
            #expect(message.contains("title"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Education with empty degree fails")
    func educationEmptyDegree() {
        let personalInfo = PersonalInfo(name: "Test", email: "test@example.com")
        let education = Education(
            degree: "",
            institution: "University",
            startDate: "2015",
            endDate: "2019"
        )
        let cvData = CVData(personalInfo: personalInfo, education: [education])

        do {
            try validator.validateCVData(cvData)
            Issue.record("Should have thrown validationFailed")
        } catch CVGenerationError.validationFailed(let message) {
            #expect(message.contains("Degree"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

@Suite("CVGeneratorUseCase Tests")
struct CVGeneratorUseCaseTests {
    @Test("Use case delegates to service")
    func useCaseDelegation() async throws {
        let service = MockCVGenerationService(shouldSucceed: true, mockDelay: 0.1)
        let useCase = CVGeneratorUseCase(service: service)

        let request = CVGenerationRequest(
            userPrompt: "I am a software engineer with experience in Swift and iOS development"
        )

        let result = try await useCase.generateCV(from: request)

        #expect(result.cvData.personalInfo.name == "John Doe")
        #expect(result.confidence > 0)
    }

    @Test("Use case validates request before generation")
    func validateRequestFirst() async {
        let service = MockCVGenerationService()
        let useCase = CVGeneratorUseCase(service: service)

        let invalidRequest = CVGenerationRequest(userPrompt: "")

        do {
            _ = try await useCase.generateCV(from: invalidRequest)
            Issue.record("Should have thrown invalidPrompt")
        } catch CVGenerationError.invalidPrompt {
            // Expected error - validation happened before service call
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Use case checks availability")
    func checkAvailability() async {
        let service = MockCVGenerationService()
        let useCase = CVGeneratorUseCase(service: service)

        let available = await useCase.isAvailable()
        #expect(available == true)
    }
}
