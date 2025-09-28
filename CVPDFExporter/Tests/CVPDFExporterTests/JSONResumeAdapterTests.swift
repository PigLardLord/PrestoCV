import Testing
import Foundation
@testable import CVPDFExporter

// MARK: - JSON Resume Adapter Tests (Sprint 5)

@Suite("JSON Resume Adapter")
struct JSONResumeAdapterTests {

    @Test("Convert CVDocument to JSON Resume")
    func convertCVDocumentToJSONResume() {
        // Given
        let adapter = JSONResumeAdapter()
        let document = CVDocument(
            personalInfo: PersonalInfo(
                name: "John Doe",
                email: "john@example.com",
                phone: "+1 234 567 8900",
                location: "San Francisco, CA",
                website: "https://johndoe.com",
                summary: "Experienced developer"
            ),
            sections: [],
            metadata: DocumentMetadata()
        )

        // When
        let jsonResume = adapter.toJSONResume(from: document)

        // Then
        #expect(jsonResume.basics?.name == "John Doe")
        #expect(jsonResume.basics?.email == "john@example.com")
        #expect(jsonResume.basics?.phone == "+1 234 567 8900")
        #expect(jsonResume.basics?.url == "https://johndoe.com")
        #expect(jsonResume.basics?.summary == "Experienced developer")
    }

    @Test("Convert work experience to JSON Resume")
    func convertWorkExperienceToJSONResume() {
        // Given
        let adapter = JSONResumeAdapter()
        let document = CVDocument(
            personalInfo: PersonalInfo(name: "Jane", email: "jane@example.com"),
            sections: [
                CVSection(
                    id: "work",
                    type: .work,
                    title: "Experience",
                    items: [
                        CVItem(
                            title: "Senior Developer",
                            subtitle: "Tech Corp",
                            description: "Led development team",
                            startDate: "2020-01",
                            endDate: "2023-12",
                            location: "Remote"
                        )
                    ]
                )
            ],
            metadata: DocumentMetadata()
        )

        // When
        let jsonResume = adapter.toJSONResume(from: document)

        // Then
        #expect(jsonResume.work?.count == 1)
        #expect(jsonResume.work?.first?.position == "Senior Developer")
        #expect(jsonResume.work?.first?.name == "Tech Corp")
        #expect(jsonResume.work?.first?.summary == "Led development team")
        #expect(jsonResume.work?.first?.startDate == "2020-01")
    }

    @Test("Convert education to JSON Resume")
    func convertEducationToJSONResume() {
        // Given
        let adapter = JSONResumeAdapter()
        let document = CVDocument(
            personalInfo: PersonalInfo(name: "Student", email: "student@example.com"),
            sections: [
                CVSection(
                    id: "edu",
                    type: .education,
                    title: "Education",
                    items: [
                        CVItem(
                            title: "Computer Science",
                            subtitle: "MIT",
                            description: "Bachelor of Science",
                            startDate: "2016",
                            endDate: "2020"
                        )
                    ]
                )
            ],
            metadata: DocumentMetadata()
        )

        // When
        let jsonResume = adapter.toJSONResume(from: document)

        // Then
        #expect(jsonResume.education?.count == 1)
        #expect(jsonResume.education?.first?.area == "Computer Science")
        #expect(jsonResume.education?.first?.institution == "MIT")
        #expect(jsonResume.education?.first?.studyType == "Bachelor of Science")
    }

    @Test("Convert skills to JSON Resume")
    func convertSkillsToJSONResume() {
        // Given
        let adapter = JSONResumeAdapter()
        let document = CVDocument(
            personalInfo: PersonalInfo(name: "Dev", email: "dev@example.com"),
            sections: [
                CVSection(
                    id: "skills",
                    type: .skills,
                    title: "Skills",
                    items: [
                        CVItem(
                            title: "Programming",
                            tags: ["Swift", "Python", "JavaScript"]
                        ),
                        CVItem(
                            title: "Frameworks",
                            tags: ["SwiftUI", "UIKit", "React"]
                        )
                    ]
                )
            ],
            metadata: DocumentMetadata()
        )

        // When
        let jsonResume = adapter.toJSONResume(from: document)

        // Then
        #expect(jsonResume.skills?.count == 2)
        #expect(jsonResume.skills?.first?.name == "Programming")
        #expect(jsonResume.skills?.first?.keywords?.count == 3)
        #expect(jsonResume.skills?.first?.keywords?.contains("Swift") == true)
    }

