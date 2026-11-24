import Testing
import Foundation
import PrestoCVDomain
import PrestoCVWorkflowPorts
import PrestoCVIntegration
import CVDocumentModel
import CVDesignCatalog
import CVRendering
import CVRenderingTestSupport
import CVBundledHeadings
import Synchronization

// MARK: Doubles

/// Renders like the fake and remembers the page it was asked to print on.
private actor SpyRenderer: PDFRendering {
    private(set) var pages: [PageSetup] = []
    private let inner = FakePDFRenderer()
    func render(html: String, page: PageSetup) async throws -> RenderedPDF {
        pages.append(page)
        return try await inner.render(html: html, page: page)
    }
}

/// A renderer that prints something other than what it was given: a PDF that lacks the document's texts.
private struct DroppingRenderer: PDFRendering {
    func render(html: String, page: PageSetup) async throws -> RenderedPDF {
        try await FakePDFRenderer().render(html: "<p>nothing of the document</p>", page: page)
    }
}

private struct CancellingRenderer: PDFRendering {
    func render(html: String, page: PageSetup) async throws -> RenderedPDF { throw CancellationError() }
}

private struct RendererFailure: Error {}

private struct FailingRenderer: PDFRendering {
    func render(html: String, page: PageSetup) async throws -> RenderedPDF { throw RendererFailure() }
}

private struct UnreadableInspector: PDFLayoutInspecting {
    func layout(of data: Data) -> PDFLayout? { nil }
    func pageCount(of data: Data) -> Int? { nil }
    func text(of data: Data) -> String? { nil }
}

/// Reads text and page count like the Linux inspector, and answers `layout` as given: the geometry a test wants to check.
private struct FixedLayoutInspector: PDFLayoutInspecting {
    let fixed: PDFLayout?
    func pageCount(of data: Data) -> Int? { MinimalPDFInspector().pageCount(of: data) }
    func text(of data: Data) -> String? { MinimalPDFInspector().text(of: data) }
    func layout(of data: Data) -> PDFLayout? { fixed }
}

private let pageBox = PDFBox(x: 0, y: 0, width: 595, height: 842)

private func layout(_ lines: [PDFTextLine]) -> PDFLayout { PDFLayout(pages: [pageBox], lines: lines) }

private func line(_ box: PDFBox, glyph: Double? = 10) -> PDFTextLine {
    PDFTextLine(pageIndex: 0, text: "line", box: box, glyphHeight: glyph)
}

/// Whether each call of a long step ran on the main actor, in the order of the calls.
private final class ThreadRecord: Sendable {
    private let threads = Mutex<[Bool]>([])
    var onMainActor: [Bool] { threads.withLock { $0 } }
    func record() {
        let onMainActor = MainActorProbe.isOnTheMainActor
        threads.withLock { $0.append(onMainActor) }
    }
}

/// Reads the bundled headings and records the thread of each read.
private struct ThreadRecordingHeadings: HeadingTableSource {
    let threads: ThreadRecord
    private let inner = BundleHeadingTableSource()
    func index() throws -> Data { threads.record(); return try inner.index() }
    func table(_ tag: String) throws -> Data? { threads.record(); return try inner.table(tag) }
}

/// Inspects like the minimal inspector and records the thread of each look at the PDF.
private struct ThreadRecordingInspector: PDFLayoutInspecting {
    let threads: ThreadRecord
    private let inner = MinimalPDFInspector()
    func layout(of data: Data) -> PDFLayout? { threads.record(); return inner.layout(of: data) }
    func pageCount(of data: Data) -> Int? { threads.record(); return inner.pageCount(of: data) }
    func text(of data: Data) -> String? { threads.record(); return inner.text(of: data) }
}

private struct BrokenHeadingSource: HeadingTableSource {
    struct Broken: Error {}
    func index() throws -> Data { throw Broken() }
    func table(_ tag: String) throws -> Data? { throw Broken() }
}

