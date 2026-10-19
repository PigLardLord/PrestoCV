import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore
@testable import CVPDFExporter
import struct PrestoCVDomain.ExportPolicy

/// How the bundled designs paginate. The planted CVs are exported with the real renderer and the options of the
/// export sheet, and the PDFs are read back with PDFKit: where the text of every page is says how the page was
/// filled and where it was cut.
///
/// Before the designs let sections and entries flow from one page to the next, a short CV took three pages in
/// Professional with the last one almost empty, a CV of four entries had a blank last page in Minimal, and ten entries
/// of 1,300 characters were refused at 14, 11 and 13 pages in Professional, Modern and Minimal.
@Suite("PDF pagination of the bundled designs", .serialized, .timeLimit(.minutes(10)))
struct PDFPaginationTests {

    static let designs = ["professional", "modern", "minimal"]

    /// The number of pages of each planted CV, by design. A CV is planted so that its last page is neither almost
    /// empty nor almost full, which keeps these numbers the same on every version of the system. A CV of two pages
    /// also runs over by more than the tightening of `OnePageFit` takes back, and is printed with its design's spacing.
    static let expectedPages: [String: [String: Int]] = [
        "short-en": ["professional": 2, "modern": 1, "minimal": 2],
        "short-it": ["professional": 2, "modern": 1, "minimal": 2],
        "short-de": ["professional": 2, "modern": 1, "minimal": 2],
        "short-es": ["professional": 2, "modern": 1, "minimal": 2],
        "short-fr": ["professional": 2, "modern": 1, "minimal": 2],
        "short-pt": ["professional": 2, "modern": 1, "minimal": 2],
        "links": ["professional": 2, "modern": 1, "minimal": 2],
        "contacts": ["professional": 1, "modern": 1, "minimal": 1],
        "real4x5": ["professional": 3, "modern": 2, "minimal": 3],
        "real9x5": ["professional": 4, "modern": 3, "minimal": 4],
        "real11x5": ["professional": 5, "modern": 4, "minimal": 5],
        "long5x4": ["professional": 5, "modern": 4, "minimal": 5],
        "long10x4": ["professional": 8, "modern": 7, "minimal": 8]
    ]

    /// The headings of the planted CVs that are in English
    private static let englishTitles: Set<String> = [
        "work experience", "education", "skills", "languages", "certifications", "profiles", "interests"
    ]

    /// A page is used up to this much of its height before the text goes on to the next one. The planted CVs fill
    /// their pages to 86% at the least: a few points are lost where a small section, or the first lines of an
    /// entry, are kept together and go to the next page as a whole.
    private static let minimumFill = 0.80

    // MARK: - Rendering

    /// What a render leaves for the tests: the PDF itself is not kept
    private actor RenderedLayouts {
        private var layouts: [String: PDFLayout] = [:]

        func layout(of planted: PlantedCVs.Planted, design: String) async throws -> PDFLayout {
            let key = "\(planted.label)/\(design)"
            if let known = layouts[key] { return known }

            let environment = try await ExportTestEnvironment.make()
            defer { environment.cleanUp() }
            let service = environment.makeService()
            let options = await environment.exportOptions(for: design)
            let exported = try await service.export(cv: planted.cv, templateId: design, options: options)

            let margins = (top: CGFloat(options.margins.top), left: CGFloat(options.margins.left),
                           bottom: CGFloat(options.margins.bottom), right: CGFloat(options.margins.right))
            let layout = try #require(PDFLayout(pdf: exported.url, margins: margins), "\(key) is not a readable PDF")
            #expect(layout.pageCount == exported.pageCount, "\(key): the export reports \(exported.pageCount) pages")
            layouts[key] = layout
            return layout
        }
    }

    private static let renders = RenderedLayouts()

    private static func layout(of planted: PlantedCVs.Planted, design: String) async throws -> PDFLayout {
        try await renders.layout(of: planted, design: design)
    }

    // MARK: - Page count

    @Test("every planted CV takes the number of pages it should", arguments: designs)
    func pageCounts(design: String) async throws {
        for planted in PlantedCVs.paginated {
            let layout = try await Self.layout(of: planted, design: design)

            #expect(layout.pageCount == Self.expectedPages[planted.label]?[design], "\(planted.label) in \(design): \(layout.summary)")
        }
    }

    @Test("ten entries of about 1,300 characters fit the page limit, and twenty-two entries of 2,000 do not", arguments: designs)
    func pageLimit(design: String) async throws {
        let longest = try #require(PlantedCVs.paginated.first { $0.label == "long10x4" })
        let layout = try await Self.layout(of: longest, design: design)
        #expect(layout.pageCount <= ExportPolicy.standard.maxPages, "\(design): \(layout.summary)")

        let environment = try await ExportTestEnvironment.make()
        defer { environment.cleanUp() }
        let service = environment.makeService()
        let options = await environment.exportOptions(for: design)
        let tooLong = PlantedCVs.long(name: "Long 22", experiences: 22, paragraphs: 6)

        do {
            _ = try await service.export(cv: tooLong, templateId: design, options: options)
            Issue.record("A CV of 22 long entries should be refused")
        } catch PDFExportError.tooManyPages(let count, let limit) {
            #expect(limit == ExportPolicy.standard.maxPages)
            #expect(count > limit)
        }
    }

