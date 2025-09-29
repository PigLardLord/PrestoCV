import Foundation
import CVPDFExporter

// Mock CV data
let mockData: [String: Any] = [
    "name": "Alexandra Johnson",
    "email": "alexandra.johnson@email.com",
    "phone": "+1 (415) 555-0123",
    "location": "San Francisco, CA",
    "website": "alexandra-dev.com",
    "summary": "Senior iOS Developer with 8+ years of experience building high-performance mobile applications. Specialized in Swift, SwiftUI, and modern iOS architectures. Passionate about creating intuitive user experiences and mentoring junior developers. Led teams of up to 10 engineers in delivering mission-critical applications with millions of active users.",
    "experience": [
        [
            "title": "Senior iOS Engineer",
            "company": "TechCorp Inc.",
            "description": "Led development of flagship iOS app serving 5M+ users. Architected modular SwiftUI framework reducing development time by 40%. Mentored team of 6 junior developers. Implemented CI/CD pipeline reducing release cycle from 2 weeks to 3 days.",
            "startDate": "2021",
            "endDate": "Present",
            "location": "San Francisco, CA"
        ],
        [
            "title": "iOS Developer",
            "company": "StartupXYZ",
            "description": "Built iOS app from scratch reaching 100K downloads in first 6 months. Integrated complex payment systems handling $2M+ in transactions. Reduced app crash rate from 2% to 0.1% through comprehensive testing. Collaborated with design team to implement pixel-perfect UI/UX.",
            "startDate": "2018",
            "endDate": "2021",
            "location": "Palo Alto, CA"
        ],
        [
            "title": "Junior iOS Developer",
            "company": "Mobile Solutions Ltd.",
            "description": "Developed features for enterprise iPad applications used by Fortune 500 clients. Optimized app performance improving load times by 60%. Participated in code reviews and agile development processes. Contributed to open-source iOS libraries with 500+ GitHub stars.",
            "startDate": "2016",
            "endDate": "2018",
            "location": "San Jose, CA"
        ]
    ],
    "education": [
        [
            "degree": "Master of Science in Computer Science",
            "school": "Stanford University",
            "description": "Specialized in Mobile Computing and Human-Computer Interaction. Thesis on 'Optimizing SwiftUI Performance in Large-Scale Applications'. GPA: 3.9/4.0",
            "startDate": "2014",
            "endDate": "2016"
        ],
        [
            "degree": "Bachelor of Science in Software Engineering",
            "school": "UC Berkeley",
            "description": "Dean's List, President of Mobile Development Club. Coursework included iOS Development, Algorithms, Software Architecture. GPA: 3.8/4.0",
            "startDate": "2010",
            "endDate": "2014"
        ]
    ],
    "skills": [
        ["category": "Languages & Frameworks", "tags": ["Swift", "SwiftUI", "UIKit", "Objective-C", "Combine", "Core Data"]],
        ["category": "Tools & Technologies", "tags": ["Xcode", "Git", "Jenkins", "Fastlane", "Firebase", "TestFlight"]],
        ["category": "Architecture & Patterns", "tags": ["MVVM", "Clean Architecture", "SOLID", "TDD", "REST APIs", "GraphQL"]],
        ["category": "Soft Skills", "tags": ["Team Leadership", "Mentoring", "Agile/Scrum", "Technical Writing", "Code Review"]]
    ],
    "certifications": [
        [
            "title": "Apple Certified iOS Developer",
            "issuer": "Apple Inc.",
            "date": "2022",
            "description": "Official certification demonstrating expertise in iOS development, Swift, and Apple frameworks."
        ],
        [
            "title": "AWS Certified Solutions Architect",
            "issuer": "Amazon Web Services",
            "date": "2021",
            "description": "Proficiency in designing distributed systems and cloud architectures for mobile backends."
        ]
    ],
    "languages": [
        ["language": "English", "level": "Native"],
        ["language": "Spanish", "level": "Professional Working Proficiency"],
        ["language": "Mandarin", "level": "Basic Conversational"]
    ]
]

@main
struct TestApp {
    static func main() async {
        do {
            print("🚀 Starting PDF generation...")

            // Create exporter
            let exporter = PDFExporter()

            // Export options
            let options = ExportOptions()

            // Export to PDF
            let pdfData = try await exporter.export(
                from: mockData,
                templateId: "modern",
                options: options
            )

            // Save PDF
            let outputPath = "/tmp/cv_export.pdf"
            try pdfData.write(to: URL(fileURLWithPath: outputPath))

            print("✅ PDF saved to: \(outputPath)")
            print("📊 Size: \(pdfData.count) bytes (\(pdfData.count / 1024)KB)")

            // Also save the HTML for inspection
            let htmlTemplate = ModernHTMLTemplate()
            let templateEngine = MustacheTemplateEngine()
            let adapter = PrestoCVCoreAdapter()
            let cvDocument = try adapter.convert(from: mockData)
            let html = try await templateEngine.render(
                template: htmlTemplate.template,
                data: cvDocument,
                customization: CustomizationOptions()
            )
            try html.write(to: URL(fileURLWithPath: "/tmp/cv_preview.html"), atomically: true, encoding: .utf8)
            print("✅ HTML saved to: /tmp/cv_preview.html")

            print("\n🎉 Generation complete!")
            print("📂 Files created:")
            print("  • /tmp/cv_preview.html")
            print("  • /tmp/cv_export.pdf")

            exit(0)
        } catch {
            print("❌ Error: \(error)")
            exit(1)
        }
    }
}