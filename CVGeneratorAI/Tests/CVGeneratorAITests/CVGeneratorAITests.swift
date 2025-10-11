import Testing
import Foundation
@testable import CVGeneratorAI

// MARK: - Model Tests

@Suite("CVData Model Tests")
struct CVDataTests {
    @Test("CVData initialization with all fields")
    func cvDataInitialization() {
        let personalInfo = PersonalInfo(
            name: "John Doe",
            email: "john@example.com",
            phone: "+1234567890",
            location: "New York",
            title: "Engineer"
        )

        let cv = CVData(
            personalInfo: personalInfo,
            summary: "Professional summary",
            experience: [],
            education: [],
            skills: [],
            languages: [],
            certifications: [],
            projects: [],
            interests: ["Reading", "Coding"]
        )

        #expect(cv.personalInfo.name == "John Doe")
        #expect(cv.summary == "Professional summary")
        #expect(cv.interests.count == 2)
    }

    @Test("CVData is Codable")
    func cvDataCodable() throws {
        let personalInfo = PersonalInfo(name: "Test", email: "test@test.com")
        let cv = CVData(personalInfo: personalInfo)

        let encoder = JSONEncoder()
        let data = try encoder.encode(cv)
        #expect(!data.isEmpty)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CVData.self, from: data)
        #expect(decoded.personalInfo.name == "Test")
    }
}

@Suite("Experience Model Tests")
struct ExperienceTests {
    @Test("Experience with all fields")
    func experienceWithAllFields() {
        let exp = Experience(
            title: "Senior Engineer",
            company: "Tech Corp",
            location: "SF",
            startDate: "2020",
            endDate: "2023",
            current: false,
            description: "Built amazing things",
            achievements: ["Achievement 1", "Achievement 2"],
            technologies: ["Swift", "iOS"]
        )

        #expect(exp.title == "Senior Engineer")
        #expect(exp.achievements.count == 2)
        #expect(exp.technologies.contains("Swift"))
    }

    @Test("Experience marked as current has no end date")
    func currentExperience() {
        let exp = Experience(
            title: "Engineer",
            company: "Company",
            startDate: "2023",
            endDate: nil,
            current: true,
            description: "Current role"
        )

        #expect(exp.current == true)
        #expect(exp.endDate == nil)
    }
}

@Suite("Skill Model Tests")
struct SkillTests {
    @Test("Skill level enum has all cases")
    func skillLevelCases() {
        #expect(SkillLevel.allCases.count == 4)
        #expect(SkillLevel.allCases.contains(.beginner))
        #expect(SkillLevel.allCases.contains(.expert))
    }

    @Test("Skill with category and years")
    func skillWithMetadata() {
        let skill = Skill(
            name: "Swift",
            level: .expert,
            category: "Programming",
            yearsOfExperience: 5
        )

        #expect(skill.name == "Swift")
        #expect(skill.level == .expert)
        #expect(skill.yearsOfExperience == 5)
    }
}

@Suite("Language Model Tests")
struct LanguageTests {
    @Test("Language proficiency enum")
    func languageProficiency() {
        #expect(LanguageProficiency.allCases.count == 7)
        #expect(LanguageProficiency.native.rawValue == "Native")
        #expect(LanguageProficiency.c2.rawValue == "C2")
    }
}

// MARK: - Request/Response Tests

@Suite("CVGenerationRequest Tests")
struct CVGenerationRequestTests {
    @Test("Request with minimal fields")
    func minimalRequest() {
        let request = CVGenerationRequest(userPrompt: "I am a software engineer")

        #expect(request.userPrompt == "I am a software engineer")
        #expect(request.personalInfo == nil)
        #expect(request.preferences.experienceLevel == .intermediate)
    }

    @Test("Request with full preferences")
    func fullRequest() {
        let personalInfo = PersonalInfo(name: "Test", email: "test@test.com")
        let preferences = GenerationPreferences(
            targetRole: "iOS Developer",
            experienceLevel: .senior,
            focusAreas: ["iOS", "SwiftUI"],
            tone: .technical
        )

        let request = CVGenerationRequest(
            userPrompt: "Background info",
            personalInfo: personalInfo,
            preferences: preferences
        )

        #expect(request.preferences.targetRole == "iOS Developer")
        #expect(request.preferences.focusAreas.count == 2)
        #expect(request.preferences.tone == .technical)
    }
}

@Suite("CVGenerationResult Tests")
struct CVGenerationResultTests {
    @Test("Result with confidence and suggestions")
    func resultWithMetadata() {
        let personalInfo = PersonalInfo(name: "Test", email: "test@test.com")
        let cvData = CVData(personalInfo: personalInfo)

        let result = CVGenerationResult(
            cvData: cvData,
            confidence: 0.9,
            suggestions: ["Add more details", "Include certifications"]
        )

        #expect(result.confidence == 0.9)
        #expect(result.suggestions.count == 2)
        #expect(result.cvData.personalInfo.name == "Test")
    }
}

@Suite("CVGenerationError Tests")
struct CVGenerationErrorTests {
    @Test("Error types and descriptions")
    func errorDescriptions() {
        let unavailable = CVGenerationError.serviceUnavailable
        #expect(unavailable.errorDescription != nil)

        let invalid = CVGenerationError.invalidPrompt
        #expect(invalid.errorDescription != nil)

        let validation = CVGenerationError.validationFailed("test")
        #expect(validation.errorDescription?.contains("test") == true)
    }
}

// MARK: - Service Tests

@Suite("MockCVGenerationService Tests")
struct MockServiceTests {
    @Test("Mock service is always available")
    func mockServiceAvailability() async {
        let service = MockCVGenerationService()
        let available = await service.isAvailable()
        #expect(available == true)
    }

    @Test("Mock service generates CV successfully")
    func mockServiceGeneration() async throws {
        let service = MockCVGenerationService(shouldSucceed: true, mockDelay: 0.1)
        let request = CVGenerationRequest(userPrompt: "I am a software engineer with 5 years experience")

        let result = try await service.generateCV(from: request)

        #expect(result.cvData.personalInfo.name == "John Doe")
        #expect(result.confidence > 0)
        #expect(!result.suggestions.isEmpty)
    }

    @Test("Mock service fails with empty prompt")
    func mockServiceEmptyPrompt() async {
        let service = MockCVGenerationService()
        let request = CVGenerationRequest(userPrompt: "  ")

        do {
            _ = try await service.generateCV(from: request)
            Issue.record("Should have thrown invalidPrompt error")
        } catch CVGenerationError.invalidPrompt {
            // Expected error
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Mock service can be configured to fail")
    func mockServiceConfiguredFailure() async {
        let service = MockCVGenerationService(shouldSucceed: false)
        let request = CVGenerationRequest(userPrompt: "Test prompt")

        do {
            _ = try await service.generateCV(from: request)
            Issue.record("Should have thrown error")
        } catch {
            // Expected to fail
        }
    }
}
