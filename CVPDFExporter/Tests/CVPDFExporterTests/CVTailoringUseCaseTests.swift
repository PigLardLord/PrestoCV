import XCTest
@testable import CVPDFExporter

final class CVTailoringUseCaseTests: XCTestCase {

    var sut: CVTailoringUseCase!
    var aiService: MockAIService!

    override func setUp() {
        super.setUp()
        aiService = MockAIService()
        sut = CVTailoringUseCase(aiService: aiService)
    }

    override func tearDown() {
        sut = nil
        aiService = nil
        super.tearDown()
    }

    // MARK: - Tests

    func test_tailorForJob_extractsRequirementsAndTailorsCV() async throws {
        // Given
        let cv = createSampleCV()
        let jobDescription = """
        We are looking for a Senior iOS Developer with 5+ years of experience.
        Required skills: Swift, SwiftUI, UIKit, Core Data.
        Experience with MVVM architecture and REST APIs is essential.
        """

        aiService.mockResult = CVTailoringResult(
            suggestedSummary: "Senior iOS Developer with expertise in Swift and SwiftUI",
            relevantSkills: ["Swift", "SwiftUI", "UIKit"],
            missingSkills: ["Core Data"],
            experienceOrder: ["exp1", "exp2"],
            highlightedAchievements: ["Led iOS team", "Increased app performance by 40%"],
            matchScore: 0.75
        )

        // When
        let result = try await sut.tailorForJob(
            cv: cv,
            jobDescription: jobDescription,
            targetRole: "Senior iOS Developer"
        )

        // Then
        XCTAssertNotNil(result.tailoredCV)
        XCTAssertEqual(result.suggestions.relevantSkills, ["Swift", "SwiftUI", "UIKit"])
        XCTAssertEqual(result.suggestions.missingSkills, ["Core Data"])
        XCTAssertEqual(result.suggestions.matchScore, 0.75)
    }

    func test_tailorForJob_usesCacheForRepeatedRequests() async throws {
        // Given
        let cv = createSampleCV()
        let jobDescription = "iOS Developer position"

        aiService.mockResult = CVTailoringResult(
            suggestedSummary: "iOS Developer",
            relevantSkills: ["Swift"],
            matchScore: 0.5
        )

        // When - First call
        let result1 = try await sut.tailorForJob(cv: cv, jobDescription: jobDescription)

        // Reset call count
        aiService.callCount = 0

        // Second call with same inputs
        let result2 = try await sut.tailorForJob(cv: cv, jobDescription: jobDescription)

        // Then
        XCTAssertEqual(result1, result2)
        XCTAssertEqual(aiService.callCount, 0) // Should use cache, not call service again
    }

    func test_suggestImprovements_detectsMissingSummary() async throws {
        // Given
        let cv = CVDocument(
            personalInfo: PersonalInfo(
                name: "John Doe",
                email: "john@example.com",
                summary: nil // Missing summary
            )
        )

        // When
        let improvements = try await sut.suggestImprovements(for: cv)

        // Then
        XCTAssertTrue(improvements.contains { $0.section == .summary })
        let summaryImprovement = improvements.first { $0.section == .summary }
        XCTAssertEqual(summaryImprovement?.priority, .high)
    }

    func test_suggestImprovements_detectsMissingSkills() async throws {
        // Given
        let cv = CVDocument(
            personalInfo: PersonalInfo(
                name: "John Doe",
                email: "john@example.com",
                summary: "Experienced developer"
            ),
            sections: [] // No skills section
        )

        // When
        let improvements = try await sut.suggestImprovements(for: cv)

        // Then
        XCTAssertTrue(improvements.contains { $0.section == .skills })
        let skillsImprovement = improvements.first { $0.section == .skills }
        XCTAssertEqual(skillsImprovement?.priority, .high)
    }

    func test_suggestImprovements_detectsLackOfQuantifiedAchievements() async throws {
        // Given
        let cv = createCVWithoutNumbers()

        // When
        let improvements = try await sut.suggestImprovements(for: cv)

        // Then
        XCTAssertTrue(improvements.contains {
            $0.suggestion.contains("quantified achievements")
        })
    }

    func test_analyzeJobPosting_extractsRequirements() async throws {
        // Given
        let jobDescription = """
        Senior iOS Developer
        Required: Swift, SwiftUI, 5+ years experience
        Nice to have: React Native, TypeScript
        Bachelor's degree in Computer Science
        """

        // When
        let requirements = try await sut.analyzeJobPosting(jobDescription)

        // Then
        XCTAssertFalse(requirements.requiredSkills.isEmpty)
    }

    func test_isAvailable_returnsServiceAvailability() {
        // Given
        aiService.available = true

        // Then
        XCTAssertTrue(sut.isAvailable)

        // When
        aiService.available = false

        // Then
        XCTAssertFalse(sut.isAvailable)
    }

    // MARK: - Helpers

    private func createSampleCV() -> CVDocument {
        CVDocument(
            personalInfo: PersonalInfo(
                name: "John Doe",
                email: "john@example.com",
                summary: "Experienced iOS Developer"
            ),
            sections: [
                CVSection(
                    id: "skills",
                    type: .skills,
                    title: "Skills",
                    items: [
                        CVItem(
                            title: "Programming",
                            tags: ["Swift", "SwiftUI", "UIKit"]
                        )
                    ]
                ),
                CVSection(
                    id: "work",
                    type: .work,
                    title: "Experience",
                    items: [
                        CVItem(
                            id: "exp1",
                            title: "Senior iOS Developer",
                            subtitle: "Tech Corp",
                            description: "Led iOS team in developing flagship app"
                        ),
                        CVItem(
                            id: "exp2",
                            title: "iOS Developer",
                            subtitle: "StartupXYZ",
                            description: "Increased app performance by 40%"
                        )
                    ]
                )
            ]
        )
    }

    private func createCVWithoutNumbers() -> CVDocument {
        CVDocument(
            personalInfo: PersonalInfo(
                name: "Jane Doe",
                email: "jane@example.com",
                summary: "Software Developer"
            ),
            sections: [
                CVSection(
                    type: .work,
                    title: "Experience",
                    items: [
                        CVItem(
                            title: "Developer",
                            description: "Developed applications and improved systems"
                        )
                    ]
                ),
                CVSection(
                    type: .skills,
                    title: "Skills",
                    items: [
                        CVItem(title: "Programming", tags: ["Swift"])
                    ]
                )
            ]
        )
    }
}

// MARK: - Mock AI Service

final class MockAIService: CVTailoringServiceProtocol, @unchecked Sendable {
    var mockResult = CVTailoringResult()
    var callCount = 0
    var available = true

    var isAvailable: Bool { available }

    func tailorCV(
        jobDescription: String,
        cvDocument: CVDocument,
        targetRole: String?
    ) async throws -> CVTailoringResult {
        callCount += 1
        return mockResult
    }
}