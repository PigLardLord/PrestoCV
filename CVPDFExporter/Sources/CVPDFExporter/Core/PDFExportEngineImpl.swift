import Foundation

// MARK: - PDF Export Engine Implementation

/// Concrete implementation of PDFExportEngine
/// Sprint 1: Enhanced with Template System support
/// Platform-agnostic with dependency injection for renderer
public final class PDFExportEngineImpl: PDFExportEngine, Sendable {

    private let renderer: HTMLToPDFRenderer
    private let adapter: PrestoCVCoreAdapter
    private let templateRepository: TemplateRepositoryProtocol
    private let templateEngine: TemplateEngine

    /// Initialize with an injected renderer
    /// - Parameters:
    ///   - renderer: Platform-specific PDF renderer implementation
    ///   - templateRepository: Where the templates come from; the installed bundled templates by default
    public init(
        renderer: HTMLToPDFRenderer,
        templateRepository: TemplateRepositoryProtocol = BundledTemplateRepository()
    ) {
        self.renderer = renderer
        self.adapter = PrestoCVCoreAdapter()
        self.templateRepository = templateRepository
        self.templateEngine = MustacheTemplateEngine()
    }

    /// Export CV to PDF using template system
    public func exportToPDF(document: CVDocument, options: ExportOptions) async throws -> Data {
        // Sprint 1: Use template system with Mustache rendering
        // Sprint 2: Apply customization options
        // Default to professional template if not specified
        let templateId = options.templateId ?? "professional"

        do {
            let template = try await templateRepository.loadTemplate(id: templateId)
            let html = try await templateEngine.render(
                template: template,
                data: document,
                customization: options.customization
            )
            return try await renderer.renderToPDF(html: html, options: options)
        } catch let error as TemplateError {
            throw PDFExportError.templateError(error.localizedDescription)
        } catch {
            throw PDFExportError.renderingFailed(error.localizedDescription)
        }
    }

    /// Load the static professional template
    private func loadStaticTemplate() -> String {
        // Sprint 0: Return the professional template HTML as a string
        // In future sprints, this will load from bundle resources

        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>CV</title>
            <style>
                * {
                    margin: 0;
                    padding: 0;
                    box-sizing: border-box;
                }

                :root {
                    --color-primary: #2C3E50;
                    --color-secondary: #34495E;
                    --color-accent: #3498DB;
                    --color-background: #FFFFFF;
                    --color-text: #2C3E50;
                    --color-text-light: #7F8C8D;
                    --font-family: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', Helvetica, Arial, sans-serif;
                    --font-size-base: 11pt;
                    --spacing-md: 15pt;
                    --spacing-lg: 20pt;
                    --spacing-xl: 30pt;
                }

                body {
                    font-family: var(--font-family);
                    font-size: var(--font-size-base);
                    color: var(--color-text);
                    background: var(--color-background);
                    line-height: 1.6;
                    padding: 40pt;
                }

                header {
                    border-bottom: 3pt solid var(--color-primary);
                    padding-bottom: var(--spacing-lg);
                    margin-bottom: var(--spacing-xl);
                }

                h1 {
                    color: var(--color-primary);
                    font-size: 24pt;
                    font-weight: 700;
                    margin-bottom: 5pt;
                }

                .contact-info {
                    color: var(--color-secondary);
                    font-size: 9pt;
                    margin-top: 5pt;
                }

                .summary {
                    margin-bottom: var(--spacing-xl);
                    padding: var(--spacing-md);
                    background-color: #F8F9FA;
                    border-left: 3pt solid var(--color-accent);
                }

                .section {
                    margin-bottom: var(--spacing-xl);
                    page-break-inside: avoid;
                }

                h2 {
                    color: var(--color-primary);
                    font-size: 14pt;
                    font-weight: 600;
                    border-bottom: 1pt solid #E0E0E0;
                    padding-bottom: 5pt;
                    margin-bottom: var(--spacing-md);
                    text-transform: uppercase;
                }

                .item {
                    margin-bottom: var(--spacing-lg);
                    page-break-inside: avoid;
                }

                .item-header {
                    display: flex;
                    justify-content: space-between;
                    margin-bottom: 5pt;
                }

                .item-title {
                    font-weight: 600;
                    color: var(--color-primary);
                }

                .item-subtitle {
                    color: var(--color-accent);
                    font-weight: 500;
                }

                .item-date {
                    color: var(--color-text-light);
                    font-size: 9pt;
                    font-style: italic;
                }

                .item-description {
                    margin-top: 5pt;
                    text-align: justify;
                }

                @media print {
                    body { padding: 0; }
                    .summary {
                        background-color: #F8F9FA !important;
                        -webkit-print-color-adjust: exact;
                        print-color-adjust: exact;
                    }
                }
            </style>
        </head>
        <body>
            <header>
                <h1>John Doe</h1>
                <div class="contact-info">
                    john.doe@example.com | +1 (555) 123-4567 | San Francisco, CA
                </div>
            </header>

            <section class="summary">
                <p>
                    Experienced Software Engineer with 8+ years developing scalable iOS applications.
                    Expertise in Swift, SwiftUI, and system architecture.
                </p>
            </section>

            <section class="section">
                <h2>Work Experience</h2>
                <div class="item">
                    <div class="item-header">
                        <div>
                            <span class="item-title">Senior iOS Developer</span>
                            <span class="item-subtitle">at Tech Corp</span>
                        </div>
                        <span class="item-date">Jan 2020 - Present</span>
                    </div>
                    <div class="item-description">
                        Leading iOS development team in building flagship applications.
                    </div>
                </div>
            </section>

            <section class="section">
                <h2>Education</h2>
                <div class="item">
                    <div class="item-header">
                        <div>
                            <span class="item-title">B.S. Computer Science</span>
                        </div>
                        <span class="item-date">2011 - 2015</span>
                    </div>
                    <div class="item-subtitle">UC Berkeley</div>
                </div>
            </section>
        </body>
        </html>
        """
    }
}

// MARK: - Public Factory

/// Factory for creating PDF export engine with dependency injection
public struct PDFExportEngineFactory {

    /// Create a new PDF export engine instance with a specific renderer
    /// - Parameter renderer: The HTML to PDF renderer implementation
    /// - Returns: Configured PDFExportEngine instance
    public static func create(with renderer: HTMLToPDFRenderer) -> PDFExportEngine {
        return PDFExportEngineImpl(renderer: renderer)
    }
}
