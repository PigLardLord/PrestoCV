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
    @Test("UPDATE_PREVIEWS=1 stores the first page of each design as its preview",
          .enabled(if: ProcessInfo.processInfo.environment["UPDATE_PREVIEWS"] == "1", "runs only with UPDATE_PREVIEWS=1"))
    func previews() async throws {
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

    /// Writes the preview as the package's last key and leaves the rest of the file as written, so that its diff shows only
    /// the preview; a preview stored before is replaced.
    static func store(_ png: Data, in name: String, data: Data) throws {
        let key = ",\n  \"previewImageBase64\": \"", preview = png.base64EncodedString()
        var text = try #require(String(data: data, encoding: .utf8)).trimmingCharacters(in: .whitespacesAndNewlines)
        if let old = text.range(of: key) { text = String(text[..<old.lowerBound]) + "\n}" }
        try #require(text.hasSuffix("\n}"), "\(name): the package must end with a closing brace on a line of its own")
        let stored = Data((String(text.dropLast(2)) + key + preview + "\"\n}\n").utf8)
        let before = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let after = try #require(try JSONSerialization.jsonObject(with: stored) as? [String: Any])
        try #require(after["previewImageBase64"] as? String == preview, "\(name): the preview is not the stored one")
        try #require(NSDictionary(dictionary: after.filter { $0.key != "previewImageBase64" })
                     == NSDictionary(dictionary: before.filter { $0.key != "previewImageBase64" }), "\(name): the rest of the package changed")
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/CVBundledDesigns/Designs/\(name).mcvt")
        try stored.write(to: file)
    }
}
#endif
