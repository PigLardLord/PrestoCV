import Foundation
import SwiftUI
import CVPDFExporter

@MainActor
final class TemplateViewerViewModel: ObservableObject {
    @Published var templates: [Template] = []
    @Published var selectedTemplateId: String?
    @Published var selectedColorPalette: ColorPalette = .professional
    @Published var selectedFontScheme: FontScheme = .classic
    @Published var previewHTML: String?
    @Published var isLoading = false
    @Published var showingExportSuccess = false
    @Published var exportedPath: String?

    private let repository = BundledTemplateRepository()
    private let engine = MustacheTemplateEngine()
    private let previewUseCase: TemplatePreviewUseCase

    init() {
        self.previewUseCase = TemplatePreviewUseCase(
            templateEngine: engine,
            repository: repository
        )
    }

    func loadTemplates() async {
        do {
            let availableTemplates = try await repository.getAllTemplates()
            templates = availableTemplates
            if selectedTemplateId == nil {
                selectedTemplateId = availableTemplates.first?.id
            }
            await refreshPreview()
        } catch {
            print("Error loading templates: \(error)")
        }
    }

    func refreshPreview() async {
        guard let templateId = selectedTemplateId else {
            previewHTML = nil
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let customization = CustomizationOptions(
                colorPalette: selectedColorPalette,
                fontScheme: selectedFontScheme
            )

            let preview = try await previewUseCase.generatePreview(
                templateId: templateId,
                cv: SampleCVData.complete,
                customization: customization,
                pageSize: .a4
            )

            previewHTML = preview.html
        } catch {
            print("Error generating preview: \(error)")
            previewHTML = nil
        }
    }

    func exportHTML() {
        guard let html = previewHTML else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.html]
        panel.nameFieldStringValue = "cv-preview.html"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try html.write(to: url, atomically: true, encoding: .utf8)
                    self.exportedPath = url.path
                    self.showingExportSuccess = true
                } catch {
                    print("Error exporting HTML: \(error)")
                }
            }
        }
    }
}
