#if canImport(WebKit) && canImport(PDFKit)   // Apple platforms only (R11)
import Foundation
import PDFKit
import CVDocumentModel
import CVDesignCatalog
import CVRendering
import CVRenderingTestSupport
import CVRenderingPDFKitInspector
import CVBundledHeadings
import CVBundledDesigns

/// Why a check of a native renderer failed, with what it read, so a failing run says what the PDF held.
public enum NativeCheckFailure: Error, Equatable {
    case unreadablePDF
    case fixtureLacks(String)
    case incomplete(missing: [String])
    case droppedNodeNotReported(missing: [String])
    case wordsRunTogether(missing: [String], text: String)
    case scriptRan
    case requestEscaped(connections: Int)
    case controlMadeNoRequest
    case annotationsDiffer(found: [String], expected: [String])
    case noHrefs
    case annotationsAppeared(count: Int)
    case geometry([GeometryViolation])
    case pageCountDiffers(layout: Int, rendered: Int)
    case budget(steps: Int, exhausted: Bool)
    /// The faults of a design's PDFs of one body, by the number of profile lines of the document that showed them.
    case pageBreaks(design: String, body: PageBreakDocument.Body, faults: [Int: [PageBreakFault]])
    /// A design's page-break document of `summaryLines` profile lines needed more pages than `PageBreakDocument.page` keeps.
    case pageBreakDocumentTruncated(design: String, summaryLines: Int, requiredPages: Int)
    /// A design's layout document needed more pages than its page setup keeps.
    case layoutDocumentTruncated(design: String, document: LayoutDocument, requiredPages: Int)
    /// A design's layout does not match the reference of its kind of device and system version: the verdict says which.
    case layoutDiffers(design: String, document: LayoutDocument, verdict: String)
}

/// A design that lays each profile (its platform, then its address) out with `display:flex` or `display:grid` and the
/// minimum column gap the CSS policy requires. The builder separates the two with a space, which flex and grid drop, so
/// only the gap keeps the words apart in the printed text. The skills and the interests stay apart by their spaces: a
/// section stays a block (#467).
public enum SeparationDesign: String, Sendable, CaseIterable {
    case flex, grid

    public var css: String {
        switch self {
        case .flex:
            ".cv{padding:0 36pt}.cv-profile{display:flex;flex-wrap:wrap;column-gap:3pt}"
        case .grid:
            ".cv{padding:0 36pt}.cv-profile{display:grid;grid-template-columns:1fr 1fr;column-gap:3pt}.cv-profile-platform{text-align:right}"
        }
    }

    /// The document whose inline entries the design lays out, and the words that must stay apart in the PDF's text.
    public static let document = CVDocument(language: "en", person: Person(name: "Ada Lovelace"), sections: [
        .skills([SkillItem(name: "Swift"), SkillItem(name: "Git")]),
        .profiles([ProfileLink(platform: "GitHub", url: "https://github.com/ada"),
                   ProfileLink(platform: "LinkedIn", url: "https://linkedin.com/in/ada")]),
        .interests(["Chess", "Running"]),
    ])
    public static let words = ["Swift", "Git", "GitHub", "https://github.com/ada", "LinkedIn", "https://linkedin.com/in/ada",
                               "Chess", "Running"]

    public func rendered() throws -> RenderedDocument {
        DocumentHTMLBuilder().render(Self.document, stylesheet: try ContractFixture.stylesheet(css), palette: ContractFixture.palette,
                                     headings: try HeadingsCatalog(source: BundleHeadingTableSource()).headings(for: "en"))
    }
}

/// How the annotations of a PDF are compared with the links of the document it was made from.
public enum AnnotationDestinations {
    /// Whether the annotations' destinations are exactly the links' `href`s, one annotation per link: as multisets, so a
    /// link with two annotations, or a link with none, does not match.
    public static func match(found: [String], expected: [String]) -> Bool {
        found.sorted() == expected.sorted()
    }
}

/// The checks of a native renderer on the PDFs it really prints, read back with PDFKit (#78, #80). The iOS and macOS
/// tests call them one line each, so a check cannot differ between the platforms.
@MainActor
public struct NativeRendererChecks<Renderer: PDFRendering> {
    private let renderer: Renderer
    private let inspector = PDFKitInspector()

    public init(renderer: Renderer) { self.renderer = renderer }

    // MARK: Completeness

    /// A PDF that lacks one of the builder's text nodes is reported incomplete, naming that node and only it.
    public func droppedField() async throws {
        let fixture = try ContractFixture.rendered()
        let html = try Self.replacing(">Tutored<", with: "><", in: fixture.html)
        let missing = DocumentCompleteness.missing(in: try await printedText(of: html), expected: fixture.textNodes)
        guard missing == ["Tutored"] else { throw NativeCheckFailure.droppedNodeNotReported(missing: missing) }
    }

