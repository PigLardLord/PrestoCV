import Foundation
import CVPDFExporter

@main
struct TestExportApp {
    static func main() async {
        do {
            try await run()
        } catch {
            print("❌ Test export failed: \(error)")
            exit(1)
        }
    }

    private static func run() async throws {
        let sampleDocument = SampleData.makeDocument()
        let repository = BundledTemplateRepository()
        let template = try await repository.loadTemplate(id: "modern")
        let templateEngine = MustacheTemplateEngine()

        let html = try await templateEngine.render(
            template: template,
            data: sampleDocument,
            customization: CustomizationOptions(colorPalette: .professional, fontScheme: .modern)
        )

        let renderer = await PDFRendererFactory.createRenderer()
        let pdfData = try await renderer.renderToPDF(html: html, options: .default)

        let exportURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cv_test_export.pdf")
        try pdfData.write(to: exportURL)

        print("✅ Export successful → \(exportURL.path)")
        print("   Size: \(ByteCountFormatter.string(fromByteCount: Int64(pdfData.count), countStyle: .file))")
    }
}

private enum SampleData {
    static func makeDocument() -> CVDocument {
        let personalInfo = PersonalInfo(
            name: "Maya Chen",
            email: "maya.chen@example.com",
            phone: "+1 (555) 987-6543",
            location: "Brooklyn, NY",
            website: "https://mayachen.design",
            summary: "Senior product designer focused on shipping accessible, user-centered experiences."
        )

        let experience = CVSection(
            type: .work,
            title: "Experience",
            items: [
                CVItem(
                    title: "Senior UX Designer",
                    subtitle: "DesignForward Agency",
                    description: "Led design system adoption across 15 product squads and improved retention by 12%.",
                    startDate: "2021",
                    endDate: "Present",
                    location: "Remote",
                    tags: ["Design Systems", "Leadership", "A/B Testing"]
                ),
                CVItem(
                    title: "Product Designer",
                    subtitle: "EcoTech Solutions",
                    description: "Owned end-to-end UX for sustainability analytics platform used by Fortune 500 teams.",
                    startDate: "2018",
                    endDate: "2021",
                    location: "New York, NY",
                    tags: ["User Research", "Prototyping", "Interaction Design"]
                )
            ],
            order: 1
        )

        let education = CVSection(
            type: .education,
            title: "Education",
            items: [
                CVItem(
                    title: "MFA, Graphic Design",
                    subtitle: "RISD",
                    description: "Thesis on inclusive design patterns for mobile platforms.",
                    startDate: "2014",
                    endDate: "2016",
                    location: "Providence, RI"
                )
            ],
            order: 2
        )

        let skills = CVSection(
            type: .skills,
            title: "Skills",
            items: [
                CVItem(title: "Design", tags: ["Figma", "Sketch", "Adobe CC"]),
                CVItem(title: "Research", tags: ["User Interviews", "Journey Mapping", "Usability Testing"])
            ],
            order: 3
        )

        return CVDocument(
            personalInfo: personalInfo,
            sections: [experience, education, skills],
            metadata: DocumentMetadata(language: "en")
        )
    }
}
