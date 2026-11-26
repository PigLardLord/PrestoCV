import Testing
import Foundation
import CVRendering
import CVRenderingTestSupport

@Suite("#558 · an iPhone, an iPad and a Mac place the same lines")
struct LayoutParityTests {
    static let version = OSVersion(major: 27, minor: 0)

    /// A line of a made-up layout: its text, its page and the bottom of its box.
    typealias Line = (text: String, page: Int, y: Double)

    static func reference(
        _ kind: DeviceKind, document: LayoutDocument = .contractFixture, _ lines: [Line]
    ) -> LayoutReference {
        let page = PDFBox(x: 0, y: 0, width: 595, height: 842)
        let lines = lines.map { line in
            PDFTextLine(pageIndex: line.page, text: line.text, box: PDFBox(x: 36, y: line.y, width: 100, height: 12),
                        glyphHeight: 10)
        }
        return LayoutReference(kind: kind, osVersion: version, design: "minimal", document: document,
                               layout: PDFLayout(pages: [page, page], lines: lines))
    }

    static let base: [Line] = [("Ada", 0, 780), ("Profile", 0, 740), ("Experience", 1, 780)]

    static func all(iphone: [Line] = base, ipad: [Line] = base, mac: [Line] = base) -> [DeviceKind: [LayoutReference]] {
        [.iphone: [reference(.iphone, iphone)], .ipad: [reference(.ipad, ipad)], .mac: [reference(.mac, mac)]]
    }

    @Test("three kinds that place every line alike have no difference")
    func same() {
        #expect(LayoutParity.differences(Self.all()).isEmpty)
    }

    @Test("lines up to 2.5 points apart pass, and 2.6 points apart fail, naming the two kinds and the line")
    func tolerance() {
        let within = Self.all(mac: [("Ada", 0, 777.5), ("Profile", 0, 742.5), ("Experience", 1, 780)])
        #expect(LayoutParity.differences(within).isEmpty)
        let beyond = Self.all(mac: [("Ada", 0, 777.4), ("Profile", 0, 740), ("Experience", 1, 780)])
        let differences = LayoutParity.differences(beyond)
        #expect(differences.count == 2)
        #expect(differences.contains {
            $0.hasPrefix("iphone 27.0 against mac 27.0, minimal contract-fixture: ")
                && $0.contains("\"Ada\" moved by x +0.00, y -2.60")
        })
        #expect(differences.contains { $0.hasPrefix("ipad 27.0 against mac 27.0") })
    }

    @Test("a line on another page, a missing line, an extra line and another order fail whatever the distance")
    func strict() {
        let otherPage = LayoutParity.differences(
            Self.all(ipad: [("Ada", 0, 780), ("Profile", 1, 740), ("Experience", 1, 780)]))
        #expect(otherPage.count == 2 && otherPage.allSatisfy { $0.contains("\"Profile\" is on page") })
        let missing = LayoutParity.differences(Self.all(mac: [("Ada", 0, 780), ("Experience", 1, 780)]))
        #expect(missing.contains { $0.contains("\"Profile\" is missing") })
        let extra = LayoutParity.differences(Self.all(iphone: Self.base + [("Skills", 1, 700)]))
        #expect(extra.contains { $0.contains("\"Skills\" is missing") })
        let order = LayoutParity.differences(Self.all(mac: [("Profile", 0, 740), ("Ada", 0, 780), ("Experience", 1, 780)]))
        #expect(!order.isEmpty)
    }

    @Test("another page count fails")
    func pageCount() {
        var references = Self.all()
        references[.ipad]?[0].layout.pages.removeLast()
        #expect(LayoutParity.differences(references).contains {
            $0.contains("2 pages in the reference, 1 found") || $0.contains("1 pages in the reference, 2 found")
        })
    }

    @Test("a kind with no reference fails once the others have some, and a document one kind lacks fails")
    func incomplete() {
        var references = Self.all()
        references[.ipad] = nil
        #expect(LayoutParity.differences(references).contains { $0.hasPrefix("no layout reference of ipad") })
        references = Self.all()
        references[.mac]?.append(Self.reference(.mac, document: .pageBreaks, Self.base))
        #expect(LayoutParity.differences(references).contains {
            $0 == "minimal page-breaks has a layout of mac and none of iphone"
        })
    }

    @Test("with no reference recorded at all there is nothing to compare, and no difference")
    func nothingRecorded() {
        #expect(LayoutParity.differences([:]).isEmpty)
    }

    /// The references stored in the repository, as this target's bundle holds them (R16). Every kind has some, so a
    /// lost folder or a bundle without it fails here instead of comparing nothing.
    @Test("the newest recorded layouts of an iPhone, an iPad and a Mac agree on pages, lines and order, within 2.5 points")
    func recorded() throws {
        let stored = LayoutReferenceStore(resources: try #require(Bundle.module.resourceURL))
        let newest = try LayoutParity.newest(in: stored)
        #expect(DeviceKind.allCases.allSatisfy { !(newest[$0] ?? []).isEmpty }, "\(stored.folder.path): \(newest.keys)")
        let differences = LayoutParity.differences(newest)
        #expect(differences.isEmpty, Comment(rawValue: differences.joined(separator: "\n")))
    }
}
