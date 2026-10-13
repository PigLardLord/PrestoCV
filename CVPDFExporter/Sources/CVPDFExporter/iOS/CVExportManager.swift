#if canImport(UIKit) && canImport(QuickLook)
import UIKit
import QuickLook
import UniformTypeIdentifiers
import os.log

/// Manages CV export and preview for iOS apps
/// Provides integration with QuickLook for PDF preview
@MainActor
public final class CVExportManager: NSObject {

    // MARK: - Properties

    private let logger = Logger(subsystem: "CVPDFExporter", category: "ExportManager")
    private let exportUseCase: PDFExportUseCase
    private let templateRepository: BundledTemplateRepository
    private let adapter: PrestoCVCoreAdapter
    private var exportedFileURL: URL?
    private weak var presentingViewController: UIViewController?

    // MARK: - Initialization

    public override init() {
        // Create renderer
        let renderer = EnhancedWKWebViewPDFRenderer()

        // Create repository (in production, could use Core Data or similar)
        let repository = InMemoryExportRepository()

        // Create template engine
        let templateEngine = MustacheTemplateEngine()

        // Initialize use case with dependencies
        self.exportUseCase = PDFExportUseCase(
            renderer: renderer,
            repository: repository,
            templateEngine: templateEngine,
            enableCaching: true
        )

        self.templateRepository = BundledTemplateRepository()
        self.adapter = PrestoCVCoreAdapter()

        super.init()
    }

    // MARK: - Public Methods

    /// Exports CV to PDF and presents it in QuickLook
    /// - Parameters:
    ///   - cvData: The CV data from PrestoCVCore
    ///   - templateId: The template to use (default: "modern")
    ///   - customization: Customization options
    ///   - presentingViewController: The view controller to present QuickLook from
    public func exportAndPreview(
        cvData: Any,
        templateId: String = "modern",
        customization: CustomizationOptions = CustomizationOptions(),
        from presentingViewController: UIViewController
    ) async throws {
        logger.info("Starting CV export with template: \(templateId)")

        // Store presenting view controller
        self.presentingViewController = presentingViewController

        // Show loading indicator
        let loadingAlert = showLoadingAlert(on: presentingViewController)

        do {
            // Convert CV data
            let cvDocument = adapter.convertToCV(from: cvData)
            logger.debug("CV document created for: \(cvDocument.personalInfo.name)")

            // Load template
            let template = try await templateRepository.loadTemplate(id: templateId)
            logger.debug("Template loaded: \(template.name)")

            // Configure export options with tight margins to match reference PDF
            // 0.5in = 36pt, 0.6in = 43.2pt
            let options = ExportOptions(
                pageSize: .a4,
                margins: EdgeInsets(top: 43, left: 36, bottom: 43, right: 36),
                maxPages: 10
            )

            // Execute export
            let result = try await exportUseCase.execute(
                document: cvDocument,
                template: template,
                options: options
            )

            logger.info("PDF generated: \(result.fileSize) bytes, \(result.pageCount) pages")

            // Save to temporary file
            let fileName = "\(cvDocument.personalInfo.name.replacingOccurrences(of: " ", with: "_"))_CV.pdf"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try result.pdfData.write(to: tempURL)
            self.exportedFileURL = tempURL

            // Dismiss loading
            await dismissAlert(loadingAlert)

            // Present QuickLook
            presentQuickLook()

        } catch {
            logger.error("Export failed: \(error.localizedDescription)")
            await dismissAlert(loadingAlert)
            showErrorAlert(error: error, on: presentingViewController)
            throw error
        }
    }

