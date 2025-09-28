import Testing
import Foundation
@testable import CVPDFExporter
#if canImport(PrestoCVCore)
import PrestoCVCore
#endif

@Suite("PrestoCVCoreAdapter")
struct PrestoCVCoreAdapterTests {

    @Test("Maps personal info correctly from CVModel")
    func test_convertToCV_mapsPersonalInfo() {
        // Given
        let adapter = PrestoCVCoreAdapter()
        let cvModel = createSampleCVModel()

        // When
        let document = adapter.convertToCV(from: cvModel)

        // Then
        #expect(document.personalInfo.name == "Jane Smith")
        #expect(document.personalInfo.email == "jane.smith@example.com")
        #expect(document.personalInfo.phone == "+1 234 567 8900")
        #expect(document.personalInfo.location == "New York, NY")
        #expect(document.personalInfo.summary == "Experienced developer")
    }

    @Test("Maps experience section from CVModel")
    func test_convertToCV_mapsExperienceSection() {
        // Given
        let adapter = PrestoCVCoreAdapter()
        let cvModel = createSampleCVModel()

        // When
        let document = adapter.convertToCV(from: cvModel)

        // Then
        let workSection = document.sections.first { $0.type == .work }
        #expect(workSection != nil)
        #expect(workSection?.items.count == 2)

        let firstExperience = workSection?.items.first
        #expect(firstExperience?.title == "Senior Developer")
        #expect(firstExperience?.subtitle == "Tech Corp")
        #expect(firstExperience?.location == "San Francisco, CA")
        #expect(firstExperience?.description?.contains("Led development") == true)
    }

    @Test("Maps education section from CVModel")
    func test_convertToCV_mapsEducationSection() {
        // Given
        let adapter = PrestoCVCoreAdapter()
        let cvModel = createSampleCVModel()

        // When
        let document = adapter.convertToCV(from: cvModel)

        // Then
        let educationSection = document.sections.first { $0.type == .education }
        #expect(educationSection != nil)
        #expect(educationSection?.items.count == 1)

        let education = educationSection?.items.first
        #expect(education?.title == "Computer Science")
        #expect(education?.subtitle == "MIT")
    }

    @Test("Maps skills section from CVModel")
    func test_convertToCV_mapsSkillsSection() {
        // Given
        let adapter = PrestoCVCoreAdapter()
        let cvModel = createSampleCVModel()

        // When
        let document = adapter.convertToCV(from: cvModel)

        // Then
        let skillsSection = document.sections.first { $0.type == .skills }
        #expect(skillsSection != nil)
        #expect(skillsSection?.items.count == 3)

        let firstSkill = skillsSection?.items.first
        #expect(firstSkill?.title == "Swift")
        #expect(firstSkill?.tags.contains("Advanced") == true)
    }

    @Test("Handles empty sections gracefully")
    func test_convertToCV_handlesEmptySections() {
        // Given
        let adapter = PrestoCVCoreAdapter()
        let emptyModel = createEmptyCVModel()

        // When
        let document = adapter.convertToCV(from: emptyModel)

        // Then
        #expect(document.personalInfo.name == "Empty User")
        #expect(document.sections.isEmpty == false) // Should still have structure
    }

    @Test("Maps languages section when present")
    func test_convertToCV_mapsLanguagesSection() {
        // Given
        let adapter = PrestoCVCoreAdapter()
        let cvModel = createSampleCVModel()

        // When
        let document = adapter.convertToCV(from: cvModel)

        // Then
        let languagesSection = document.sections.first { $0.type == .languages }
        #expect(languagesSection != nil)
        #expect(languagesSection?.items.count == 2)

        let firstLanguage = languagesSection?.items.first
        #expect(firstLanguage?.title == "English")
        #expect(firstLanguage?.subtitle == "Native")
    }

    @Test("Maps certifications section when present")
    func test_convertToCV_mapsCertificationsSection() {
        // Given
        let adapter = PrestoCVCoreAdapter()
        let cvModel = createSampleCVModel()

        // When
        let document = adapter.convertToCV(from: cvModel)

        // Then
        let certificationsSection = document.sections.first { $0.type == .certifications }
        #expect(certificationsSection != nil)
        #expect(certificationsSection?.items.first?.title == "AWS Certified")
    }

    // MARK: - Helper Methods

    private func createSampleCVModel() -> MockCVModel {
        MockCVModel(
            personalInfo: MockPersonalInfo(
                name: "Jane Smith",
                email: "jane.smith@example.com",
                phone: "+1 234 567 8900",
                location: "New York, NY",
                summary: "Experienced developer"
            ),
            experiences: [
                MockExperience(
                    title: "Senior Developer",
                    company: "Tech Corp",
                    location: "San Francisco, CA",
                    period: "2020-Present",
                    description: "Led development team"
                ),
                MockExperience(
                    title: "Developer",
                    company: "Startup Inc",
                    location: "Austin, TX",
                    period: "2018-2020",
                    description: "Built products"
                )
            ],
            education: [
                MockEducation(
                    degree: "Computer Science",
                    institution: "MIT",
                    period: "2014-2018"
                )
            ],
            skills: [
                MockSkill(name: "Swift", level: "Advanced"),
                MockSkill(name: "Python", level: "Intermediate"),
                MockSkill(name: "JavaScript", level: "Intermediate")
            ],
            languages: [
                MockLanguage(name: "English", level: "Native"),
                MockLanguage(name: "Spanish", level: "Professional")
            ],
            certifications: [
                MockCertification(
                    name: "AWS Certified",
                    issuer: "Amazon",
                    date: "2023"
                )
            ]
        )
    }

    private func createEmptyCVModel() -> MockCVModel {
        MockCVModel(
            personalInfo: MockPersonalInfo(
                name: "Empty User",
                email: "empty@example.com"
            ),
            experiences: [],
            education: [],
            skills: [],
            languages: [],
            certifications: []
        )
    }
}

// MARK: - Mock Types for Testing

private struct MockCVModel {
    let personalInfo: MockPersonalInfo
    let experiences: [MockExperience]
    let education: [MockEducation]
    let skills: [MockSkill]
    let languages: [MockLanguage]
    let certifications: [MockCertification]
}

private struct MockPersonalInfo {
    let name: String
    let email: String
    let phone: String?
    let location: String?
    let summary: String?

    init(name: String, email: String, phone: String? = nil, location: String? = nil, summary: String? = nil) {
        self.name = name
        self.email = email
        self.phone = phone
        self.location = location
        self.summary = summary
    }
}

private struct MockExperience {
    let title: String
    let company: String
    let location: String
    let period: String
    let description: String
}

private struct MockEducation {
    let degree: String
    let institution: String
    let period: String
}

private struct MockSkill {
    let name: String
    let level: String
}

private struct MockLanguage {
    let name: String
    let level: String
}

private struct MockCertification {
    let name: String
    let issuer: String
    let date: String
}