    // MARK: - Filling the pages

    @Test("no page is blank, and a page is filled before the text goes on to the next", arguments: designs)
    func pagesAreFilled(design: String) async throws {
        for planted in PlantedCVs.paginated {
            let layout = try await Self.layout(of: planted, design: design)

            #expect(layout.blankPageNumbers.isEmpty, "\(planted.label) in \(design) has blank pages: \(layout.summary)")
            for page in 1..<max(layout.pageCount, 1) {
                #expect(layout.fill(ofPage: page) >= Self.minimumFill, "\(planted.label) in \(design), page \(page): \(layout.summary)")
            }
        }
    }

    @Test("the last page of a planted CV is neither nearly empty nor nearly full, so its page count is the same on every version", arguments: designs)
    func lastPagesAreInTheMiddle(design: String) async throws {
        for planted in PlantedCVs.paginated {
            let layout = try await Self.layout(of: planted, design: design)

            let lastFill = layout.fill(ofPage: layout.pageCount)
            #expect((0.10...0.90).contains(lastFill), "\(planted.label) in \(design): the last page is \(Int(lastFill * 100))% full (\(layout.summary))")
        }
    }

    @Test("the text is inside the margins on every page, and none of it is lost", arguments: designs)
    func nothingIsClippedOrLost(design: String) async throws {
        for planted in PlantedCVs.paginated {
            let layout = try await Self.layout(of: planted, design: design)

            for page in 1...layout.pageCount {
                #expect(layout.isInsideMargins(page: page), "\(planted.label) in \(design), page \(page) has text outside the margins")
            }
            #expect(layout.missing(markers: planted.markers).isEmpty, "\(planted.label) in \(design) lost: \(layout.missing(markers: planted.markers))")
        }
    }

    // MARK: - Where the pages are cut

    @Test("a section title is never left alone at the foot of a page", arguments: designs)
    func titlesStayWithTheirText(design: String) async throws {
        for planted in PlantedCVs.paginated where planted.hasEnglishHeadings {
            let layout = try await Self.layout(of: planted, design: design)

            #expect(layout.titlesWithoutText(Self.englishTitles).isEmpty, "\(planted.label) in \(design): \(layout.titlesWithoutText(Self.englishTitles))")
        }
    }

    @Test("an entry is cut with at least three lines on each side", arguments: designs)
    func entriesAreNotCutShort(design: String) async throws {
        for planted in PlantedCVs.paginated {
            guard let titlePattern = planted.entryTitlePattern else { continue }
            let layout = try await Self.layout(of: planted, design: design)

            let early = layout.entriesCutTooEarly(titlePattern: titlePattern, stopAt: Self.englishTitles, minimum: 3)
            let late = layout.continuationsCutTooLate(titlePattern: titlePattern, stopAt: Self.englishTitles, minimum: 3, column: 0...330)
            #expect(early.isEmpty, "\(planted.label) in \(design): \(early)")
            #expect(late.isEmpty, "\(planted.label) in \(design): \(late)")
        }
    }

    // MARK: - Ratings and links

    @Test("the dots of a skill rating stay on one line", arguments: designs)
    func ratingsStayWhole(design: String) async throws {
        for planted in PlantedCVs.paginated {
            let layout = try await Self.layout(of: planted, design: design)

            #expect(layout.brokenRatings().isEmpty, "\(planted.label) in \(design): \(layout.brokenRatings())")
        }
    }

    @Test("a mark between two contact details is never at the start or the end of a line", arguments: designs)
    func contactSeparatorsStayBetweenItems(design: String) async throws {
        for planted in PlantedCVs.paginated {
            let layout = try await Self.layout(of: planted, design: design)

            #expect(layout.linesWithSeparatorAtAnEdge().isEmpty, "\(planted.label) in \(design): \(layout.linesWithSeparatorAtAnEdge())")
        }
    }

    @Test("a long web address breaks between its words, never in the middle of one", arguments: designs)
    func addressesBreakBetweenWords(design: String) async throws {
        let planted = try #require(PlantedCVs.paginated.first { $0.label == "links" })
        let layout = try await Self.layout(of: planted, design: design)

        for address in PlantedCVs.longLinkWords {
            #expect(layout.addressWordsCut(address).isEmpty, "\(design) cut the words \(layout.addressWordsCut(address)) of \(address)")
        }
    }
}