private func workflow(renderer: any PDFRendering = FakePDFRenderer(), inspector: any PDFLayoutInspecting = MinimalPDFInspector(),
                      source: any HeadingTableSource = BundleHeadingTableSource(),
                      policy: ExportPolicy = .standard) throws -> ExportCVWorkflow {
    ExportCVWorkflow(renderer: renderer, inspector: inspector, headings: HeadingsCatalog(source: source),
                     style: DocumentStyle(stylesheet: try ContractFixture.stylesheet(), palette: ContractFixture.palette, fonts: .system),
                     policy: policy)
}

private func language(_ tag: String) -> DocumentLanguage {
    guard let language = DocumentLanguage(tag) else { preconditionFailure("language") }
    return language
}

private func text(of outcome: ExportOutcome) -> String { MinimalPDFInspector().text(of: outcome.pdf) ?? "" }

@Suite("Export CV workflow")
struct ExportCVWorkflowTests {
    @Test("a full CV exports to a complete PDF that holds every field of the document")
    func exportsEveryField() async throws {
        let outcome = try await workflow().export(Fixtures.fullCV(), language: language("it"))
        #expect(!outcome.truncated)
        #expect(outcome.pageCount == outcome.requiredPages)
        let pdf = text(of: outcome)
        for expected in ["Ada Lovelace", "Analytical Engineer", "ada@example.com", "Babbage & Co", "Poetry", "Swift Certified", "github.com/ada"] {
            #expect(pdf.contains(expected), "\(expected) is missing from the PDF")
        }
    }

    @MainActor
    @Test("the headings are read and the PDF is checked off the main actor, also when the sheet asks from it (R19)")
    func exportRunsOffTheMainActor() async throws {
        let headings = ThreadRecord(), inspector = ThreadRecord()
        let export = try workflow(inspector: ThreadRecordingInspector(threads: inspector),
                                  source: ThreadRecordingHeadings(threads: headings))

        _ = try await export.export(Fixtures.fullCV(), language: language("it"))

        #expect(!headings.onMainActor.isEmpty && !headings.onMainActor.contains(true))
        #expect(!inspector.onMainActor.isEmpty && !inspector.onMainActor.contains(true))
    }

    @Test("a multi-line summary and description export complete, each line in the PDF")
    func multiLineText() async throws {
        var cv = Fixtures.fullCV()
        var personal = cv.personal
        personal.summary = "First summary line\nSecond summary line"
        cv.setPersonalDetails(personal)
        var sections = cv.sections
        sections.experiences = [Experience(role: "Analyst", company: "Babbage", description: "- led a team\r\n- shipped the Engine")]
        cv.setSections(sections)
        let outcome = try await workflow().export(cv, language: language("it"))
        let pdf = text(of: outcome)
        for line in ["First summary line", "Second summary line", "led a team", "shipped the Engine"] {
            #expect(pdf.contains(line), "\(line) is missing from the PDF")
        }
    }

    @Test("a certification without a name exports complete, with its issuer, year, address and description in the PDF")
    func unnamedCertification() async throws {
        var cv = Fixtures.fullCV()
        var sections = cv.sections
        sections.certifications = [Certification(name: " ", issuer: "Royal Society", issued: Fixtures.date(2017),
                                                 link: Fixtures.link("https://notes.example/g"), description: "Notes on the Engine")]
        cv.setSections(sections)
        let outcome = try await workflow().export(cv, language: language("it"))
        let pdf = text(of: outcome)
        for expected in ["Royal Society", "2017", "notes.example/g", "Notes on the Engine"] {
            #expect(pdf.contains(expected), "\(expected) is missing from the PDF")
        }
    }

    @Test("the headings follow the language of the export, not the CV's own", arguments: ["it", "en", "de", "fr", "es", "pt"])
    func headingsFollowTheLanguage(tag: String) async throws {
        let headings = try HeadingsCatalog(source: BundleHeadingTableSource()).headings(for: tag)
        let outcome = try await workflow().export(Fixtures.fullCV(), language: language(tag))
        #expect(text(of: outcome).localizedCaseInsensitiveContains(headings.experience))
        #expect(text(of: outcome).localizedCaseInsensitiveContains(headings.skills))
    }

