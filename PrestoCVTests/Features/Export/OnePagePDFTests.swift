import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore
@testable import CVPDFExporter

extension RealRendererSuites {
    /// A short CV that runs over one page is printed on one page, with the spacing of its design tightened and its
    /// small lists set along a line, instead of leaving its last sections alone on a second page. A CV that no tightening
    /// brings onto one page is printed as its design lays it out: its pages, and where they break, are what they were.
    @Suite("Short CVs on one page", .serialized, .timeLimit(.minutes(20)))
    struct OnePagePDFTests {

        static let designs = ["professional", "modern", "minimal"]

        /// A CV that is short enough to come onto one page in every design
        struct ShortCase {
            let label: String
            let cv: CVModel
            /// Texts from its first and its last sections that must be in the PDF whatever the pagination
            let markers: [String]
        }

        static let shortCases: [ShortCase] = EverydayCVs.all.map { ShortCase(label: $0.label, cv: $0.cv, markers: $0.markers) }
            + [ShortCase(label: ShortCVs.trailingLists.label, cv: ShortCVs.trailingLists.cv, markers: ShortCVs.trailingLists.markers)]

        /// Every CV of the suite, to print in every design: the CVs of the product review, the invented ones, the planted
        /// ones of the pagination tests, and the samples of the app in each of its languages
        static func allCVs() async throws -> [(label: String, cv: CVModel)] {
            var cvs = EverydayCVs.all.map { ($0.label, $0.cv) }
            cvs += [(ShortCVs.trailingLists.label, ShortCVs.trailingLists.cv), (ShortCVs.tooLongForOnePage.label, ShortCVs.tooLongForOnePage.cv)]
            cvs += PlantedCVs.paginated.map { ($0.label, $0.cv) }
            for language in BundledSamples.languages {
                cvs += try await BundledSamples.load(language: language).map { ($0.label, $0.cv) }
            }
            return cvs
        }

        private static func layout(_ label: String, _ cv: CVModel, design: String, fit: RenderedLayouts.Fit = .standard) async throws -> PDFLayout {
            try await RenderedLayouts.shared.layout(label: label, cv: cv, design: design, fit: fit)
        }

        /// The titles of the sections in every language of the designs, as PDFKit reads them back: in lower case
        private static let allTitles: Set<String> = {
            let placeholders = ["work_experience", "education", "skills", "languages", "certifications", "social_links", "interests"]
            return Set(DocumentLanguage.allCases.flatMap { language in
                placeholders.map { TemplateLocalizer(locale: Locale(identifier: language.rawValue)).localize(template: "{{i18n_\($0)}}").lowercased() }
            })
        }()

        // MARK: - One page

        @Test("a short CV takes one page in every design", arguments: designs)
        func shortCVsTakeOnePage(design: String) async throws {
            for short in Self.shortCases {
                let layout = try await Self.layout(short.label, short.cv, design: design)

                #expect(layout.pageCount == 1, "\(short.label) in \(design): \(layout.summary)")
                #expect(layout.missing(markers: short.markers).isEmpty, "\(short.label) in \(design) lost: \(layout.missing(markers: short.markers))")
            }
        }

        // MARK: - The case of the product review

        @Test("the lists that a design leaves alone on a second page come back onto the first", arguments: ["professional", "minimal"])
        func trailingListsComeBackOntoTheFirstPage(design: String) async throws {
            let short = ShortCVs.trailingLists

            // As the design lays it out: the first page ends with a fifth of its height empty, and the second holds the lists
            let own = try await Self.layout(short.label, short.cv, design: design, fit: .disabled)
            #expect(own.pageCount == 2, "\(design): \(own.summary)")
            #expect(own.fill(ofPage: 1) <= 0.85, "\(design): \(own.summary)")
            let secondPage = own.pages.last?.text.lowercased() ?? ""
            for title in ["languages", "profiles", "interests"] {
                #expect(secondPage.contains(title), "\(design): the second page has no \(title)")
            }
            for title in ["work experience", "education", "skills", "certifications"] {
                #expect(!secondPage.contains(title), "\(design): the second page has \(title)")
            }

            // The tightening alone, as the renderer had it before the compact step, still leaves two pages
            let tightened = try await Self.layout(short.label, short.cv, design: design, fit: .tighteningOnly)
            #expect(tightened.pageCount == 2, "\(design): \(tightened.summary)")

            let printed = try await Self.layout(short.label, short.cv, design: design)
            #expect(printed.pageCount == 1, "\(design): \(printed.summary)")
            #expect(printed.missing(markers: short.markers).isEmpty, "\(design) lost: \(printed.missing(markers: short.markers))")
        }

