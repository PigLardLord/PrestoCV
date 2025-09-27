import Testing
import Foundation
@testable import PrestoCV

// Mock renderer for testing
final class MockPDFRenderer: HTMLToPDFRenderer, @unchecked Sendable {
    var renderCallCount = 0
    var lastHTMLInput: String?
    var lastOptionsInput: ExportOptions?
    var shouldThrow = false

    func renderToPDF(html: String, options: ExportOptions) async throws -> Data {
        renderCallCount += 1
        lastHTMLInput = html
        lastOptionsInput = options

        if shouldThrow {
            throw PDFExportError.renderingFailed("Mock error")
        }

        // Return minimal valid PDF
        return Data([0x25, 0x50, 0x44, 0x46]) // %PDF header
    }
}

// MARK: - PDF Export Engine Core Tests

@Suite("PDF Export Engine Core")
struct PDFExportEngineCoreTests {

    // MARK: - Factory Tests

    @Test("PDF export engine factory creates instance")
    func pdfExportEngineFactoryCreatesInstance() {
        // Test with dependency injection - platform agnostic
        let mockRenderer = MockPDFRenderer()
        let engine = PDFExportEngineFactory.create(with: mockRenderer)

        #expect(engine != nil)
        #expect(engine is PDFExportEngineImpl)
    }

    @Test("PDF export engine with mock renderer")
    func pdfExportEngineWithMockRenderer() async throws {
        // Given
        let mockRenderer = MockPDFRenderer()
        let engine = PDFExportEngineFactory.create(with: mockRenderer)
        let document = createSampleDocument()
        let options = ExportOptions.default

        // When
        let pdfData = try await engine.exportToPDF(document: document, options: options)

        // Then
        #expect(!pdfData.isEmpty)
        #expect(mockRenderer.renderCallCount == 1)
        #expect(mockRenderer.lastHTMLInput != nil)
        #expect(mockRenderer.lastHTMLInput?.contains("Test User") ?? false)
    }

    // MARK: - Helper Methods

    private func createSampleDocument() -> CVDocument {
        let personalInfo = PersonalInfo(
            name: "Test User",
            email: "test@example.com"
        )

        let workSection = CVSection(
            id: "work",
            type: .work,
            title: "Experience",
            items: [],
            order: 1
        )

        return CVDocument(
            personalInfo: personalInfo,
            sections: [workSection],
            metadata: DocumentMetadata()
        )
    }

    // MARK: - Model Tests

    @Test("Create sample document")
    func createSampleDocumentTest() {
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

        #expect(document.personalInfo.name == "Test User")
        #expect(document.sections.count == 1)
        #expect(document.sections[0].type == .work)
    }

    @Test("Complex document creation")
    func complexDocumentCreation() {
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

        #expect(document.personalInfo.name == "John Smith")
        #expect(document.sections.count == 2)
        #expect(document.metadata.version == "2.0")
    }

    // MARK: - Export Options Tests

    @Test("Export options validation")
    func exportOptionsValidation() {
        let options = ExportOptions.default

        #expect(options.pageSize.width == PageSize.a4.width)
        #expect(options.pageSize.height == PageSize.a4.height)
        #expect(options.margins.top == 72)

        let customOptions = ExportOptions(
            pageSize: .letter,
            margins: .uniform(36)
        )

        #expect(customOptions.pageSize.width == PageSize.letter.width)
        #expect(customOptions.margins.top == 36)
    }

    // MARK: - Adapter Tests

    @Test("PrestoCVCore adapter creates valid document")
    func prestoCVCoreAdapterCreatesValidDocument() {
        let adapter = PrestoCVCoreAdapter()
        let document = adapter.convertToCV(from: nil)

        #expect(!document.personalInfo.name.isEmpty)
        #expect(!document.personalInfo.email.isEmpty)
        #expect(!document.sections.isEmpty)

        // Verify sections are properly structured
        for section in document.sections {
            #expect(!section.title.isEmpty)
            #expect(section.order > 0)
        }
    }
}