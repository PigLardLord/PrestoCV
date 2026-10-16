import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore
@testable import CVPDFExporter

/// A short CV that runs a few lines over one page is printed on one page, with the spacing of its design tightened
/// a little, instead of leaving its last sections alone on a second page. A CV that the tightening cannot bring onto
/// one page is printed as before.
@Suite("Short CVs on one page", .serialized, .timeLimit(.minutes(10)))
struct OnePagePDFTests {

    static let designs = ["professional", "modern", "minimal"]

    /// The pages each everyday CV takes, by design. With their own spacing, the English and the German CV run a fifth of
    /// a page over in Professional and Minimal, the Italian one two fifths: that is more than the tightening takes back.
    static let expectedPages: [String: [String: Int]] = [
        "nurse-en": ["professional": 1, "modern": 1, "minimal": 1],
        "nurse-it": ["professional": 2, "modern": 1, "minimal": 2],
        "nurse-de": ["professional": 1, "modern": 1, "minimal": 1]
    ]

    // MARK: - Rendering

    private static func layout(of cv: CVModel, design: String) async throws -> PDFLayout {
        let environment = try await ExportTestEnvironment.make()
        defer { environment.cleanUp() }
        let service = environment.makeService()
        let options = await environment.exportOptions(for: design)
        let exported = try await service.export(cv: cv, templateId: design, options: options)

        let margins = (top: CGFloat(options.margins.top), left: CGFloat(options.margins.left),
                       bottom: CGFloat(options.margins.bottom), right: CGFloat(options.margins.right))
        let layout = try #require(PDFLayout(pdf: exported.url, margins: margins), "\(design) did not make a readable PDF")
        #expect(layout.pageCount == exported.pageCount, "\(design): the export reports \(exported.pageCount) pages")
        return layout
    }

    // MARK: - One page

    @Test("a short CV that fits on one page, with its spacing a little tighter, takes one page", arguments: designs)
    func shortCVsTakeOnePage(design: String) async throws {
        for everyday in EverydayCVs.all {
            let layout = try await Self.layout(of: everyday.cv, design: design)

            #expect(layout.pageCount == Self.expectedPages[everyday.label]?[design], "\(everyday.label) in \(design): \(layout.summary)")
            #expect(layout.blankPageNumbers.isEmpty, "\(everyday.label) in \(design) has blank pages: \(layout.summary)")
            for page in 1...layout.pageCount {
                #expect(layout.isInsideMargins(page: page), "\(everyday.label) in \(design), page \(page) has text outside the margins")
            }
            #expect(layout.missing(markers: everyday.markers).isEmpty, "\(everyday.label) in \(design) lost: \(layout.missing(markers: everyday.markers))")
        }
    }

    // MARK: - Longer CVs

    @Test("a CV that the tightening cannot bring onto one page fills its first page and goes on to a second", arguments: designs)
    func longerCVsKeepTheirPagination(design: String) async throws {
        for everyday in EverydayCVs.all where Self.expectedPages[everyday.label]?[design] == 2 {
            let layout = try await Self.layout(of: everyday.cv, design: design)

            #expect(layout.pageCount == 2, "\(everyday.label) in \(design): \(layout.summary)")
            #expect(layout.fill(ofPage: 1) >= 0.80, "\(everyday.label) in \(design): \(layout.summary)")
        }
    }
}