    /// Exports CV to PDF and returns the data
    /// - Parameters:
    ///   - cvData: The CV data from PrestoCVCore
    ///   - templateId: The template to use
    ///   - customization: Customization options
    /// - Returns: PDF data
    public func exportToPDF(
        cvData: Any,
        templateId: String = "modern",
        customization: CustomizationOptions = CustomizationOptions()
    ) async throws -> Data {
        // Convert CV data
        let cvDocument = adapter.convertToCV(from: cvData)

        // Load template
        let template = try await templateRepository.loadTemplate(id: templateId)

        // Configure export options with tight margins to match reference PDF
        // 0.5in = 36pt, 0.6in = 43.2pt
        let options = ExportOptions(
            pageSize: .a4,
            margins: EdgeInsets(top: 43, left: 36, bottom: 43, right: 36),
            maxPages: 10
        )

        // Execute export
        let result = try await exportUseCase.execute(
            document: cvDocument,
            template: template,
            options: options
        )

        return result.pdfData
    }

    /// Gets available templates
    public func getAvailableTemplates() async throws -> [Template] {
        return try await templateRepository.getTemplates()
    }

    // MARK: - Private Methods

    private func showLoadingAlert(on viewController: UIViewController) -> UIAlertController {
        let alert = UIAlertController(
            title: "Exporting CV",
            message: "Generating PDF...\n\n\n",
            preferredStyle: .alert
        )

        // Add activity indicator
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.startAnimating()
        alert.view.addSubview(indicator)

        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
            indicator.bottomAnchor.constraint(equalTo: alert.view.bottomAnchor, constant: -20)
        ])

        viewController.present(alert, animated: true)
        return alert
    }

    private func dismissAlert(_ alert: UIAlertController) async {
        await withCheckedContinuation { continuation in
            alert.dismiss(animated: true) {
                continuation.resume()
            }
        }
    }

    private func showErrorAlert(error: Error, on viewController: UIViewController) {
        let alert = UIAlertController(
            title: "Export Failed",
            message: error.localizedDescription,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "OK", style: .default))
        viewController.present(alert, animated: true)
    }

    private func presentQuickLook() {
        guard exportedFileURL != nil,
              let viewController = presentingViewController else {
            logger.error("Cannot present QuickLook: missing URL or view controller")
            return
        }

        let previewController = QLPreviewController()
        previewController.dataSource = self
        previewController.delegate = self

        viewController.present(previewController, animated: true)
    }

    private func handlePreviewDismissal() {
        logger.debug("QuickLook dismissed")

        guard let url = exportedFileURL else { return }
        exportedFileURL = nil

        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            try? FileManager.default.removeItem(at: url)
            logger.debug("Temporary PDF file cleaned up")
        }
    }
}

// MARK: - QLPreviewControllerDataSource

extension CVExportManager: QLPreviewControllerDataSource {

    public func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return exportedFileURL != nil ? 1 : 0
    }

    public func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return exportedFileURL! as QLPreviewItem
    }
}

// MARK: - QLPreviewControllerDelegate

extension CVExportManager: QLPreviewControllerDelegate {

    nonisolated public func previewControllerDidDismiss(_ controller: QLPreviewController) {
        Task { @MainActor [weak self] in
            self?.handlePreviewDismissal()
        }
    }
}

// MARK: - In-Memory Export Repository

/// Simple in-memory implementation of ExportRepositoryProtocol
private actor InMemoryExportRepository: ExportRepositoryProtocol {
    private var history: [ExportHistoryEntry] = []
    private var cache: [String: (data: Data, expiry: Date)] = [:]

    func saveExportHistory(_ entry: ExportHistoryEntry) async throws {
        history.append(entry)
        // Keep only last 100 entries
        if history.count > 100 {
            history.removeFirst()
        }
    }

    func getExportHistory(limit: Int) async throws -> [ExportHistoryEntry] {
        return Array(history.suffix(limit))
    }

    func cachePDF(data: Data, key: String, ttl: TimeInterval) async throws {
        let expiry = Date().addingTimeInterval(ttl)
        cache[key] = (data, expiry)
    }

    func getCachedPDF(key: String) async -> Data? {
        if let cached = cache[key] {
            if cached.expiry > Date() {
                return cached.data
            } else {
                cache.removeValue(forKey: key)
            }
        }
        return nil
    }

    func clearExpiredCache() async throws {
        let now = Date()
        cache = cache.filter { $0.value.expiry > now }
    }

    func clearAll() async throws {
        cache.removeAll()
        history.removeAll()
    }
}

#endif
