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

private struct UnreadableInspector: PDFInspecting {
    func pageCount(of data: Data) -> Int? { nil }
    func text(of data: Data) -> String? { nil }
}

private struct BrokenHeadingSource: HeadingTableSource {
    struct Broken: Error {}
    func index() throws -> Data { throw Broken() }
    func table(_ tag: String) throws -> Data? { throw Broken() }
}

private func workflow(renderer: any PDFRendering = FakePDFRenderer(), inspector: any PDFInspecting = MinimalPDFInspector(),
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
}
