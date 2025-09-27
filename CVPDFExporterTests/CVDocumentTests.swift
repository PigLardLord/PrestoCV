import Testing
import Foundation
@testable import PrestoCV

// MARK: - CVDocument Tests

@Suite("CVDocument Models")
struct CVDocumentTests {

    // MARK: - PersonalInfo Tests

    @Test("Personal info initialization with all fields")
    func personalInfoInitialization() {
        let info = PersonalInfo(
            name: "John Doe",
            email: "john@example.com",
            phone: "+1234567890",
            location: "New York",
            website: "https://johndoe.com",
            summary: "Test summary"
        )

        #expect(info.name == "John Doe")
        #expect(info.email == "john@example.com")
        #expect(info.phone == "+1234567890")
        #expect(info.location == "New York")
        #expect(info.website == "https://johndoe.com")
        #expect(info.summary == "Test summary")
    }

    @Test("Personal info with optional fields")
    func personalInfoWithOptionalFields() {
        let info = PersonalInfo(
            name: "Jane Doe",
            email: "jane@example.com"
        )

        #expect(info.name == "Jane Doe")
        #expect(info.email == "jane@example.com")
        #expect(info.phone == nil)
        #expect(info.location == nil)
        #expect(info.website == nil)
        #expect(info.summary == nil)
    }

    // MARK: - CVItem Tests

    @Test("CV item initialization with all fields")
    func cvItemInitialization() {
        let item = CVItem(
            title: "Software Engineer",
            subtitle: "Tech Corp",
            description: "Developed iOS apps",
            startDate: "Jan 2020",
            endDate: "Dec 2023",
            location: "San Francisco",
            tags: ["Swift", "iOS"]
        )

        #expect(item.title == "Software Engineer")
        #expect(item.subtitle == "Tech Corp")
        #expect(item.description == "Developed iOS apps")
        #expect(item.startDate == "Jan 2020")
        #expect(item.endDate == "Dec 2023")
        #expect(item.location == "San Francisco")
        #expect(item.tags == ["Swift", "iOS"])
    }

    @Test("CV item with minimal fields")
    func cvItemWithMinimalFields() {
        let item = CVItem(title: "Developer")

        #expect(item.title == "Developer")
        #expect(item.subtitle == nil)
        #expect(item.description == nil)
        #expect(item.startDate == nil)
        #expect(item.endDate == nil)
        #expect(item.location == nil)
        #expect(item.tags.isEmpty)
    }

    // MARK: - CVSection Tests

    @Test("CV section initialization")
    func cvSectionInitialization() {
        let section = CVSection(
            id: "work",
            type: .work,
            title: "Work Experience",
            items: [],
            order: 1
        )

        #expect(section.id == "work")
        #expect(section.type == .work)
        #expect(section.title == "Work Experience")
        #expect(section.items.isEmpty)
        #expect(section.order == 1)
        #expect(section.visible == true)
    }

    @Test("Section types have correct values")
    func sectionTypeValues() {
        #expect(SectionType.work.rawValue == "work")
        #expect(SectionType.education.rawValue == "education")
        #expect(SectionType.skills.rawValue == "skills")
        #expect(SectionType.custom.rawValue == "custom")
    }

    // MARK: - CVDocument Tests

    @Test("CV document initialization")
    func cvDocumentInitialization() {
        let personalInfo = PersonalInfo(
            name: "Test User",
            email: "test@example.com"
        )
        let document = CVDocument(
            personalInfo: personalInfo,
            sections: [],
            metadata: DocumentMetadata()
        )

        #expect(document.personalInfo.name == "Test User")
        #expect(document.sections.isEmpty)
        #expect(document.metadata.version == "1.0")
    }

    @Test("CV document with multiple sections")
    func cvDocumentWithMultipleSections() {
        let personalInfo = PersonalInfo(
            name: "Test User",
            email: "test@example.com"
        )

        let workSection = CVSection(
            id: "work",
            type: .work,
            title: "Experience",
            items: []
        )

        let educationSection = CVSection(
            id: "edu",
            type: .education,
            title: "Education",
            items: []
        )

        let document = CVDocument(
            personalInfo: personalInfo,
            sections: [workSection, educationSection],
            metadata: DocumentMetadata()
        )

        #expect(document.sections.count == 2)
        #expect(document.sections[0].type == .work)
        #expect(document.sections[1].type == .education)
    }

    // MARK: - DocumentMetadata Tests

    @Test("Document metadata default values")
    func documentMetadataDefaults() {
        let metadata = DocumentMetadata()

        #expect(metadata.version == "1.0")
        #expect(metadata.createdAt != nil)
        #expect(metadata.updatedAt != nil)
    }

    @Test("Document metadata with custom values")
    func documentMetadataCustomValues() {
        let customFields = ["templateId": "professional"]
        let metadata = DocumentMetadata(
            version: "2.0",
            customFields: customFields
        )

        #expect(metadata.version == "2.0")
        #expect(metadata.customFields["templateId"] == "professional")
    }
}