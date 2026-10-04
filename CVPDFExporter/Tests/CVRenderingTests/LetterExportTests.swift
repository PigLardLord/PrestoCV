import Testing
import Foundation
@testable import CVDocumentModel
@testable import CVRendering
import CVRenderingTestSupport

/// A letter that arrives at its page: one A4 page, complete, or an error (ADR 0019, ADR 0011). The fake renderer lays out forty
/// lines to a page, which is enough to tell a letter that fits from one that does not; whether a real letter fits in real fonts is
/// verified on the native renderers, with `LetterExportContract`.
@Suite("ADR 0019 · a letter is one A4 page, or an error")
struct LetterExportTests {
    func export(_ letter: LetterDocument, with renderer: any PDFRendering = FakePDFRenderer(), inspector: any PDFInspecting = MinimalPDFInspector()) async throws -> Data {
        try await LetterPDFExport(renderer: renderer, inspector: inspector).export(letter)
    }

    /// As many paragraphs as a letter may have: more than a page holds.
    func overlong(_ letter: LetterDocument = letterFixture) -> LetterDocument {
        var long = letter
        long.body = (1...LetterDocumentValidator.maxParagraphs).map { "Paragraph \($0) says something about the role." }
        return long
    }

    @Test("the page is A4, one page, with the margins of every page")
    func pageSetup() {
        #expect(LetterPDFExport.page == PageSetup(widthPoints: 595, heightPoints: 842, maxPages: 1))
        #expect(LetterPDFExport.page.verticalMarginPoints == PageSetup.a4.verticalMarginPoints)
    }

    @Test("a letter that fits is exported as one page that holds every text node, in each of the six languages", arguments: LetterConventionsTests.languages)
    func fits(language: String) async throws {
        var letter = letterFixture
        letter.language = language
        let pdf = try await export(letter)
        let inspector = MinimalPDFInspector()
        #expect(inspector.pageCount(of: pdf) == 1)
        let text = try #require(inspector.text(of: pdf))
        #expect(DocumentCompleteness.missing(in: text, expected: try render(letter).textNodes).isEmpty)
        #expect(text.contains(try #require(LetterConventionsTests.expected.first { $0.language == language }).valedictions[1]))
    }

    /// The pages a letter needed, from the error.
    func requiredPages(_ letter: LetterDocument, with renderer: any PDFRendering = FakePDFRenderer()) async throws -> Int {
        let failure = try await #require(throws: LetterPDFExport.Failure.self) { _ = try await export(letter, with: renderer) }
        guard case .doesNotFitOnOnePage(let pages) = failure else { Issue.record("expected doesNotFitOnOnePage, got \(failure)"); return 0 }
        return pages
    }

    @Test("a letter that cannot fit is a typed error, never a page that is cut off")
    func doesNotFit() async throws {
        #expect(try await requiredPages(overlong()) >= 2)
    }

    /// Cuts the letter to one page and says how many it needed: three.
    struct NeedsThreePages: PDFRendering {
        func render(html: String, page: PageSetup) async throws -> RenderedPDF {
            let pdf = try await FakePDFRenderer().render(html: html, page: page)
            return RenderedPDF(data: pdf.data, pageCount: 1, requiredPages: 3)
        }
    }
    @Test("the error says how many pages the letter needed")
    func pagesNeeded() async throws {
        #expect(try await requiredPages(letterFixture, with: NeedsThreePages()) == 3)
    }

    @Test("a letter that the validator accepts and that is too long for the page is the export's error, not an invalid document", arguments: LetterConventionsTests.languages)
    func validButTooLong(language: String) async throws {
        let letter = ContractFixture.overlongLetter(language: language)
        try LetterDocumentValidator.validate(letter)
        #expect(letter.body.count == LetterDocumentValidator.maxParagraphs && letter.attachments.count == LetterDocumentValidator.maxAttachments)
        #expect(try await requiredPages(letter) >= 2)
    }

    @Test("a letter with line breaks in its paragraphs is exported complete: the check ignores spacing")
    func multiLine() async throws {
        var letter = letterFixture
        letter.body[0] = "First line\nSecond line\n\nThird"
        letter.closing = "Thanks,\nAda"
        let pdf = try await export(letter)
        let text = try #require(MinimalPDFInspector().text(of: pdf))
        #expect(DocumentCompleteness.missing(in: text, expected: try render(letter).textNodes).isEmpty)
    }

