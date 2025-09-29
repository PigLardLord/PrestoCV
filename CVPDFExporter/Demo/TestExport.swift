import Foundation
import CVPDFExporter

// Test the actual PDF rendering pipeline
@main
struct TestExport {
    static func main() async {
        print("🚀 Testing CVPDFExporter with actual renderer...")
        print("=" * 50)

        // Create sample CV data structure
        let cvData: [String: Any] = [
            "personalInfo": [
                "name": "Alexandra Johnson",
                "email": "alex.johnson@email.com",
                "phone": "+1 (555) 123-4567",
                "location": "San Francisco, CA",
                "linkedIn": "linkedin.com/in/alexjohnson",
                "summary": """
                Senior iOS Developer with 8+ years of experience building high-performance mobile applications. \
                Specialized in Swift, SwiftUI, and modern iOS architectures. Passionate about creating \
                intuitive user experiences and mentoring junior developers. Led teams of up to 10 engineers \
                in delivering mission-critical applications with millions of active users.
                """
            ],
            "experience": [
                [
                    "title": "Senior iOS Engineer",
                    "company": "TechCorp Inc.",
                    "period": "Jan 2021 - Present",
                    "location": "San Francisco, CA",
                    "description": """
                    • Led iOS development team of 6 engineers in building flagship mobile banking app
                    • Architected and implemented modular SwiftUI architecture reducing build times by 40%
                    • Mentored junior developers and conducted code reviews to maintain high code quality
                    • Implemented CI/CD pipeline reducing deployment time from days to hours
                    • Collaborated with product and design teams to deliver features used by 2M+ users
                    """
                ],
                [
                    "title": "iOS Developer",
                    "company": "StartupXYZ",
                    "period": "Jun 2018 - Dec 2020",
                    "location": "San Francisco, CA",
                    "description": """
                    • Developed consumer-facing iOS app from concept to App Store release
                    • Implemented real-time chat using WebSocket and background processing
                    • Reduced app launch time by 60% through performance optimizations
                    • Built custom UI components library used across multiple products
                    • Achieved 4.8★ App Store rating with over 50K downloads
                    """
                ],
                [
                    "title": "Junior iOS Developer",
                    "company": "Digital Agency Co.",
                    "period": "Jul 2016 - May 2018",
                    "location": "New York, NY",
                    "description": """
                    • Developed and maintained iOS applications for various clients
                    • Implemented push notifications and in-app purchase features
                    • Collaborated with Android team to ensure feature parity
                    • Participated in agile development process with 2-week sprints
                    """
                ]
            ],
            "education": [
                [
                    "degree": "Bachelor of Science in Computer Science",
                    "institution": "University of California, Berkeley",
                    "period": "2012 - 2016",
                    "location": "Berkeley, CA",
                    "description": "GPA: 3.8/4.0 • Dean's List • Magna Cum Laude"
                ]
            ],
            "skills": [
                [
                    "category": "Languages & Frameworks",
                    "tags": ["Swift", "SwiftUI", "UIKit", "Objective-C", "Combine", "Core Data", "CloudKit"]
                ],
                [
                    "category": "Tools & Technologies",
                    "tags": ["Xcode", "Git", "CI/CD", "Fastlane", "TestFlight", "Firebase", "REST APIs", "GraphQL"]
                ],
                [
                    "category": "Architecture & Patterns",
                    "tags": ["MVVM", "Clean Architecture", "TDD", "SOLID", "Coordinator Pattern", "Dependency Injection"]
                ],
                [
                    "category": "Soft Skills",
                    "tags": ["Team Leadership", "Mentoring", "Agile/Scrum", "Code Review", "Technical Documentation"]
                ]
            ],
            "languages": [
                ["name": "English", "level": "Native"],
                ["name": "Spanish", "level": "Professional Working Proficiency"],
                ["name": "Mandarin", "level": "Basic Conversational"]
            ],
            "certifications": [
                [
                    "name": "Apple Certified iOS Developer",
                    "issuer": "Apple Inc.",
                    "date": "2023",
                    "description": "Advanced certification in iOS development and best practices"
                ],
                [
                    "name": "WWDC 2023 Scholarship Winner",
                    "issuer": "Apple Inc.",
                    "date": "2023",
                    "description": "Selected from thousands of applicants worldwide"
                ],
                [
                    "name": "AWS Certified Solutions Architect",
                    "issuer": "Amazon Web Services",
                    "date": "2022",
                    "description": "Associate level certification for cloud architecture"
                ]
            ]
        ]

        do {
            print("\n📋 Step 1: Converting CV data to domain model...")
            let adapter = PrestoCVCoreAdapter()
            let cvDocument = adapter.convertToCV(from: cvData)
            print("✅ CV document created for: \(cvDocument.personalInfo.name)")

            print("\n📄 Step 2: Loading template...")
            let templateRepo = BundledTemplateRepository()
            let template = try templateRepo.loadTemplate(id: "modern")
            print("✅ Template loaded: \(template.name)")

            print("\n🎨 Step 3: Setting up PDF rendering...")
            let templateEngine = MustacheTemplateEngine()

            print("\n🖨️ Step 4: Creating PDF renderer...")

            // Use the factory to get the appropriate renderer
            let renderer = PDFRendererFactory.createRenderer()
            print("✅ Using renderer: \(type(of: renderer))")

            // Create repository
            let repository = InMemoryExportRepository()

            // Create use case
            let exportUseCase = PDFExportUseCase(
                renderer: renderer,
                repository: repository,
                templateEngine: templateEngine,
                enableCaching: false
            )

            // Configure options
            let options = ExportOptions(
                pageSize: .a4,
                margins: EdgeInsets(top: 20, left: 20, bottom: 20, right: 20),
                maxPages: 10
            )

            // Execute PDF generation
            print("⏳ Generating PDF (this may take a few seconds)...")
            let result = try await exportUseCase.execute(
                document: cvDocument,
                template: template,
                options: options
            )

            print("✅ PDF generated successfully!")
            print("   📊 Size: \(result.fileSize) bytes")
            print("   📄 Pages: \(result.pageCount)")

            // Save PDF
            let pdfPath = "/tmp/cv_export.pdf"
            try result.pdfData.write(to: URL(fileURLWithPath: pdfPath))
            print("\n💾 PDF saved to: \(pdfPath)")

            // Also generate HTML for preview
            let htmlContent = try await templateEngine.render(template: template, data: cvDocument)
            let htmlPath = "/tmp/cv_preview.html"
            try htmlContent.data(using: .utf8)?.write(to: URL(fileURLWithPath: htmlPath))
            print("📝 HTML preview also saved to: \(htmlPath)")

            print("\n" + "=" * 50)
            print("🎉 SUCCESS! PDF export is working correctly!")
            print("\n📂 Generated files:")
            print("   HTML: file://\(htmlPath)")
            print("   PDF:  file://\(pdfPath)")
            print("\n🔍 To view the results:")
            print("   open \(htmlPath)  # View HTML in browser")
            print("   open \(pdfPath)   # View PDF")

            #if os(iOS)
            print("\n📱 On iOS: The CVExportButton would show this PDF in QuickLook")
            #endif

        } catch {
            print("\n❌ Error: \(error)")
            print("   \(error.localizedDescription)")
        }
    }
}

// Extension to create string repetition
extension String {
    static func *(left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}

// In-memory repository for testing
actor InMemoryExportRepository: ExportRepositoryProtocol {
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