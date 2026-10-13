import Foundation
import CVPDFExporter

/// Demo app to render an actual CV to PDF
struct RenderCVDemo {

    static func main() async {
        print("🚀 CVPDFExporter Demo - Rendering Real CV")
        print(String(repeating: "=", count: 50))

        do {
            // 1. Create sample CV data
            print("\n📝 Creating sample CV data...")
            let cvDocument = createSampleCV()
            print("✅ CV created for: \(cvDocument.personalInfo.name)")

            // 2. Load and render template
            print("\n🎨 Loading template...")
            let templateRepository = BundledTemplateRepository()
            let template = try await templateRepository.loadTemplate(id: "modern")
            let templateEngine = MustacheTemplateEngine()
            print("✅ Template loaded: \(template.name)")

            // 3. Generate HTML
            print("\n🔧 Generating HTML...")
            let customization = CustomizationOptions(
                colorPalette: .professional,
                fontScheme: .modern
            )
            let html = try await templateEngine.render(
                template: template,
                data: cvDocument,
                customization: customization
            )
            print("✅ HTML generated (\(html.count) bytes)")

            // 4. Save HTML for preview
            let htmlPath = FileManager.default.temporaryDirectory
                .appendingPathComponent("cv_preview.html")
            try html.write(to: htmlPath, atomically: true, encoding: String.Encoding.utf8)
            print("📄 HTML saved to: \(htmlPath.path)")

            // 5. Render to PDF
            print("\n📄 Rendering PDF...")
            let renderer = await PDFRendererFactory.createRenderer()
            print("Using renderer: \(type(of: renderer))")

            let options = ExportOptions(
                pageSize: .a4,
                margins: EdgeInsets(top: 20, left: 20, bottom: 20, right: 20),
                maxPages: 10
            )

            let startTime = Date()
            let pdfData = try await renderer.renderToPDF(html: html, options: options)
            let renderTime = Date().timeIntervalSince(startTime)

            print("✅ PDF rendered in \(String(format: "%.2f", renderTime))s")
            print("   Size: \(formatBytes(pdfData.count))")

            // 6. Save PDF
            let pdfPath = FileManager.default.temporaryDirectory
                .appendingPathComponent("cv_output.pdf")
            try pdfData.write(to: pdfPath)
            print("💾 PDF saved to: \(pdfPath.path)")

            // 7. Display summary
            print("\n" + String(repeating: "=", count: 50))
            print("✨ Success! CV rendered successfully")
            print("\nFiles created:")
            print("  • HTML: \(htmlPath.lastPathComponent)")
            print("  • PDF:  \(pdfPath.lastPathComponent)")
            print("\nOpen the PDF with:")
            print("  open \(pdfPath.path)")

            // On macOS, offer to open the PDF
            #if os(macOS)
            print("\nPress ENTER to open the PDF, or Ctrl+C to exit...")
            _ = readLine()

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = [pdfPath.path]
            try process.run()
            print("📖 Opening PDF in default viewer...")
            #endif

        } catch {
            print("\n❌ Error: \(error)")
            exit(1)
        }
    }

