import Foundation
import Combine

/// View model for PDF export functionality
/// Manages state and coordination between UI and domain layer
@MainActor
public final class ExportViewModel: ObservableObject {

    // MARK: - Properties

    private let container: PDFExportDependencyContainer
    private let exportUseCase: PDFExportUseCase
    private let templateSelectionUseCase: TemplateSelectionUseCase
    private let templatePreviewUseCase: TemplatePreviewUseCase
    private let tailoringUseCase: CVTailoringUseCase

    // MARK: - Observable State

    @Published public private(set) var templates: [Template] = []
    @Published public var selectedTemplateId: String = "professional"
    @Published public var customization = CustomizationOptions()
    @Published public private(set) var isExporting = false
    @Published public private(set) var exportProgress: Double = 0.0
    @Published public var showError = false
    @Published public var errorMessage: String?
    @Published public var showPreview = false
    @Published public private(set) var previewHTML: String = ""
    @Published public private(set) var tailoringSuggestions: CVTailoringResult?

    // MARK: - Initialization

    public init(container: PDFExportDependencyContainer) {
        self.container = container
        self.exportUseCase = container.makeExportUseCase()
        self.templateSelectionUseCase = container.makeTemplateSelectionUseCase()
        self.templatePreviewUseCase = container.makeTemplatePreviewUseCase()
        self.tailoringUseCase = container.makeCVTailoringUseCase()

        // Load templates on init
        Task {
            await loadTemplates()
        }
    }

    // MARK: - Public Methods

    /// Loads available templates
    public func loadTemplates() async {
        do {
            templates = try await templateSelectionUseCase.getAvailableTemplates()
            // Select recommended template if available
            if !templates.isEmpty {
                selectedTemplateId = templates.first?.id ?? "professional"
            }
        } catch {
            handleError(error, message: "Failed to load templates")
        }
    }

    /// Updates customization options
    public func updateCustomization(
        colorPalette: ColorPalette? = nil,
        fontScheme: FontScheme? = nil
    ) {
        if let colorPalette, let fontScheme {
            customization = CustomizationOptions(
                colorPalette: colorPalette,
                fontScheme: fontScheme
            )
        } else if let colorPalette {
            customization = CustomizationOptions(
                colorPalette: colorPalette,
                fontScheme: customization.fontScheme
            )
        } else if let fontScheme {
            customization = CustomizationOptions(
                colorPalette: customization.colorPalette,
                fontScheme: fontScheme
            )
        }
    }

    /// Selects a template
    public func selectTemplate(_ templateId: String) {
        selectedTemplateId = templateId
    }

    /// Exports CV to PDF
    @discardableResult
    public func exportToPDF(document: CVDocument) async throws -> Data {
        guard validateDocument(document) else {
            throw PDFExportError.renderingFailed("Document validation failed")
        }

        isExporting = true
        exportProgress = 0.0
        defer { isExporting = false }

        do {
            // Get selected template
            guard let template = templates.first(where: { $0.id == selectedTemplateId }) else {
                throw PDFExportError.templateError("Template not found: \(selectedTemplateId)")
            }

            // Create export options
            let options = ExportOptions(
                templateId: selectedTemplateId,
                customization: customization
            )

            // Export to PDF
            exportProgress = 0.5
            let result = try await exportUseCase.execute(
                document: document,
                template: template,
                options: options
            )

            exportProgress = 1.0
            return result.pdfData

        }
    }

    /// Generates preview HTML for current settings
    public func generatePreview(document: CVDocument) async throws {
        do {
            let preview = try await templatePreviewUseCase.generatePreview(
                templateId: selectedTemplateId,
                cv: document,
                customization: customization
            )

            previewHTML = preview.html
            showPreview = true
        } catch {
            handleError(error, message: "Preview generation failed")
            throw error
        }
    }

    /// Tailors CV for a job description
    public func tailorForJob(
        document: CVDocument,
        jobDescription: String
    ) async throws -> CVDocument? {
        guard tailoringUseCase.isAvailable else {
            return nil
        }

        do {
            let result = try await tailoringUseCase.tailorForJob(
                cv: document,
                jobDescription: jobDescription
            )

            tailoringSuggestions = result.suggestions
            return result.tailoredCV
        } catch {
            handleError(error, message: "Tailoring failed")
            throw error
        }
    }

    /// Validates document for export
    public func validateDocument(_ document: CVDocument) -> Bool {
        // Check required fields
        guard !document.personalInfo.name.isEmpty,
              !document.personalInfo.email.isEmpty else {
            return false
        }

        // Check for at least some content
        guard !document.sections.isEmpty ||
              document.personalInfo.summary != nil else {
            return false
        }

        return true
    }

    /// Gets template recommendations for a CV
    public func getTemplateRecommendations(for document: CVDocument) async -> [Template] {
        do {
            // Get the recommended template
            let recommendedTemplate = try await templateSelectionUseCase.recommendTemplate(for: document)

            // Return recommended template first, then others
            var recommendations = [recommendedTemplate]
            recommendations.append(contentsOf: templates.filter { $0.id != recommendedTemplate.id })
            return recommendations
        } catch {
            // Return default order on error
            return templates
        }
    }

    /// Clears any error state
    public func clearError() {
        showError = false
        errorMessage = nil
    }

    /// Dismisses preview
    public func dismissPreview() {
        showPreview = false
        previewHTML = ""
    }

    // MARK: - Private Methods

    private func handleError(_ error: Error, message: String) {
        errorMessage = "\(message): \(error.localizedDescription)"
        showError = true
    }
}