    @Test("Convert JSON Resume back to CVDocument")
    func convertJSONResumeToCVDocument() {
        // Given
        let adapter = JSONResumeAdapter()
        let jsonResume = JSONResume(
            basics: JSONResume.Basics(
                name: "Jane Smith",
                label: "Designer",
                email: "jane@design.com",
                phone: "+1 555 1234",
                url: "https://janesmith.design",
                summary: "Creative designer"
            ),
            work: [
                JSONResume.Work(
                    name: "Design Studio",
                    position: "Lead Designer",
                    startDate: "2020-03",
                    summary: "Leading design projects"
                )
            ]
        )

        // When
        let document = adapter.fromJSONResume(jsonResume)

        // Then
        #expect(document.personalInfo.name == "Jane Smith")
        #expect(document.personalInfo.email == "jane@design.com")
        #expect(document.personalInfo.phone == "+1 555 1234")
        #expect(document.personalInfo.website == "https://janesmith.design")
        #expect(document.personalInfo.summary == "Creative designer")

        // Check work section
        let workSection = document.sections.first { $0.type == .work }
        #expect(workSection != nil)
        #expect(workSection?.items.first?.title == "Lead Designer")
        #expect(workSection?.items.first?.subtitle == "Design Studio")
    }

    @Test("Round trip conversion preserves data")
    func roundTripConversion() {
        // Given
        let adapter = JSONResumeAdapter()
        let originalDocument = CVDocument(
            personalInfo: PersonalInfo(
                name: "Test User",
                email: "test@example.com",
                phone: "+1 234 567",
                location: "New York",
                website: "https://test.com",
                summary: "Test summary"
            ),
            sections: [
                CVSection(
                    id: "work",
                    type: .work,
                    title: "Experience",
                    items: [
                        CVItem(
                            title: "Developer",
                            subtitle: "Company",
                            description: "Description",
                            startDate: "2020",
                            endDate: "2023"
                        )
                    ]
                )
            ],
            metadata: DocumentMetadata()
        )

        // When
        let jsonResume = adapter.toJSONResume(from: originalDocument)
        let convertedDocument = adapter.fromJSONResume(jsonResume)

        // Then
        #expect(convertedDocument.personalInfo.name == originalDocument.personalInfo.name)
        #expect(convertedDocument.personalInfo.email == originalDocument.personalInfo.email)
        #expect(convertedDocument.sections.count == originalDocument.sections.count)
    }

    @Test("Handle empty sections gracefully")
    func handleEmptySections() {
        // Given
        let adapter = JSONResumeAdapter()
        let document = CVDocument(
            personalInfo: PersonalInfo(name: "Empty", email: "empty@example.com"),
            sections: [],
            metadata: DocumentMetadata()
        )

        // When
        let jsonResume = adapter.toJSONResume(from: document)

        // Then
        #expect(jsonResume.basics?.name == "Empty")
        #expect(jsonResume.work == nil || jsonResume.work?.isEmpty == true)
        #expect(jsonResume.education == nil || jsonResume.education?.isEmpty == true)
        #expect(jsonResume.skills == nil || jsonResume.skills?.isEmpty == true)
    }

    @Test("Parse location from string")
    func parseLocationFromString() {
        // Given
        let adapter = JSONResumeAdapter()
        let document = CVDocument(
            personalInfo: PersonalInfo(
                name: "John",
                email: "john@example.com",
                location: "San Francisco, CA, USA"
            ),
            sections: [],
            metadata: DocumentMetadata()
        )

        // When
        let jsonResume = adapter.toJSONResume(from: document)

        // Then
        #expect(jsonResume.basics?.location?.city != nil ||
                jsonResume.basics?.location?.address == "San Francisco, CA, USA")
    }
}