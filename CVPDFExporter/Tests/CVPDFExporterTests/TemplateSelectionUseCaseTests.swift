import XCTest
@testable import CVPDFExporter

final class TemplateSelectionUseCaseTests: XCTestCase {

    var sut: TemplateSelectionUseCase!
    var repository: MockTemplateRepository!

    override func setUp() {
        super.setUp()
        repository = MockTemplateRepository()
        sut = TemplateSelectionUseCase(repository: repository)
    }

    override func tearDown() {
        sut = nil
        repository = nil
        super.tearDown()
    }

    // MARK: - Tests

    func test_getAvailableTemplates_returnsAllTemplates() async throws {
        // Given
        let expectedTemplates = [
            Template(id: "modern", name: "Modern", htmlContent: "<html>modern</html>"),
            Template(id: "professional", name: "Professional", htmlContent: "<html>pro</html>"),
            Template(id: "minimal", name: "Minimal", htmlContent: "<html>min</html>")
        ]
        repository.templates = expectedTemplates

        // When
        let templates = try await sut.getAvailableTemplates()

        // Then
        XCTAssertEqual(templates.count, 3)
        XCTAssertEqual(templates, expectedTemplates)
    }

    func test_recommendTemplate_forTechnicalCV_returnsModern() async throws {
        // Given
        let cv = createTechnicalCV()
        repository.templates = createAllTemplates()

        // When
        let recommended = try await sut.recommendTemplate(for: cv)

        // Then
        XCTAssertEqual(recommended.id, "modern")
        XCTAssertEqual(recommended.name, "Modern")
    }

    func test_recommendTemplate_forExecutiveCV_returnsProfessional() async throws {
        // Given
        let cv = createExecutiveCV()
        repository.templates = createAllTemplates()

        // When
        let recommended = try await sut.recommendTemplate(for: cv)

        // Then
        XCTAssertEqual(recommended.id, "professional")
        XCTAssertEqual(recommended.name, "Professional")
    }

    func test_recommendTemplate_forCreativeCV_returnsCreative() async throws {
        // Given
        let cv = createCreativeCV()
        repository.templates = createAllTemplates()

        // When
        let recommended = try await sut.recommendTemplate(for: cv)

        // Then
        XCTAssertEqual(recommended.id, "creative")
        XCTAssertEqual(recommended.name, "Creative")
    }

    func test_getTemplateById_existingId_returnsTemplate() async throws {
        // Given
        let templates = createAllTemplates()
        repository.templates = templates

        // When
        let template = try await sut.getTemplate(byId: "modern")

        // Then
        XCTAssertNotNil(template)
        XCTAssertEqual(template?.id, "modern")
    }

    func test_getTemplateById_nonExistingId_returnsNil() async throws {
        // Given
        repository.templates = createAllTemplates()

        // When
        let template = try await sut.getTemplate(byId: "nonexistent")

        // Then
        XCTAssertNil(template)
    }

    func test_filterTemplates_byPremium_returnsOnlyPremium() async throws {
        // Given
        repository.templates = [
            Template(id: "1", name: "Free", htmlContent: "", isPremium: false),
            Template(id: "2", name: "Premium1", htmlContent: "", isPremium: true),
            Template(id: "3", name: "Premium2", htmlContent: "", isPremium: true)
        ]

        // When
        let premiumTemplates = try await sut.filterTemplates(isPremium: true)

        // Then
        XCTAssertEqual(premiumTemplates.count, 2)
        XCTAssertTrue(premiumTemplates.allSatisfy { $0.isPremium })
    }

    // MARK: - Helpers

    private func createTechnicalCV() -> CVDocument {
        CVDocument(
            personalInfo: PersonalInfo(
                name: "Tech Developer",
                email: "tech@example.com",
                phone: nil,
                location: nil,
                website: nil,
                summary: "iOS Developer with Swift expertise"
            ),
            sections: [
                CVSection(type: .skills, title: "Skills", items: [
                    CVItem(
                        title: "Programming",
                        subtitle: nil,
                        description: nil,
                        startDate: nil,
                        endDate: nil,
                        location: nil,
                        tags: ["Swift", "SwiftUI", "iOS"]
                    )
                ])
            ]
        )
    }

    private func createExecutiveCV() -> CVDocument {
        CVDocument(
            personalInfo: PersonalInfo(
                name: "Executive Leader",
                email: "exec@example.com",
                phone: nil,
                location: nil,
                website: nil,
                summary: "Senior executive with 20+ years experience"
            ),
            sections: [
                CVSection(type: .work, title: "Experience", items: [
                    CVItem(
                        title: "CEO",
                        subtitle: "Fortune 500 Company",
                        description: "Led company transformation",
                        startDate: "2015",
                        endDate: "Present",
                        location: "New York",
                        tags: []
                    )
                ])
            ]
        )
    }

    private func createCreativeCV() -> CVDocument {
        CVDocument(
            personalInfo: PersonalInfo(
                name: "Creative Designer",
                email: "design@example.com",
                phone: nil,
                location: nil,
                website: "portfolio.com",
                summary: "UI/UX Designer with creative portfolio"
            ),
            sections: [
                CVSection(type: .projects, title: "Projects", items: [
                    CVItem(
                        title: "Brand Redesign",
                        subtitle: "Major Client",
                        description: "Complete visual identity overhaul",
                        startDate: nil,
                        endDate: nil,
                        location: nil,
                        tags: ["Design", "Branding"]
                    )
                ])
            ]
        )
    }

    private func createAllTemplates() -> [Template] {
        [
            Template(id: "modern", name: "Modern", htmlContent: "<html>modern</html>"),
            Template(id: "professional", name: "Professional", htmlContent: "<html>pro</html>"),
            Template(id: "minimal", name: "Minimal", htmlContent: "<html>min</html>"),
            Template(id: "creative", name: "Creative", htmlContent: "<html>creative</html>", isPremium: true)
        ]
    }
}

// MARK: - Mock Repository

final class MockTemplateRepository: TemplateRepositoryProtocol, @unchecked Sendable {
    var templates: [Template] = []

    func getTemplates() async throws -> [Template] {
        templates
    }

    func getTemplate(id: String) async throws -> Template? {
        templates.first { $0.id == id }
    }

    func installTemplate(_ package: TemplatePackage) async throws {
        // Mock implementation - no-op for tests
    }
}