    @Test("a regional tag finds the table of its language")
    func regionalTag() async throws {
        let outcome = try await workflow().export(Fixtures.fullCV(), language: language("pt-BR"))
        #expect(!outcome.truncated)
    }

    @Test("a language without headings is unsupportedLanguage, never English")
    func unsupportedLanguage() async throws {
        await #expect(throws: ExportFailure.unsupportedLanguage) {
            try await workflow().export(Fixtures.fullCV(), language: language("sv"))
        }
    }

    @Test("a CV without a name is notReady, and nothing is rendered")
    func notReady() async throws {
        let renderer = SpyRenderer()
        var cv = Fixtures.fullCV()
        cv.setPersonalDetails(PersonalDetails(fullName: "   "))
        await #expect(throws: ExportFailure.notReady) { try await workflow(renderer: renderer).export(cv, language: language("it")) }
        #expect(await renderer.pages.isEmpty)
    }

    @Test("a document the exporter refuses is invalidDocument")
    func invalidDocument() async throws {
        var cv = Fixtures.fullCV()
        var personal = cv.personal
        personal.summary = String(repeating: "x", count: 20_000)   // over the exporter's bound for one text
        cv.setPersonalDetails(personal)
        await #expect(throws: ExportFailure.invalidDocument) { try await workflow().export(cv, language: language("it")) }
    }

    @Test("a PDF that lacks the document's texts is incomplete, with the number of texts missing")
    func incomplete() async throws {
        do {
            _ = try await workflow(renderer: DroppingRenderer()).export(Fixtures.fullCV(), language: language("it"))
            Issue.record("expected incomplete")
        } catch let failure as ExportFailure {
            guard case .incomplete(let missing) = failure else { Issue.record("got \(failure)"); return }
            #expect(missing > 0)
        }
    }

    @Test("a PDF that cannot be read back is renderingFailed")
    func unreadable() async throws {
        await #expect(throws: ExportFailure.renderingFailed) {
            try await workflow(inspector: UnreadableInspector()).export(Fixtures.fullCV(), language: language("it"))
        }
    }

    @Test("a heading table that cannot be read is renderingFailed, not unsupportedLanguage")
    func brokenHeadings() async throws {
        await #expect(throws: ExportFailure.renderingFailed) {
            try await workflow(source: BrokenHeadingSource()).export(Fixtures.fullCV(), language: language("it"))
        }
    }

    @Test("a CV longer than the policy allows is a truncated outcome with both page counts")
    func truncated() async throws {
        let policy = ExportPolicy(pageWidth: 595.28, pageHeight: 841.89, margin: 43, maxPages: 1)
        let outcome = try await workflow(policy: policy).export(Fixtures.fullCV(), language: language("it"))
        #expect(outcome.truncated)
        #expect(outcome.pageCount == 1)
        #expect(outcome.requiredPages > 1)
    }

    @Test("the page the renderer prints on comes from the export policy")
    func pageFromPolicy() async throws {
        let renderer = SpyRenderer()
        let policy = ExportPolicy(pageWidth: 500, pageHeight: 700, margin: 30, maxPages: 7)
        _ = try await workflow(renderer: renderer, policy: policy).export(Fixtures.fullCV(), language: language("it"))
        let pages = await renderer.pages
        #expect(pages == [PageSetup(widthPoints: 500, heightPoints: 700, maxPages: 7, verticalMarginPoints: 30)])
    }

    @Test("an error of the renderer is renderingFailed, whatever its type")
    func rendererError() async throws {
        await #expect(throws: ExportFailure.renderingFailed) {
            try await workflow(renderer: FailingRenderer()).export(Fixtures.fullCV(), language: language("it"))
        }
    }

    @Test("a CV that misses a field the export requires is notReady", arguments: Array(ExportReadiness.requiredFields))
    func missingRequiredField(field: ExportReadiness.Field) async throws {
        var cv = Fixtures.fullCV()
        var personal = cv.personal
        switch field {
        case .name: personal.fullName = " \n"
        case .email: personal.email = nil
        case .phone: personal.phone = nil
        }
        cv.setPersonalDetails(personal)
        await #expect(throws: ExportFailure.notReady) { try await workflow().export(cv, language: language("it")) }
    }

    @Test("cancellation passes through unchanged")
    func cancellation() async throws {
        await #expect(throws: CancellationError.self) {
            try await workflow(renderer: CancellingRenderer()).export(Fixtures.fullCV(), language: language("it"))
        }
    }

    @Test("exporting does not change the CV and gives the same PDF twice")
    func repeatable() async throws {
        let cv = Fixtures.fullCV()
        let export = try workflow()
        let first = try await export.export(cv, language: language("it"))
        let second = try await export.export(cv, language: language("it"))
        #expect(first == second)
        #expect(cv == Fixtures.fullCV())
    }

    // MARK: Geometry (R8, #80)

    private func export(layout: PDFLayout?, policy: ExportPolicy = .standard,
                        renderer: any PDFRendering = FakePDFRenderer()) async throws -> ExportOutcome {
        try await workflow(renderer: renderer, inspector: FixedLayoutInspector(fixed: layout), policy: policy)
            .export(Fixtures.fullCV(), language: language("it"))
    }

    @Test("a line below the bottom edge fails with textNotVisible")
    func belowBottom() async throws {
        await #expect(throws: ExportFailure.textNotVisible(lines: 1)) {
            try await export(layout: layout([line(PDFBox(x: 40, y: -5, width: 100, height: 10))]))
        }
    }

    @Test("a line past the right edge fails with textNotVisible")
    func pastRight() async throws {
        await #expect(throws: ExportFailure.textNotVisible(lines: 1)) {
            try await export(layout: layout([line(PDFBox(x: 500, y: 100, width: 100, height: 10))]))
        }
    }

    @Test("a glyph under the minimum fails with textNotVisible, and the count is the lines at fault")
    func glyphTooSmall() async throws {
        let ok = line(PDFBox(x: 40, y: 100, width: 100, height: 10))
        let small = line(PDFBox(x: 40, y: 80, width: 100, height: 5), glyph: 5)
        await #expect(throws: ExportFailure.textNotVisible(lines: 2)) { try await export(layout: layout([ok, small, small])) }
    }

    @Test("a line of unknown glyph height fails with textNotVisible")
    func unknownGlyph() async throws {
        await #expect(throws: ExportFailure.textNotVisible(lines: 1)) {
            try await export(layout: layout([line(PDFBox(x: 40, y: 100, width: 100, height: 10), glyph: nil)]))
        }
    }

    @Test("a line exactly on the edges, with glyphs exactly at the minimum, passes")
    func onTheEdge() async throws {
        let edge = line(PDFBox(x: 0, y: 0, width: 595, height: 842), glyph: GeometricCompleteness.minimumGlyphHeight)
        let outcome = try await export(layout: layout([edge]))
        #expect(!outcome.truncated)
    }

    @Test("a layout that cannot be read is renderingFailed")
    func noLayout() async throws {
        await #expect(throws: ExportFailure.renderingFailed) { try await export(layout: nil) }
    }

    @Test("a truncated PDF skips the text and geometry checks")
    func truncatedSkipsGeometry() async throws {
        let policy = ExportPolicy(pageWidth: 595.28, pageHeight: 841.89, margin: 43, maxPages: 1)
        let outcome = try await export(layout: layout([line(PDFBox(x: 40, y: -50, width: 100, height: 10), glyph: 1)]), policy: policy)
        #expect(outcome.truncated)
    }

    @Test("an incomplete text is reported before the geometry")
    func incompleteFirst() async throws {
        await #expect {
            try await export(layout: layout([line(PDFBox(x: 40, y: -5, width: 100, height: 10))]), renderer: DroppingRenderer())
        } throws: { error in
            guard let failure = error as? ExportFailure, case .incomplete = failure else { return false }
            return true
        }
    }
}
