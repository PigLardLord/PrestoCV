import Testing
import Foundation
import CVRendering
import CVRenderingTestSupport

@Suite("#558 · a layout reference written as JSON")
struct LayoutReferenceTests {
    static let reference = LayoutReference(
        platform: .ios, osVersion: OSVersion(major: 27, minor: 0), design: "minimal", document: .contractFixture,
        layout: PDFLayout(pages: [PDFBox(x: 0, y: 0, width: 595.2756, height: 841.8898)], lines: [
            PDFTextLine(pageIndex: 0, text: "Ada \"Lovelace\"", box: PDFBox(x: 36, y: 790.125, width: 120.5, height: -0.004), glyphHeight: 18),
            PDFTextLine(pageIndex: 0, text: "a\\b\tc\u{1}é", box: PDFBox(x: -1.5, y: 10.0049, width: 0.1, height: 9), glyphHeight: nil),
        ]))

    @Test("writes the reference's fields, then a page per line and a text line per line, in points rounded to 0.01")
    func text() {
        #expect(Self.reference.json() == """
            {
              "platform": "ios",
              "osVersion": "27.0",
              "design": "minimal",
              "document": "contract-fixture",
              "pages": [
                {"x": 0.00, "y": 0.00, "width": 595.28, "height": 841.89}
              ],
              "lines": [
                {"page": 0, "text": "Ada \\"Lovelace\\"", "x": 36.00, "y": 790.13, "width": 120.50, "height": 0.00, "glyphHeight": 18.00},
                {"page": 0, "text": "a\\\\b\\tc\\u0001é", "x": -1.50, "y": 10.00, "width": 0.10, "height": 9.00, "glyphHeight": null}
              ]
            }

            """)
    }

    @Test("reads back what it wrote, every value at its rounding")
    func roundTrip() throws {
        let read = try LayoutReference(json: Data(Self.reference.json().utf8))
        #expect(read.platform == .ios && read.osVersion == OSVersion(major: 27, minor: 0) && read.design == "minimal" && read.document == .contractFixture)
        #expect(read.layout.pages == [PDFBox(x: 0, y: 0, width: 595.28, height: 841.89)])
        #expect(read.layout.lines.map(\.text) == ["Ada \"Lovelace\"", "a\\b\tc\u{1}é"])
        #expect(read.layout.lines.map(\.box) == [PDFBox(x: 36, y: 790.13, width: 120.5, height: 0), PDFBox(x: -1.5, y: 10, width: 0.1, height: 9)])
        #expect(read.layout.lines.map(\.glyphHeight) == [18, nil])
        #expect(read.json() == Self.reference.json())
    }

    @Test("a layout with no page and no line is written and read back")
    func empty() throws {
        var reference = Self.reference
        reference.layout = PDFLayout(pages: [], lines: [])
        #expect(try LayoutReference(json: Data(reference.json().utf8)) == reference)
    }

    @Test("refuses a platform, a version or a document it does not know")
    func refusals() {
        let json = Self.reference.json()
        #expect(throws: LayoutReferenceError.unknownPlatform("android")) {
            try LayoutReference(json: Data(json.replacingOccurrences(of: "\"ios\"", with: "\"android\"").utf8))
        }
        #expect(throws: LayoutReferenceError.invalidOSVersion("27")) {
            try LayoutReference(json: Data(json.replacingOccurrences(of: "\"27.0\"", with: "\"27\"").utf8))
        }
        #expect(throws: LayoutReferenceError.unknownDocument("one-page")) {
            try LayoutReference(json: Data(json.replacingOccurrences(of: "\"contract-fixture\"", with: "\"one-page\"").utf8))
        }
    }

    @Test("files a reference by platform and version, then by design and document")
    func path() {
        #expect(Self.reference.path == "ios-27.0/minimal-contract-fixture.json")
    }

    @Test("an OS version is a major and a minor number, ordered as numbers", arguments: [
        ("27.0", OSVersion(major: 27, minor: 0)), ("26.10", OSVersion(major: 26, minor: 10)),
    ])
    func version(text: String, version: OSVersion) {
        #expect(OSVersion(text) == version && version.description == text)
    }

    @Test("a version that is not two numbers is refused", arguments: ["27", "27.0.1", "a.b", "27.", ".1", "-1.0", ""])
    func notAVersion(text: String) {
        #expect(OSVersion(text) == nil)
    }

    @Test("versions order by major, then minor")
    func order() {
        #expect(OSVersion(major: 26, minor: 10) > OSVersion(major: 26, minor: 5))
        #expect(OSVersion(major: 27, minor: 0) > OSVersion(major: 26, minor: 10))
    }

    static let folders = ["ios-26.5", "ios-27.0", "macos-27.2", "ios-27.2", "README.md", ".DS_Store", "ios-28", "watchos-27.0"]

    @Test("a run reads the references of its platform's closest version at or below its own", arguments: [
        (LayoutReference.Platform.ios, OSVersion(major: 27, minor: 1), OSVersion(major: 27, minor: 0)),
        (.ios, OSVersion(major: 27, minor: 2), OSVersion(major: 27, minor: 2)),
        (.ios, OSVersion(major: 30, minor: 0), OSVersion(major: 27, minor: 2)),
        (.macos, OSVersion(major: 28, minor: 0), OSVersion(major: 27, minor: 2)),
    ])
    func closest(platform: LayoutReference.Platform, running: OSVersion, read: OSVersion) {
        #expect(LayoutReference.closestVersion(platform, atOrBelow: running, among: Self.folders) == read)
    }

    @Test("a run older than every reference of its platform has none", arguments: [
        (LayoutReference.Platform.ios, OSVersion(major: 26, minor: 4)), (.macos, OSVersion(major: 27, minor: 1)),
    ])
    func noneBelow(platform: LayoutReference.Platform, running: OSVersion) {
        #expect(LayoutReference.closestVersion(platform, atOrBelow: running, among: Self.folders) == nil)
    }

    @Test("the newest references of each platform, and none without a folder")
    func newest() {
        #expect(LayoutReference.newestVersion(.ios, among: Self.folders) == OSVersion(major: 27, minor: 2))
        #expect(LayoutReference.newestVersion(.macos, among: Self.folders) == OSVersion(major: 27, minor: 2))
        #expect(LayoutReference.newestVersion(.ios, among: ["macos-27.2", "notes"]) == nil)
    }

    @Test("a run with no reference says how to record one, in the folder of its own version")
    func howToRecord() {
        let hint = "record it by running the layout tests with RECORD_LAYOUTS set to the absolute path of "
            + "CVPDFExporter/Tests/LayoutReferences (on the iOS simulator, TEST_RUNNER_RECORD_LAYOUTS for xcodebuild), "
            + "then review and commit the folder ios-26.5"
        #expect(LayoutReference.noReference(.ios, atOrBelow: OSVersion(major: 26, minor: 5))
            == "no layout reference for ios 26.5 or an earlier version: " + hint)
        #expect(LayoutReference.noReference(path: "ios-26.0/minimal-page-breaks.json", platform: .ios, running: OSVersion(major: 26, minor: 5))
            == "no layout reference ios-26.0/minimal-page-breaks.json: " + hint)
    }
}