    /// The inline entries of `design` are separate words in the PDF's text.
    public func inlineEntriesStayApart(design: SeparationDesign) async throws {
        let text = try await printedText(of: try design.rendered().html)
        let words = Set(text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).map(String.init))
        let missing = SeparationDesign.words.filter { !words.contains($0) }
        guard missing.isEmpty else { throw NativeCheckFailure.wordsRunTogether(missing: missing, text: text) }
    }

    // MARK: R8 on the renderer

    /// A script in the document does not run: the text it appends is not printed, and the document's text is.
    public func scriptDoesNotRun() async throws {
        let fixture = try ContractFixture.rendered()
        let html = try Self.hostile(fixture.html, head: "", body: Self.injectingScript)
        let text = try await printedText(of: html)
        guard !text.contains("INJECTED") else { throw NativeCheckFailure.scriptRan }
        try Self.complete(text, fixture.textNodes)
    }

    /// A remote image, stylesheet and font make no connection to the local listener they point at.
    public func remoteResourcesMakeNoConnection() async throws {
        try await makesNoConnection { base in
            (head: "<link rel=\"stylesheet\" href=\"\(base)/s.css\">"
                + "<style>@font-face{font-family:R;src:url(\"\(base)/f.woff2\")} main{font-family:R}</style>",
             body: "<p><img src=\"\(base)/i.png\"></p>")
        }
    }

    /// A link and a meta refresh are not followed: neither connects to the local listener. On macOS the check fails
    /// when the navigation policy allows them. On the iOS simulator the render ends before a refresh starts, so there the
    /// check passes even without the policy; the secure web view's own tests (#79) show the policy on iOS.
    public func linkAndRefreshAreNotFollowed() async throws {
        try await makesNoConnection { base in
            (head: "<meta http-equiv=\"refresh\" content=\"0; url=\(base)/refresh\">", body: "<p><a href=\"\(base)/link\">link</a></p>")
        }
    }

    /// After every attempt above at once, the PDF still holds the whole document and nothing the script added.
    public func documentKeepsItsText() async throws {
        let listener = try LoopbackListener()
        defer { listener.stop() }
        let base = try await listener.start()
        let fixture = try ContractFixture.rendered()
        let html = try Self.hostile(fixture.html,
            head: "<meta http-equiv=\"refresh\" content=\"0; url=\(base)/refresh\"><link rel=\"stylesheet\" href=\"\(base)/s.css\">"
                + "<style>@font-face{font-family:R;src:url(\"\(base)/f.woff2\")} main{font-family:R}</style>",
            body: "<p><img src=\"\(base)/i.png\"><a href=\"\(base)/link\">link</a></p>" + Self.injectingScript)
        let text = try await printedText(of: html)
        guard !text.contains("INJECTED") else { throw NativeCheckFailure.scriptRan }
        try Self.complete(text, fixture.textNodes)
    }

    // MARK: Link annotations

    /// Where the platform keeps link annotations (`kept`), their destinations are the builder's `href`s; where it keeps
    /// none, the PDF has no annotation at all, so a change of the platform's behaviour fails the check either way.
    public func linkAnnotations(kept: Bool) async throws {
        let fixture = try ContractFixture.rendered()
        let pdf = try await renderer.render(html: fixture.html, page: .a4)
        guard let document = PDFDocument(data: pdf.data) else { throw NativeCheckFailure.unreadablePDF }
        let annotations = (0..<document.pageCount).compactMap { document.page(at: $0) }.flatMap(\.annotations)
        guard kept else {
            guard annotations.isEmpty else { throw NativeCheckFailure.annotationsAppeared(count: annotations.count) }
            return
        }
        let found = annotations.map { annotation in
            (annotation.url ?? (annotation.action as? PDFActionURL)?.url).map(Self.normalised)
                ?? "no destination (\(annotation.type ?? "untyped"))"
        }
        let expected = Self.hrefs(in: fixture.html)
        guard !expected.isEmpty else { throw NativeCheckFailure.noHrefs }
        guard AnnotationDestinations.match(found: found, expected: expected) else {
            throw NativeCheckFailure.annotationsDiffer(found: found.sorted(), expected: expected.sorted())
        }
    }

    // MARK: Geometry

    /// The fixture's PDF has every line inside its page and tall enough to read, on every page the renderer reports.
    public func fixtureGeometry() async throws {
        let pdf = try await renderer.render(html: try ContractFixture.rendered().html, page: .a4)
        guard let layout = inspector.layout(of: pdf.data) else { throw NativeCheckFailure.unreadablePDF }
        let violations = GeometricCompleteness.violations(in: layout, minimumGlyphHeight: GeometricCompleteness.minimumGlyphHeight)
        guard violations.isEmpty else { throw NativeCheckFailure.geometry(violations) }
        guard layout.pages.count == pdf.pageCount else {
            throw NativeCheckFailure.pageCountDiffers(layout: layout.pages.count, rendered: pdf.pageCount)
        }
    }

    // MARK: Page breaks

    /// #467: the bundled design `name`, in its default palette and fonts, prints every `PageBreakDocument` of `body` whole
    /// on `PageBreakDocument.page` with no section's start (its title, or the head of its first entry) at a page's foot, no
    /// blank page, no line cut by a page's edge or hidden in its margin, every text node and no line outside its page; and
    /// the page count is the PDF's own.
    public func pageBreaks(design name: String, body: PageBreakDocument.Body) async throws {
        let design = try await Self.bundledDesign(name)
        try await pageBreaks(name, stylesheet: design.stylesheet, palette: design.manifest.defaultPalette.palette,
                             fonts: design.manifest.defaultFonts, body: body)
    }

    /// #467: the same for an imported design at the markup contract's limits for a section title, in the contract
    /// fixture's palette and the system fonts.
    public func pageBreaks(imported design: PageBreakDocument.LimitDesign, body: PageBreakDocument.Body) async throws {
        try await pageBreaks("imported-\(design.rawValue)", stylesheet: try ContractFixture.stylesheet(design.css),
                             palette: ContractFixture.palette, fonts: .system, body: body)
    }

    private func pageBreaks(_ name: String, stylesheet: ValidatedStylesheet, palette: Palette, fonts: FontScheme,
                            body: PageBreakDocument.Body) async throws {
        let headings = try HeadingsCatalog(source: BundleHeadingTableSource()).headings(for: "en")
        var faults: [Int: [PageBreakFault]] = [:]
        for lines in PageBreakDocument.summaryLines {
            let document = DocumentHTMLBuilder().render(PageBreakDocument.document(summaryLines: lines, body: body),
                                                        stylesheet: stylesheet, palette: palette, fonts: fonts, headings: headings)
            let pdf = try await renderer.render(html: document.html, page: PageBreakDocument.page)
            guard !pdf.truncated else {
                throw NativeCheckFailure.pageBreakDocumentTruncated(design: name, summaryLines: lines, requiredPages: pdf.requiredPages)
            }
            guard let layout = inspector.layout(of: pdf.data) else {
                throw NativeCheckFailure.unreadablePDF
            }
            guard layout.pages.count == pdf.pageCount else {
                throw NativeCheckFailure.pageCountDiffers(layout: layout.pages.count, rendered: pdf.pageCount)
            }
            let found = PageBreaks.faults(of: document, printedAs: layout, starts: PageBreakDocument.startLines(headings),
                                          page: PageBreakDocument.page)
            if !found.isEmpty { faults[lines] = found }
        }
        guard faults.isEmpty else { throw NativeCheckFailure.pageBreaks(design: name, body: body, faults: faults) }
    }

    // MARK: Layout

    /// #558: the layout of the bundled design `name` in `document`, in the design's default palette and fonts, as this
    /// renderer prints it on this platform and OS version.
    public func layoutReference(design name: String, document: LayoutDocument) async throws -> LayoutReference {
        let design = try await Self.bundledDesign(name)
        let rendered = try document.rendered(stylesheet: design.stylesheet, palette: design.manifest.defaultPalette.palette,
                                             fonts: design.manifest.defaultFonts)
        let pdf = try await renderer.render(html: rendered.html, page: document.page)
        guard !pdf.truncated else {
            throw NativeCheckFailure.layoutDocumentTruncated(design: name, document: document, requiredPages: pdf.requiredPages)
        }
        guard let layout = inspector.layout(of: pdf.data) else { throw NativeCheckFailure.unreadablePDF }
        guard layout.pages.count == pdf.pageCount else {
            throw NativeCheckFailure.pageCountDiffers(layout: layout.pages.count, rendered: pdf.pageCount)
        }
        return LayoutReference(kind: .running, osVersion: .running, design: name, document: document, layout: layout)
    }

    /// #558: compares the layout of the bundled design `name` in `document` with the stored reference of this kind of
    /// device and system version (the closest lower version when there is none), at 0.5 pt. The failure names the
    /// reference's kind and version and every line that moved, by how much.
    public func checkLayout(
        design name: String, document: LayoutDocument, against store: LayoutReferenceStore
    ) async throws {
        let found = try await layoutReference(design: name, document: document)
        let verdict = try store.verdict(of: found)
        guard verdict == .matches else {
            throw NativeCheckFailure.layoutDiffers(design: name, document: document, verdict: verdict.description)
        }
    }

    /// #558: writes the layout of the bundled design `name` in `document` into `folder`, in the folder of this kind of
    /// device and OS version.
    public func recordLayout(design name: String, document: LayoutDocument, into folder: URL) async throws {
        try LayoutRecording.write(try await layoutReference(design: name, document: document), into: folder)
    }

    // MARK: Step budget

    /// The completeness search on real documents (the fixture and the two separation designs) finds every node and uses
    /// at most a tenth of its budget. Prints the counts as `STEP-BUDGET <document>=<steps>` and returns them.
    @discardableResult
    public func stepBudget() async throws -> [String: Int] {
        var documents = [("fixture", try ContractFixture.rendered())]
        for design in SeparationDesign.allCases { documents.append((design.rawValue, try design.rendered())) }
        var steps: [String: Int] = [:]
        for (name, document) in documents {
            let report = DocumentCompleteness.report(in: try await printedText(of: document.html), expected: document.textNodes)
            print("STEP-BUDGET \(name)=\(report.steps)")
            steps[name] = report.steps
            guard report.missing.isEmpty else { throw NativeCheckFailure.incomplete(missing: report.missing) }
            guard !report.budgetExhausted, report.steps <= DocumentCompleteness.stepBudget / 10 else {
                throw NativeCheckFailure.budget(steps: report.steps, exhausted: report.budgetExhausted)
            }
        }
        return steps
    }

    // MARK: Helpers

    /// The bundled design `name`, validated.
    private static func bundledDesign(_ name: String) async throws -> ValidatedDesign {
        guard let package = try await BundleDesignSource().bundledPackages().first(where: { $0.name == name }) else {
            throw NativeCheckFailure.fixtureLacks(name)
        }
        return try DesignPackageValidator().validate(package.data)
    }

    private static var injectingScript: String { "<script>document.querySelector('main').append('INJECTED')</script>" }

    /// Renders `html` on A4 and reads its text back with PDFKit.
    private func printedText(of html: String) async throws -> String {
        let pdf = try await renderer.render(html: html, page: .a4)
        guard let text = inspector.text(of: pdf.data) else { throw NativeCheckFailure.unreadablePDF }
        return text
    }

    /// Renders the fixture with what `attack` adds for a listener's base URL, and shows that nothing connected to the
    /// listener: a later page without the rules makes a request first, which closes the window, and the PDF is complete.
    private func makesNoConnection(_ attack: (String) -> (head: String, body: String)) async throws {
        let listener = try LoopbackListener()
        defer { listener.stop() }
        let base = try await listener.start()
        let fixture = try ContractFixture.rendered()
        let parts = attack(base)
        let text = try await printedText(of: try Self.hostile(fixture.html, head: parts.head, body: parts.body))
        guard try await laterPageMakesARequest() else { throw NativeCheckFailure.controlMadeNoRequest }
        guard listener.count == 0 else { throw NativeCheckFailure.requestEscaped(connections: listener.count) }
        try Self.complete(text, fixture.textNodes)
    }

    /// `html` with `head` added at the end of its head and `body` at the end of its main element.
    private static func hostile(_ html: String, head: String, body: String) throws -> String {
        try replacing("</main>", with: body + "</main>", in: try replacing("</head>", with: head + "</head>", in: html))
    }

    /// `html` with its one occurrence of `marker` replaced; a fixture without it, or with two, cannot make the case.
    private static func replacing(_ marker: String, with replacement: String, in html: String) throws -> String {
        guard html.components(separatedBy: marker).count == 2 else { throw NativeCheckFailure.fixtureLacks(marker) }
        return html.replacingOccurrences(of: marker, with: replacement)
    }

    private static func complete(_ text: String, _ nodes: [String]) throws {
        let missing = DocumentCompleteness.missing(in: text, expected: nodes)
        guard missing.isEmpty else { throw NativeCheckFailure.incomplete(missing: missing) }
    }

    /// The destinations of the builder's links, unescaped and normalised as PDFKit reports them.
    private static func hrefs(in html: String) -> [String] {
        html.matches(of: /href="([^"]+)"/).compactMap { match in
            let raw = String(match.output.1).replacingOccurrences(of: "&quot;", with: "\"").replacingOccurrences(of: "&#39;", with: "'")
                .replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&amp;", with: "&")
            return URL(string: raw).map(normalised)
        }
    }

    /// A URL as a string with an empty path written `/`: PDFKit reports `https://ada.example` as `https://ada.example/`.
    private static func normalised(_ url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url.absoluteString }
        if components.host != nil, components.path.isEmpty { components.path = "/" }
        return components.string ?? url.absoluteString
    }
}
#endif
