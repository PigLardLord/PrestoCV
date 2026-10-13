import Testing
import Foundation
@testable import CVPDFExporter

@Suite("ExportViewModel Tests")
struct ExportViewModelTests {

    @Test("Should initialize with default template")
    @MainActor
    func test_init_selectsDefaultTemplate() async throws {
        // Given
        let storage = try await TemplateTestStorage.withBundledTemplates()
        defer { storage.cleanUp() }
        let container = MockDependencyContainer(templateRepository: storage.repository)
        let viewModel = ExportViewModel(container: container)

        // Then
        #expect(viewModel.selectedTemplateId == "professional")
        #expect(!viewModel.isExporting)
        #expect(!viewModel.showError)
        #expect(!viewModel.showPreview)
    }

    @Test("Should load the bundled templates")
    @MainActor
    func test_init_loadsTemplates() async throws {
        // Given
        let storage = try await TemplateTestStorage.withBundledTemplates()
        defer { storage.cleanUp() }
        let container = MockDependencyContainer(templateRepository: storage.repository)
        let viewModel = ExportViewModel(container: container)

        // When
        await viewModel.loadTemplates()

        // Then
        #expect(viewModel.templates.count > 0)
        #expect(viewModel.templates.contains { $0.id == "professional" })
        #expect(viewModel.templates.contains { $0.id == "modern" })
    }

    @Test("Should update customization options")
    @MainActor
    func test_updateCustomization_updatesOptions() async throws {
        // Given
        let storage = try await TemplateTestStorage.withBundledTemplates()
        defer { storage.cleanUp() }
        let container = MockDependencyContainer(templateRepository: storage.repository)
        let viewModel = ExportViewModel(container: container)

        // When
        viewModel.updateCustomization(
            colorPalette: .modern,
            fontScheme: .serif
        )

        // Then
        #expect(viewModel.customization.colorPalette == .modern)
        #expect(viewModel.customization.fontScheme == .serif)
    }

    @Test("Should handle template selection")
    @MainActor
    func test_selectTemplate_updatesSelection() async throws {
        // Given
        let storage = try await TemplateTestStorage.withBundledTemplates()
        defer { storage.cleanUp() }
        let container = MockDependencyContainer(templateRepository: storage.repository)
        let viewModel = ExportViewModel(container: container)

        // When
        viewModel.selectTemplate("modern")

        // Then
        #expect(viewModel.selectedTemplateId == "modern")
    }

    @Test("Should export CV to PDF")
    @MainActor
    func test_exportToPDF_generatesData() async throws {
        // Given
        let storage = try await TemplateTestStorage.withBundledTemplates()
        defer { storage.cleanUp() }
        let container = MockDependencyContainer(templateRepository: storage.repository)
        let viewModel = ExportViewModel(container: container)
        let document = createSampleCV()

        // Wait for templates to load
        await viewModel.loadTemplates()

        // When
        let pdfData = try await viewModel.exportToPDF(document: document)

        // Then
        #expect(!pdfData.isEmpty)
        #expect(!viewModel.isExporting)
    }

    @Test("Should handle export errors")
    @MainActor
    func test_exportToPDF_handlesError() async throws {
        // Given
        let storage = try await TemplateTestStorage.withBundledTemplates()
        defer { storage.cleanUp() }
        let container = MockDependencyContainer(templateRepository: storage.repository)
        let viewModel = ExportViewModel(container: container)
        let invalidDocument = CVDocument(
            personalInfo: PersonalInfo(name: "", email: "")
        )

        // Wait for templates to load
        await viewModel.loadTemplates()

        // When/Then
        do {
            _ = try await viewModel.exportToPDF(document: invalidDocument)
            Issue.record("Expected error but got success")
        } catch {
            // Error is expected for invalid document
            #expect(error is PDFExportError)
        }
    }

    @Test("Should generate template preview")
    @MainActor
    func test_generatePreview_createsHTMLPreview() async throws {
        // Given
        let storage = try await TemplateTestStorage.withBundledTemplates()
        defer { storage.cleanUp() }
        let container = MockDependencyContainer(templateRepository: storage.repository)
        let viewModel = ExportViewModel(container: container)
        let document = createSampleCV()

        // When
        viewModel.selectedTemplateId = "modern"
        try await viewModel.generatePreview(document: document)

        // Then
        #expect(!viewModel.previewHTML.isEmpty)
        #expect(viewModel.showPreview)
    }

    @Test("Should handle AI tailoring when available")
    @MainActor
    func test_tailorForJob_appliesSuggestions() async throws {
        // Given
        let storage = try await TemplateTestStorage.withBundledTemplates()
        defer { storage.cleanUp() }
        let container = MockDependencyContainer(templateRepository: storage.repository)
        let viewModel = ExportViewModel(container: container)
        let document = createSampleCV()
        let jobDescription = "Senior iOS Developer with SwiftUI experience"

        // When
        let tailoredDoc = try await viewModel.tailorForJob(
            document: document,
            jobDescription: jobDescription
        )

        // Then
        #expect(tailoredDoc != nil)
        #expect(viewModel.tailoringSuggestions != nil)
    }

    @Test("Should track export state correctly")
    @MainActor
    func test_exportState_updatesCorrectly() async throws {
        // Given
        let storage = try await TemplateTestStorage.withBundledTemplates()
        defer { storage.cleanUp() }
        let container = MockDependencyContainer(templateRepository: storage.repository)
        let viewModel = ExportViewModel(container: container)
        let document = createSampleCV()

        // Wait for templates to load
        await viewModel.loadTemplates()

        // Then - Initial state
        #expect(!viewModel.isExporting)

        // When - Export
        _ = try await viewModel.exportToPDF(document: document)

        // Then - After export
        #expect(!viewModel.isExporting)
    }

    @Test("Should validate document before export")
    @MainActor
    func test_validateDocument_checksRequirements() async throws {
        // Given
        let storage = try await TemplateTestStorage.withBundledTemplates()
        defer { storage.cleanUp() }
        let container = MockDependencyContainer(templateRepository: storage.repository)
        let viewModel = ExportViewModel(container: container)

        // When - Valid document
        let validDoc = createSampleCV()
        let isValid = viewModel.validateDocument(validDoc)

        // Then
        #expect(isValid)

        // When - Invalid document
        let invalidDoc = CVDocument(
            personalInfo: PersonalInfo(name: "", email: "")
        )
        let isInvalid = viewModel.validateDocument(invalidDoc)

        // Then
        #expect(!isInvalid)
    }

    // MARK: - Helpers

    private func createSampleCV() -> CVDocument {
        CVDocument(
            personalInfo: PersonalInfo(
                name: "John Doe",
                email: "john@example.com",
                phone: "+1 234 567 8900",
                summary: "Experienced iOS Developer"
            ),
            sections: [
                CVSection(
                    type: .work,
                    title: "Experience",
                    items: [
                        CVItem(
                            title: "Senior iOS Developer",
                            subtitle: "Tech Corp",
                            description: "Led development team"
                        )
                    ]
                ),
                CVSection(
                    type: .skills,
                    title: "Skills",
                    items: [
                        CVItem(
                            title: "Programming",
                            tags: ["Swift", "SwiftUI", "UIKit"]
                        )
                    ]
                )
            ]
        )
    }
}
