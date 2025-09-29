#!/usr/bin/swift

import Foundation
import CVPDFExporter

// Mock CV data
let mockData: [String: Any] = [
    "name": "Alexandra Johnson",
    "email": "alexandra.johnson@email.com",
    "phone": "+1 (415) 555-0123",
    "location": "San Francisco, CA",
    "website": "alexandra-dev.com",
    "summary": "Senior iOS Developer with 8+ years of experience building high-performance mobile applications.",
    "experience": [
        [
            "title": "Senior iOS Engineer",
            "company": "TechCorp Inc.",
            "description": "Led development of flagship iOS app.",
            "startDate": "2021",
            "endDate": "Present",
            "location": "San Francisco, CA"
        ]
    ],
    "education": [
        [
            "degree": "Master of Science in Computer Science",
            "school": "Stanford University",
            "description": "Specialized in Mobile Computing.",
            "startDate": "2014",
            "endDate": "2016"
        ]
    ],
    "skills": [
        ["category": "Languages & Frameworks", "tags": ["Swift", "SwiftUI", "UIKit", "Objective-C", "Combine", "Core Data"]],
        ["category": "Tools & Technologies", "tags": ["Xcode", "Git", "Jenkins", "Fastlane", "Firebase", "TestFlight"]],
        ["category": "Architecture & Patterns", "tags": ["MVVM", "Clean Architecture", "SOLID", "TDD", "REST APIs", "GraphQL"]],
        ["category": "Soft Skills", "tags": ["Team Leadership", "Mentoring", "Agile/Scrum", "Technical Writing", "Code Review"]]
    ],
    "languages": [
        ["language": "English", "level": "Native"],
        ["language": "Spanish", "level": "Professional Working Proficiency"]
    ]
]

// Test HTML generation only
Task {
    do {
        print("🚀 Testing HTML generation with fixed template engine...")

        // Create components
        let htmlTemplate = ModernHTMLTemplate()
        let templateEngine = MustacheTemplateEngine()
        let adapter = PrestoCVCoreAdapter()

        // Convert data and render
        let cvDocument = try adapter.convert(from: mockData)
        let html = try await templateEngine.render(
            template: htmlTemplate.template,
            data: cvDocument,
            customization: CustomizationOptions()
        )

        // Save HTML
        let outputPath = "/tmp/cv_test.html"
        try html.write(to: URL(fileURLWithPath: outputPath), atomically: true, encoding: .utf8)

        print("✅ HTML saved to: \(outputPath)")

        // Check if skills are properly rendered
        if html.contains("Swift") && html.contains("SwiftUI") && html.contains("UIKit") {
            print("✅ Skills are properly rendered!")
        } else {
            print("⚠️ Skills might not be rendered correctly")
        }

        // Check if template variables are replaced
        if html.contains("{{#hasSkills}}") || html.contains("{{#skillList}}") {
            print("❌ Template variables still present in output!")
        } else {
            print("✅ All template variables processed!")
        }

        print("\n📂 Open the HTML file to verify:")
        print("open \(outputPath)")

        exit(0)
    } catch {
        print("❌ Error: \(error)")
        exit(1)
    }
}

dispatchMain()