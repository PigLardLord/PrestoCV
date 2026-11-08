#if os(macOS)   // macOS only (R11)
import Testing
import Foundation
import AppKit
import PDFKit
import CVDocumentModel
import CVDesignCatalog
import CVRendering
import CVRenderingMacOS
import CVRenderingWebKitSupport
import CVRenderingTestSupport
import CVBundledDesigns
import CVBundledHeadings

/// #3: the preview of each bundled design, printed from the real render path.
@MainActor
@Suite("#3 · bundled design previews", .serialized, .timeLimit(.minutes(10)))
struct BundledDesignsPreviewTests {
    /// UPDATE_PREVIEWS=1 prints the English sample with each design and stores the first page as the package's preview,
    /// over the file in the checkout. The package's hash changes: pin the new one in `BundledDesignsRenderingTests`.
    @Test("UPDATE_PREVIEWS=1 stores the first page of each design as its preview")
    func previews() async throws {
        guard ProcessInfo.processInfo.environment["UPDATE_PREVIEWS"] == "1" else { return }
        let renderer = MacPDFRenderer(rules: try await SecureWebViewConfiguration.compileRules())
        let headings = try HeadingsCatalog(source: BundleHeadingTableSource()).headings(for: "en")
        for package in try await BundleDesignSource().bundledPackages() {
            let design = try DesignPackageValidator().validate(package.data)
            let html = DocumentHTMLBuilder().build(Self.sample, stylesheet: design.stylesheet, palette: ContractFixture.palette, headings: headings)
            let pdf = try await renderer.render(html: html, page: .a4)
            #expect(!pdf.truncated, "\(design.manifest.id): truncated")
            try Self.store(try Self.firstPagePNG(pdf.data), in: package.name, data: package.data)
        }
    }

    /// An invented CV with three roles, two degrees and every other section; the names, employers and contacts are made up.
    static let sample = CVDocument(language: "en", person: Person(
        name: "Marta Bellini", professionalTitle: "Food safety specialist", email: "marta.bellini@example.org",
        phone: "+39 333 000 0000", location: "Bologna", website: "https://marta.example.org"), sections: [
        .summary("Eight years of quality work in food production, from the line to the audit."),
        .experience([
            ExperienceItem(role: "Head of quality", company: "Forno Aurora", location: "Bologna",
                           period: DocumentPeriod(start: DocumentDate(year: 2021, month: 4), end: .present), description: "Ran the audits of two plants."),
            ExperienceItem(role: "Quality engineer", company: "Pasta Dorata", location: "Modena",
                           period: DocumentPeriod(start: DocumentDate(year: 2017, month: 9), end: .date(DocumentDate(year: 2021, month: 3))), description: "Cut rejects by a third."),
            ExperienceItem(role: "Line technician", company: "Latteria Verde", period: DocumentPeriod(start: DocumentDate(year: 2014), end: .date(DocumentDate(year: 2017)))),
        ]),
        .education([
            EducationItem(degree: "Food technology", school: "University of Example", period: DocumentPeriod(start: DocumentDate(year: 2011), end: .date(DocumentDate(year: 2014)))),
            EducationItem(degree: "Chemistry diploma", school: "Istituto Esempio", period: DocumentPeriod(start: DocumentDate(year: 2006), end: .date(DocumentDate(year: 2011)))),
        ]),
        .skills([SkillItem(name: "Root cause analysis", rating: 5), SkillItem(name: "Audits"), SkillItem(name: "HACCP", rating: 4)]),
        .languages([LanguageItem(language: "Italiano", level: .native), LanguageItem(language: "English", level: .c1)]),
        .certifications([CertificationItem(name: "Lead auditor", issuer: "Example Institute", year: 2020, url: "https://cert.example.org/1")]),
        .profiles([ProfileLink(platform: "Web", url: "https://marta.example.org/cv")]),
        .interests(["Hiking", "Chess"]),
    ])

    static func firstPagePNG(_ pdf: Data) throws -> Data {
        let page = try #require(PDFDocument(data: pdf)?.page(at: 0))
        let image = page.thumbnail(of: CGSize(width: 480, height: 679), for: .mediaBox)
        let tiff = try #require(image.tiffRepresentation)
        return try #require(NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]))
    }

    static func store(_ png: Data, in name: String, data: Data) throws {
        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["previewImageBase64"] = png.base64EncodedString()
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/CVBundledDesigns/Designs/\(name).mcvt")
        try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]).write(to: file)
    }
}
#endif
