import Testing
import Foundation
@testable import CVPDFExporter

@Suite("One page fit")
struct OnePageFitTests {

    @Test("only a CV of two pages is printed again with its spacing tightened", arguments: [(1, false), (2, true), (3, false), (8, false)])
    func triesTighteningTwoPagesOnly(pageCount: Int, tries: Bool) {
        #expect(OnePageFit().triesTightening(pageCount: pageCount) == tries)
    }

    @Test("the tightened print is kept only when it takes one page", arguments: [(1, true), (2, false), (3, false)])
    func keepsTightenedOnOnePageOnly(pageCount: Int, keeps: Bool) {
        #expect(OnePageFit().keepsTightened(pageCount: pageCount) == keeps)
    }

    @Test("every bundled design says how it tightens its spacing onto one page", arguments: ["professional", "modern", "minimal"])
    func bundledDesignsTighten(id: String) throws {
        let url = try #require(
            Bundle.module.url(forResource: id, withExtension: "mcvt", subdirectory: "Templates/Bundled"),
            "Bundled template '\(id)' should be in the module bundle"
        )
        let package = try JSONDecoder().decode(TemplatePackage.self, from: Data(contentsOf: url))

        #expect(package.cssContent.contains(".\(OnePageFit.className)"), "\(id) has no rules for .\(OnePageFit.className)")
    }
}
