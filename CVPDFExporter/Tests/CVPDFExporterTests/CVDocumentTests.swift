import XCTest
@testable import CVPDFExporter

final class CVDocumentTests: XCTestCase {

    // MARK: - PersonalInfo Tests

    func testPersonalInfoInitialization() {
        let info = PersonalInfo(
            name: "John Doe",
            email: "john@example.com",
            phone: "+1234567890",
            location: "New York",
            website: "https://johndoe.com",
            summary: "Test summary"
        )

        XCTAssertEqual(info.name, "John Doe")
        XCTAssertEqual(info.email, "john@example.com")
        XCTAssertEqual(info.phone, "+1234567890")
        XCTAssertEqual(info.location, "New York")
        XCTAssertEqual(info.website, "https://johndoe.com")
        XCTAssertEqual(info.summary, "Test summary")
    }

    func testPersonalInfoWithOptionalFields() {
        let info = PersonalInfo(
            name: "Jane Doe",
            email: "jane@example.com"
        )

        XCTAssertEqual(info.name, "Jane Doe")
        XCTAssertEqual(info.email, "jane@example.com")
        XCTAssertNil(info.phone)
        XCTAssertNil(info.location)
        XCTAssertNil(info.website)
        XCTAssertNil(info.summary)
    }

    // MARK: - CVItem Tests

    func testCVItemInitialization() {
        let item = CVItem(
            title: "Software Engineer",
            subtitle: "Tech Corp",
            description: "Developed iOS apps",
            startDate: "Jan 2020",
            endDate: "Dec 2023",
            location: "San Francisco",
            tags: ["Swift", "iOS"]
        )

        XCTAssertEqual(item.title, "Software Engineer")
        XCTAssertEqual(item.subtitle, "Tech Corp")
        XCTAssertEqual(item.description, "Developed iOS apps")
        XCTAssertEqual(item.startDate, "Jan 2020")
        XCTAssertEqual(item.endDate, "Dec 2023")
        XCTAssertEqual(item.location, "San Francisco")
        XCTAssertEqual(item.tags, ["Swift", "iOS"])
    }

    func testCVItemWithMinimalFields() {
        let item = CVItem(title: "Skill Category")

        XCTAssertEqual(item.title, "Skill Category")
        XCTAssertNil(item.subtitle)
        XCTAssertNil(item.description)
        XCTAssertNil(item.startDate)
        XCTAssertNil(item.endDate)
        XCTAssertNil(item.location)
        XCTAssertTrue(item.tags.isEmpty)
    }

    // MARK: - CVSection Tests

    func testCVSectionInitialization() {
        let items = [
            CVItem(title: "Item 1"),
            CVItem(title: "Item 2")
        ]

        let section = CVSection(
            id: "work",
            type: .work,
            title: "Work Experience",
            items: items,
            order: 1
        )

        XCTAssertEqual(section.id, "work")
        XCTAssertEqual(section.type, .work)
        XCTAssertEqual(section.title, "Work Experience")
        XCTAssertEqual(section.items.count, 2)
        XCTAssertEqual(section.items[0].title, "Item 1")
        XCTAssertEqual(section.order, 1)
    }

    func testSectionTypeValues() {
        XCTAssertEqual(SectionType.work.rawValue, "work")
        XCTAssertEqual(SectionType.education.rawValue, "education")
        XCTAssertEqual(SectionType.skills.rawValue, "skills")
        XCTAssertEqual(SectionType.projects.rawValue, "projects")
        XCTAssertEqual(SectionType.certifications.rawValue, "certifications")
        XCTAssertEqual(SectionType.languages.rawValue, "languages")
        XCTAssertEqual(SectionType.custom.rawValue, "custom")
    }

    // MARK: - CVDocument Tests

    func testCVDocumentInitialization() {
        let personalInfo = PersonalInfo(
            name: "Test User",
            email: "test@example.com"
        )

        let section = CVSection(
            id: "skills",
            type: .skills,
            title: "Skills",
            items: [CVItem(title: "Swift")],
            order: 1
        )

        let metadata = DocumentMetadata(
            version: "2.0",
            createdAt: Date(),
            updatedAt: Date()
        )

        let document = CVDocument(
            personalInfo: personalInfo,
            sections: [section],
            metadata: metadata
        )

        XCTAssertEqual(document.personalInfo.name, "Test User")
        XCTAssertEqual(document.sections.count, 1)
        XCTAssertEqual(document.sections[0].type, .skills)
        XCTAssertEqual(document.metadata.version, "2.0")
    }

    func testCVDocumentWithMultipleSections() {
        let personalInfo = PersonalInfo(
            name: "Multi Section",
            email: "multi@example.com"
        )

        let workSection = CVSection(
            id: "work",
            type: .work,
            title: "Experience",
            items: [],
            order: 1
        )

        let eduSection = CVSection(
            id: "edu",
            type: .education,
            title: "Education",
            items: [],
            order: 2
        )

        let document = CVDocument(
            personalInfo: personalInfo,
            sections: [workSection, eduSection],
            metadata: DocumentMetadata()
        )

        XCTAssertEqual(document.sections.count, 2)
        XCTAssertEqual(document.sections[0].order, 1)
        XCTAssertEqual(document.sections[1].order, 2)
    }

    // MARK: - DocumentMetadata Tests

    func testDocumentMetadataDefaults() {
        let metadata = DocumentMetadata()

        XCTAssertNotNil(metadata.createdAt)
        XCTAssertNotNil(metadata.updatedAt)
        XCTAssertEqual(metadata.version, "1.0")
    }

    func testDocumentMetadataCustomValues() {
        let created = Date(timeIntervalSince1970: 1000000)
        let updated = Date(timeIntervalSince1970: 2000000)

        let metadata = DocumentMetadata(
            version: "2.5",
            createdAt: created,
            updatedAt: updated
        )

        XCTAssertEqual(metadata.createdAt, created)
        XCTAssertEqual(metadata.updatedAt, updated)
        XCTAssertEqual(metadata.version, "2.5")
    }
}