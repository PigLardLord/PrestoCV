import Foundation
@testable import PrestoCV
@testable import PrestoCVCore
@testable import CVPDFExporter

/// The bundled templates, installed the way the app does at launch but into a temporary folder,
/// so that no test touches the real Application Support.
struct ExportTestEnvironment {
    let root: URL
    let repository: BundledTemplateRepository

    /// Where exported PDFs are written
    var exportsDirectory: URL { root.appendingPathComponent("Exports", isDirectory: true) }

    static func make() async throws -> ExportTestEnvironment {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExportTestEnvironment_\(UUID().uuidString)", isDirectory: true)
        let registryDirectory = root.appendingPathComponent("Registry", isDirectory: true)
        try FileManager.default.createDirectory(at: registryDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("Exports", isDirectory: true),
            withIntermediateDirectories: true
        )

        let registryManager = TemplateRegistryManager(storageDirectory: registryDirectory)
        let fileRepository = FileTemplateRepository(
            templatesDirectory: root.appendingPathComponent("Templates", isDirectory: true),
            registryManager: registryManager
        )
        try await TemplateBootstrapService(
            installUseCase: InstallTemplateUseCase(repository: fileRepository),
            registryManager: registryManager
        ).syncBundledTemplates()

        return ExportTestEnvironment(root: root, repository: BundledTemplateRepository(fileRepository: fileRepository))
    }

    /// The real renderer, as the tests use it: a page that is not ready in time fails the render instead of being drawn
    /// as it is, and a newly created simulator has all the time it needs to start its web content.
    @MainActor
    static func makeRenderer() -> EnhancedWKWebViewPDFRenderer {
        EnhancedWKWebViewPDFRenderer(pageLoadTimeout: patience, readinessTimeout: patience, onReadinessTimeout: .fail)
    }

    func makeService() -> CVExportService {
        CVExportService(
            container: PDFExportDependencyContainer(templateRepository: repository, makeRenderer: { Self.makeRenderer() }),
            fileNames: ExportFileName(titlePattern: { _ in "%@ – CV" }),
            temporaryDirectory: exportsDirectory
        )
    }

    /// The options of the export sheet for a design
    @MainActor
    func exportOptions(for design: String) -> ExportOptions {
        let viewModel = CVExportSheetViewModel(
            cv: CVModel(),
            exportService: makeService(),
            preferencesStore: InMemoryExportPreferencesStore(),
            documentLanguageSink: { _ in },
            exportPolicy: .standard,
            documentLanguageDetector: englishDocumentLanguageDetector,
            appLocale: Locale(identifier: "en"),
            previewDebounce: .zero
        )
        viewModel.selectedTemplateId = design
        return viewModel.currentExportOptions()
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: root)
    }
}
