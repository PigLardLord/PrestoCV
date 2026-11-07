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

/// #121 and #3: the bundled designs, printed by the real macOS renderer in every language, read by `pdftotext` the way a
/// naive parser reads a CV. Needs poppler (`brew install poppler`): a Mac without it fails the test, it does not skip it.
@MainActor
@Suite("#121 · a naive parser reads each printed bundled design", .serialized, .timeLimit(.minutes(10)))
struct BundledDesignsPrintedTests {
    static let palette = ContractFixture.palette

    func renderer() async throws -> MacPDFRenderer { MacPDFRenderer(rules: try await SecureWebViewConfiguration.compileRules()) }

    func printed(_ design: ValidatedDesign, language: String) async throws -> (pdf: Data, document: CVDocument, headings: Headings) {
        let document = AtsFixture.document(language: language)
        let headings = try HeadingsCatalog(source: BundleHeadingTableSource()).headings(for: language)
        let html = DocumentHTMLBuilder().build(document, stylesheet: design.stylesheet, palette: Self.palette, headings: headings)
        let pdf = try await renderer().render(html: html, page: .a4)
        #expect(!pdf.truncated, "\(design.manifest.id) \(language): truncated")
        return (pdf.data, document, headings)
    }

    @Test("every design in every language keeps sections, email, roles and chronology in reading and in content-stream order")
    func readsBack() async throws {
        for package in try await BundleDesignSource().bundledPackages() {
            let design = try DesignPackageValidator().validate(package.data)
            for language in AtsFixture.languages {
                let output = try await printed(design, language: language)
                for raw in [false, true] { try check(output, label: "\(design.manifest.id) \(language) raw=\(raw)", raw: raw) }
            }
        }
    }

    func check(_ printed: (pdf: Data, document: CVDocument, headings: Headings), label: String, raw: Bool) throws {
        let text = try Pdftotext.read(printed.pdf, raw: raw)
        let reading = AtsReading(text: text, document: printed.document, headings: printed.headings)
        #expect(reading.passesFloors, "\(label): failed \(reading.failedFloors)")
        #expect(reading.score >= 0.95, "\(label): recovered \(reading.recovered) of \(reading.expected)")
    }

    /// UPDATE_PREVIEWS=1 prints the English fixture with each design and stores the first page as the package's preview,
    /// over the file in the checkout. The package's hash changes: pin the new one in `BundledDesignsRenderingTests`.
    @Test("UPDATE_PREVIEWS=1 stores the first page of each design as its preview")
    func previews() async throws {
        guard ProcessInfo.processInfo.environment["UPDATE_PREVIEWS"] == "1" else { return }
        for package in try await BundleDesignSource().bundledPackages() {
            let design = try DesignPackageValidator().validate(package.data)
            let png = try Self.firstPagePNG(try await printed(design, language: "en").pdf)
            try Self.store(png, in: package.name, data: package.data)
        }
    }

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

/// `pdftotext` from poppler: reading order by default, content-stream order with `-raw`.
enum Pdftotext {
    struct Missing: Error, CustomStringConvertible { var description: String { "pdftotext not found: brew install poppler" } }

    static func read(_ pdf: Data, raw: Bool) throws -> String {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).pdf")
        try pdf.write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        let process = Process(), out = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["pdftotext"] + (raw ? ["-raw"] : []) + [file.path, "-"]
        process.environment = ["PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"]
        process.standardOutput = out
        try process.run()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw Missing() }
        return String(decoding: data, as: UTF8.self)
    }
}
#endif