    static func createSampleCV() -> CVDocument {
        let personalInfo = PersonalInfo(
            name: "Alexandra Johnson",
            email: "alex.johnson@email.com",
            phone: "+1 (555) 123-4567",
            location: "San Francisco, CA",
            website: "linkedin.com/in/alexjohnson",
            summary: """
            Senior iOS Developer with 8+ years of experience building high-performance mobile applications.
            Specialized in Swift, SwiftUI, and modern iOS architectures. Passionate about creating
            intuitive user experiences and mentoring junior developers. Led teams of up to 10 engineers
            in delivering mission-critical applications with millions of active users.
            """
        )

        let workExperience = CVSection(
            id: "work",
            type: .work,
            title: "Professional Experience",
            items: [
                CVItem(
                    title: "Senior iOS Engineer",
                    subtitle: "TechCorp Inc.",
                    description: """
                    • Led iOS development team of 6 engineers in building flagship mobile banking app
                    • Architected and implemented modular SwiftUI architecture reducing build times by 40%
                    • Mentored junior developers and conducted code reviews to maintain high code quality
                    • Implemented CI/CD pipeline reducing deployment time from days to hours
                    • Collaborated with product and design teams to deliver features used by 2M+ users
                    """,
                    startDate: "Jan 2021",
                    endDate: "Present",
                    location: "San Francisco, CA",
                    tags: ["Swift", "SwiftUI", "Team Lead"]
                ),
                CVItem(
                    title: "iOS Developer",
                    subtitle: "StartupXYZ",
                    description: """
                    • Developed consumer-facing iOS app from concept to App Store release
                    • Implemented real-time chat using WebSocket and background processing
                    • Reduced app launch time by 60% through performance optimizations
                    • Built custom UI components library used across multiple products
                    • Achieved 4.8★ App Store rating with over 50K downloads
                    """,
                    startDate: "Jun 2018",
                    endDate: "Dec 2020",
                    location: "San Francisco, CA",
                    tags: ["UIKit", "Core Data", "REST APIs"]
                ),
                CVItem(
                    title: "Junior iOS Developer",
                    subtitle: "Digital Agency Co.",
                    description: """
                    • Developed and maintained iOS applications for various clients
                    • Implemented push notifications and in-app purchase features
                    • Collaborated with Android team to ensure feature parity
                    • Participated in agile development process with 2-week sprints
                    """,
                    startDate: "Jul 2016",
                    endDate: "May 2018",
                    location: "New York, NY",
                    tags: ["Objective-C", "iOS", "Mobile"]
                )
            ],
            order: 1
        )

        let education = CVSection(
            id: "education",
            type: .education,
            title: "Education",
            items: [
                CVItem(
                    title: "Bachelor of Science in Computer Science",
                    subtitle: "University of California, Berkeley",
                    description: "GPA: 3.8/4.0 • Dean's List • Magna Cum Laude",
                    startDate: "2012",
                    endDate: "2016",
                    location: "Berkeley, CA",
                    tags: []
                )
            ],
            order: 2
        )

        let skills = CVSection(
            id: "skills",
            type: .skills,
            title: "Technical Skills",
            items: [
                CVItem(
                    title: "Languages & Frameworks",
                    subtitle: nil,
                    description: nil,
                    startDate: nil,
                    endDate: nil,
                    location: nil,
                    tags: ["Swift", "SwiftUI", "UIKit", "Objective-C", "Combine", "Async/Await"]
                ),
                CVItem(
                    title: "Tools & Technologies",
                    subtitle: nil,
                    description: nil,
                    startDate: nil,
                    endDate: nil,
                    location: nil,
                    tags: ["Xcode", "Git", "CI/CD", "Firebase", "TestFlight", "App Store Connect"]
                ),
                CVItem(
                    title: "Architecture & Patterns",
                    subtitle: nil,
                    description: nil,
                    startDate: nil,
                    endDate: nil,
                    location: nil,
                    tags: ["MVVM", "Clean Architecture", "TDD", "SOLID", "Dependency Injection"]
                ),
                CVItem(
                    title: "Soft Skills",
                    subtitle: nil,
                    description: nil,
                    startDate: nil,
                    endDate: nil,
                    location: nil,
                    tags: ["Team Leadership", "Mentoring", "Agile/Scrum", "Technical Writing"]
                )
            ],
            order: 3
        )

        let certifications = CVSection(
            id: "certifications",
            type: .certifications,
            title: "Certifications & Achievements",
            items: [
                CVItem(
                    title: "Apple Certified iOS Developer",
                    subtitle: "Apple Inc.",
                    description: "Advanced certification in iOS development and best practices",
                    startDate: "2023",
                    endDate: nil,
                    location: nil,
                    tags: []
                ),
                CVItem(
                    title: "WWDC 2023 Scholarship Winner",
                    subtitle: "Apple Inc.",
                    description: "Selected from thousands of applicants worldwide",
                    startDate: "2023",
                    endDate: nil,
                    location: nil,
                    tags: []
                ),
                CVItem(
                    title: "AWS Certified Solutions Architect",
                    subtitle: "Amazon Web Services",
                    description: "Associate level certification for cloud architecture",
                    startDate: "2022",
                    endDate: nil,
                    location: nil,
                    tags: []
                )
            ],
            order: 4
        )

        let languages = CVSection(
            id: "languages",
            type: .languages,
            title: "Languages",
            items: [
                CVItem(
                    title: "English",
                    subtitle: "Native",
                    description: nil,
                    startDate: nil,
                    endDate: nil,
                    location: nil,
                    tags: []
                ),
                CVItem(
                    title: "Spanish",
                    subtitle: "Professional Working Proficiency",
                    description: nil,
                    startDate: nil,
                    endDate: nil,
                    location: nil,
                    tags: []
                ),
                CVItem(
                    title: "Mandarin",
                    subtitle: "Basic Conversational",
                    description: nil,
                    startDate: nil,
                    endDate: nil,
                    location: nil,
                    tags: []
                )
            ],
            order: 5
        )

        return CVDocument(
            personalInfo: personalInfo,
            sections: [workExperience, education, skills, certifications, languages],
            metadata: DocumentMetadata()
        )
    }

    static func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// String repetition helper removed - using String(repeating:count:) directly
