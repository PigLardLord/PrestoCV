import Foundation
import CVPDFExporter

// Test runner to verify the PDF export functionality
@main
struct TestRunner {
    static func main() async {
        print("Testing CVPDFExporter...")

        // Create sample CV data
        let cvData: [String: Any] = [
            "personalInfo": [
                "name": "Alexandra Johnson",
                "email": "alex.johnson@email.com",
                "phone": "+1 (555) 123-4567",
                "location": "San Francisco, CA",
                "linkedIn": "linkedin.com/in/alexjohnson",
                "summary": "Senior iOS Developer with 8+ years of experience"
            ],
            "experience": [
                [
                    "title": "Senior iOS Engineer",
                    "company": "TechCorp Inc.",
                    "period": "Jan 2021 - Present",
                    "location": "San Francisco, CA",
                    "description": "Led iOS development team"
                ]
            ],
            "education": [
                [
                    "degree": "BS Computer Science",
                    "institution": "UC Berkeley",
                    "period": "2012 - 2016",
                    "location": "Berkeley, CA",
                    "description": "GPA: 3.8/4.0"
                ]
            ],
            "skills": [
                [
                    "category": "Languages",
                    "tags": ["Swift", "SwiftUI", "UIKit"]
                ]
            ],
            "languages": [
                ["name": "English", "level": "Native"]
            ],
            "certifications": [
                [
                    "name": "Apple Certified iOS Developer",
                    "issuer": "Apple Inc.",
                    "date": "2023",
                    "description": "Advanced certification"
                ]
            ]
        ]

        // Test PDF generation
        do {
            print("Creating PDF export components...")

            // Create adapter
            let adapter = PrestoCVCoreAdapter()
            let cvDocument = adapter.convertToCV(from: cvData)
            print("✅ CV document created: \(cvDocument.personalInfo.name)")

            // Load template
            let templateRepo = BundledTemplateRepository()
            let template = try templateRepo.loadTemplate(id: "modern")
            print("✅ Template loaded: \(template.name)")

            // Create renderer and use case
            let renderer = EnhancedWKWebViewPDFRenderer()
            let repository = InMemoryRepository()
            let templateEngine = MustacheTemplateEngine()

            let exportUseCase = PDFExportUseCase(
                renderer: renderer,
                repository: repository,
                templateEngine: templateEngine,
                enableCaching: false
            )

            // Configure export options
            let options = ExportOptions(
                pageSize: .a4,
                margins: EdgeInsets(top: 20, left: 20, bottom: 20, right: 20),
                maxPages: 10
            )

            print("Generating PDF...")
            let result = try await exportUseCase.execute(
                document: cvDocument,
                template: template,
                options: options
            )

            print("✅ PDF generated successfully!")
            print("   - Size: \(result.fileSize) bytes")
            print("   - Pages: \(result.pageCount)")

            // Save to file for inspection
            let outputPath = "/tmp/test_cv_export.pdf"
            try result.pdfData.write(to: URL(fileURLWithPath: outputPath))
            print("✅ PDF saved to: \(outputPath)")

            // Generate HTML preview
            let htmlPath = "/tmp/test_cv_export.html"
            let htmlContent = try templateEngine.render(template: template, context: adapter.convertToTemplateContext(cvDocument))
            try htmlContent.write(to: URL(fileURLWithPath: htmlPath), atomically: true, encoding: .utf8)
            print("✅ HTML preview saved to: \(htmlPath)")

            print("\n🎉 All tests passed! PDF export is working correctly.")
            print("\nYou can view the generated files:")
            print("  open \(outputPath)")
            print("  open \(htmlPath)")

        } catch {
            print("❌ Error: \(error)")
        }
    }
}

// Simple in-memory repository for testing
actor InMemoryRepository: ExportRepositoryProtocol {
    private var history: [ExportHistoryEntry] = []
    private var cache: [String: (data: Data, expiry: Date)] = [:]

    func saveExportHistory(_ entry: ExportHistoryEntry) async throws {
        history.append(entry)
    }

    func getExportHistory(limit: Int) async throws -> [ExportHistoryEntry] {
        return Array(history.suffix(limit))
    }

    func cachePDF(data: Data, key: String, ttl: TimeInterval) async throws {
        let expiry = Date().addingTimeInterval(ttl)
        cache[key] = (data, expiry)
    }

    func getCachedPDF(key: String) async -> Data? {
        if let cached = cache[key], cached.expiry > Date() {
            return cached.data
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