        // MARK: - A CV that does not fit

        @Test("a CV of two pages that no step brings onto one page keeps its pages, as its design lays them out", arguments: designs)
        func aCVThatDoesNotFitIsPrintedAsItIs(design: String) async throws {
            let short = ShortCVs.tooLongForOnePage
            let own = try await Self.layout(short.label, short.cv, design: design, fit: .disabled)
            let printed = try await Self.layout(short.label, short.cv, design: design)

            #expect(own.pageCount == 2, "\(design): \(own.summary)")
            #expect(printed.pageCount == 2, "\(design): \(printed.summary)")
            #expect(printed.pages.map(\.text) == own.pages.map(\.text), "\(design): the pages are not those of the design's own layout")
            #expect(printed.fill(ofPage: 1) >= 0.80, "\(design): \(printed.summary)")
            #expect(printed.missing(markers: short.markers).isEmpty, "\(design) lost: \(printed.missing(markers: short.markers))")
        }

        // MARK: - Long CVs

        @Test("a CV that does not come onto one page has the pages and the page breaks of its design's own layout", arguments: designs)
        func longCVsAreUnchanged(design: String) async throws {
            var compared = 0
            for (label, cv) in try await Self.allCVs() {
                let own = try await Self.layout(label, cv, design: design, fit: .disabled)
                let printed = try await Self.layout(label, cv, design: design)
                if own.pageCount == 2 && printed.pageCount == 1 { continue }   // brought onto one page: the tests above hold it

                #expect(printed.pageCount == own.pageCount, "\(label) in \(design): \(own.summary) became \(printed.summary)")
                #expect(printed.pages.map { $0.lines.first?.text } == own.pages.map { $0.lines.first?.text },
                        "\(label) in \(design): the pages start with other lines")
                #expect(printed.pages.map(\.text) == own.pages.map(\.text), "\(label) in \(design): the pages hold other text")
                compared += own.pageCount > 1 ? 1 : 0
            }
            #expect(compared >= 30, "\(design): only \(compared) CVs of more than one page were compared")
        }

        // MARK: - Headings

        @Test("a section title is never left alone at the foot of a page, whatever the CV", arguments: designs)
        func titlesStayWithTheirText(design: String) async throws {
            for (label, cv) in try await Self.allCVs() {
                let layout = try await Self.layout(label, cv, design: design)

                #expect(layout.titlesWithoutText(Self.allTitles).isEmpty, "\(label) in \(design): \(layout.titlesWithoutText(Self.allTitles))")
            }
        }

        // MARK: - Readability

        @Test("a CV brought onto one page keeps the size of its text, its side margins and 10 mm at its foot", arguments: designs)
        func tighteningKeepsTheTextReadable(design: String) async throws {
            for short in Self.shortCases {
                let own = try await Self.layout(short.label, short.cv, design: design, fit: .disabled)
                let printed = try await Self.layout(short.label, short.cv, design: design)

                #expect(!printed.fontSizes.isEmpty)
                #expect(printed.fontSizes == own.fontSizes, "\(short.label) in \(design): the text is set in other sizes: \(own.fontSizes) became \(printed.fontSizes)")
                for page in 1...printed.pageCount {
                    #expect(printed.isInsideMargins(page: page, bottomMargin: CGFloat(OnePageFit.minimumBottomMargin)),
                            "\(short.label) in \(design), page \(page) has text outside the margins")
                }
                // PDFKit reads some lines of a design as overlapping where it wraps a tag: no more of them than before
                #expect(printed.overlappingLines().count <= own.overlappingLines().count, "\(short.label) in \(design): \(printed.overlappingLines())")
            }
        }
    }
}
