import XCTest
@testable import CVPDFExporter

// Platform-agnostic tests for PDFExportEngine
final class PDFExportEngineCoreTests: XCTestCase {

    // MARK: - Factory Tests

    func testPDFExportEngineFactoryCreatesInstance() {
        #if canImport(UIKit)
        let engine = PDFExportEngineFactory.create()
        XCTAssertNotNil(engine)
        XCTAssertTrue(engine is PDFExportEngineImpl)
        #else
        // On macOS, we should still be able to create an engine
        // even if it's a stub or different implementation
        XCTSkip("PDF engine tests require platform-specific implementation")
        #endif
    }

    // MARK: - Model Tests

    func testCreateSampleDocument() {
        let personalInfo = PersonalInfo(
            name: "Test User",
            email: "test@example.com",
            phone: "+1234567890",
            location: "Test City",
            website: "https://example.com",
            summary: "Test summary for PDF export"
        )

        let workSection = CVSection(
            id: "work",
            type: .work,
            title: "Experience",
            items: [
                CVItem(
                    title: "Senior Developer",
                    subtitle: "Tech Company",
                    description: "Developed applications",
                    startDate: "2020",
                    endDate: "Present"
                )
            ],
            order: 1
        )

        let document = CVDocument(
            personalInfo: personalInfo,
            sections: [workSection],
            metadata: DocumentMetadata()
        )

        XCTAssertEqual(document.personalInfo.name, "Test User")
        XCTAssertEqual(document.sections.count, 1)
        XCTAssertEqual(document.sections[0].type, .work)
    }

    func testComplexDocumentCreation() {
        let personalInfo = PersonalInfo(
            name: "John Smith",
            email: "john.smith@example.com",
            phone: "+1 (555) 123-4567",
            location: "San Francisco, CA",
            website: "https://johnsmith.dev",
            summary: "Senior Software Engineer with 10+ years of experience"
        )

        let workSection = CVSection(
            id: "work",
            type: .work,
            title: "Professional Experience",
            items: [
                CVItem(
                    title: "Senior iOS Engineer",
                    subtitle: "Tech Innovations Inc.",
                    description: "Led iOS development team",
                    startDate: "Jan 2021",
                    endDate: "Present",
                    location: "San Francisco, CA",
                    tags: ["Swift", "SwiftUI", "Team Lead"]
                )
            ],
            order: 1
        )

        let educationSection = CVSection(
            id: "education",
            type: .education,
            title: "Education",
            items: [
                CVItem(
                    title: "Master of Computer Science",
                    subtitle: "Stanford University",
                    description: "Specialized in Mobile Computing",
                    startDate: "2013",
                    endDate: "2015",
                    location: "Stanford, CA"
                )
            ],
            order: 2
        )

        let document = CVDocument(
            personalInfo: personalInfo,
            sections: [workSection, educationSection],
            metadata: DocumentMetadata(version: "2.0")
        )

        XCTAssertEqual(document.personalInfo.name, "John Smith")
        XCTAssertEqual(document.sections.count, 2)
        XCTAssertEqual(document.metadata.version, "2.0")
    }

    // MARK: - Export Options Tests

    func testExportOptionsValidation() {
        let options = ExportOptions.default

        XCTAssertEqual(options.pageSize.width, PageSize.a4.width)
        XCTAssertEqual(options.pageSize.height, PageSize.a4.height)
        XCTAssertEqual(options.margins.top, 72)

        let customOptions = ExportOptions(
            pageSize: .letter,
            margins: .uniform(36)
        )

        XCTAssertEqual(customOptions.pageSize.width, PageSize.letter.width)
        XCTAssertEqual(customOptions.margins.top, 36)
    }

    // MARK: - Adapter Tests

    func testPrestoCVCoreAdapterCreatesValidDocument() {
        let adapter = PrestoCVCoreAdapter()
        let document = adapter.convertToCV(from: nil)

        XCTAssertFalse(document.personalInfo.name.isEmpty)
        XCTAssertFalse(document.personalInfo.email.isEmpty)
        XCTAssertFalse(document.sections.isEmpty)

        // Verify sections are properly structured
        for section in document.sections {
            XCTAssertFalse(section.title.isEmpty)
            XCTAssertTrue(section.order > 0)
        }
    }
}