    /// Cuts the document to its first page and says nothing, as a renderer that does not report truncation would (#8).
    struct SilentlyTruncating: PDFRendering {
        func render(html: String, page: PageSetup) async throws -> RenderedPDF {
            let pdf = try await FakePDFRenderer().render(html: html, page: PageSetup(widthPoints: page.widthPoints, heightPoints: page.heightPoints, maxPages: 1))
            return RenderedPDF(data: pdf.data, pageCount: pdf.pageCount, requiredPages: pdf.pageCount)
        }
    }
    @Test("a renderer that cuts the letter and does not say so is caught by the completeness check")
    func silentTruncation() async throws {
        let failure = try await #require(throws: LetterPDFExport.Failure.self) { _ = try await export(overlong(), with: SilentlyTruncating()) }
        guard case .missing(let nodes) = failure else { Issue.record("expected missing text, got \(failure)"); return }
        #expect(nodes.contains("Certificato di laurea"))
    }

    /// Two pages, which the renderer reports as one.
    struct ClaimsOnePage: PDFRendering {
        func render(html: String, page: PageSetup) async throws -> RenderedPDF {
            let pdf = try await FakePDFRenderer().render(html: html, page: PageSetup(widthPoints: page.widthPoints, heightPoints: page.heightPoints, maxPages: 10))
            return RenderedPDF(data: pdf.data, pageCount: 1, requiredPages: 1)
        }
    }
    @Test("a renderer that claims one page for two is read from the PDF itself")
    func misreportedPages() async throws {
        #expect(try await requiredPages(overlong(), with: ClaimsOnePage()) >= 2)
    }

    struct DroppingContent: PDFRendering {
        func render(html: String, page: PageSetup) async throws -> RenderedPDF {
            try await FakePDFRenderer().render(html: html.replacingOccurrences(of: "Certificato di laurea", with: ""), page: page)
        }
    }
    @Test("a PDF that loses a text node is incomplete, and names it")
    func losesContent() async throws {
        await #expect(throws: LetterPDFExport.Failure.missing(["Certificato di laurea"])) { _ = try await export(letterFixture, with: DroppingContent()) }
    }

    struct NotAPDF: PDFRendering {
        func render(html: String, page: PageSetup) async throws -> RenderedPDF { RenderedPDF(data: Data("not a PDF".utf8), pageCount: 1, requiredPages: 1) }
    }
    @Test("what cannot be read as a PDF is an error, not a page")
    func unreadable() async throws {
        await #expect(throws: LetterPDFExport.Failure.unreadablePDF) { _ = try await export(letterFixture, with: NotAPDF()) }
    }

    struct Unreachable: PDFRendering { func render(html: String, page: PageSetup) async throws -> RenderedPDF { Issue.record("rendered"); throw CancellationError() } }
    @Test("a letter that cannot be rendered never reaches the renderer", arguments: [("ja", "language is not supported"), ("it", LetterDocumentValidator.textReason)])
    func invalidNeverRendered(language: String, reason: String) async throws {
        var letter = letterFixture
        letter.language = language
        if language == "it" { letter.body[0] = "\u{202E}evil" }
        await #expect(throws: LetterBuildFailure.invalid(reason)) { _ = try await export(letter, with: Unreachable()) }
    }

    @Test("a cancelled export ends in a cancellation, never in a domain error")
    func cancellation() async {
        let cancelled: Bool = await withTaskGroup(of: Bool.self) { group in
            group.cancelAll()
            group.addTask {
                do { _ = try await export(letterFixture); return false } catch is CancellationError { return true } catch { return false }
            }
            return await group.next() ?? false
        }
        #expect(cancelled)
    }

    @Test("the fake renderer passes the letter contract, in each of the six languages")
    func contract() async throws {
        try await LetterExportContract.verify(FakePDFRenderer(), inspector: MinimalPDFInspector())
    }

    struct LosesContent: PDFRendering {
        func render(html: String, page: PageSetup) async throws -> RenderedPDF {
            try await FakePDFRenderer().render(html: html.replacingOccurrences(of: "Allegati", with: ""), page: page)
        }
    }
    @Test("a renderer that loses content, cuts silently or cannot be read fails the letter contract", arguments: [0, 1, 2])
    func contractFails(which: Int) async {
        let renderers: [any PDFRendering] = [LosesContent(), SilentlyTruncating(), NotAPDF()]
        await #expect(throws: (any Error).self) { try await LetterExportContract.verify(renderers[which], inspector: MinimalPDFInspector()) }
    }
}
