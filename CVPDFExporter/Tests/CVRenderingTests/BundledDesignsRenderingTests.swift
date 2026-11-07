import Testing
import Foundation
import CVDocumentModel
import CVDesignCatalog
@testable import CVRendering
import CVRenderingTestSupport
import CVBundledDesigns
import CVBundledHeadings

/// What the bundled designs do to a document (#3, ADR 0011): they render it completely, they print the HTML reviewed in
/// the golden files, and a package changes only with a new version.
@Suite("The bundled designs render the fixture (#3)")
struct BundledDesignsRenderingTests {
    /// The SHA-256 of each bundled package, by `id@version`. The catalog's sync never replaces an installed design of the
    /// same version, so a changed package needs a new version: bump it in the manifest, then pin the new hash here.
    static let pins: [String: String] = [
        "minimal@1.1.0": "0d9cabe655afab2d7bd5c886391936efeb011c2195e5be9e93d4a5f5a7bc7d5f",
        "modern@1.1.0": "344f5e50d0985ea643a2ff67d777929a0e9e04562ac04b1e4e495e0993f7bf19",
        "professional@1.1.0": "bc3fd5c4a5a03017e6c2c21d94ba0da68a53863f8e6dbf4e3dd9a13e74f8736b",
    ]

    static func packages() async throws -> [(name: String, data: Data, design: ValidatedDesign)] {
        try await BundleDesignSource().bundledPackages().map { ($0.name, $0.data, try DesignPackageValidator().validate($0.data)) }
    }

    @Test("SHA-256 is the standard one")
    func sha256() {
        #expect(SHA256.hex(Data("abc".utf8)) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        #expect(SHA256.hex(Data()) == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }

    @Test("every bundled design passes the rendering gate with a complete PDF")
    func gate() async throws {
        let headings = try HeadingsCatalog(source: BundleHeadingTableSource()).headings(for: "it")
        let gate = FixtureRenderingGate(renderer: FakePDFRenderer(), inspector: MinimalPDFInspector(), fixture: ContractFixture.document,
                                        headings: headings, palette: ContractFixture.palette)
        let designs = try await Self.packages()
        #expect(designs.count == 3)
        for (name, _, design) in designs {
            do { try await gate.verify(design) } catch { Issue.record("\(name): \(error)") }
        }
    }

    @Test("each bundled package is pinned to its id and version: a change needs a new version (#3)")
    func pinned() async throws {
        let hashes = Dictionary(uniqueKeysWithValues: try await Self.packages().map { ("\($0.design.manifest.id)@\($0.design.manifest.version)", SHA256.hex($0.data)) })
        #expect(hashes == Self.pins)
    }

    @Test("golden output: the fixture renders exactly to the reviewed HTML of each design")
    func golden() async throws {
        let headings = try HeadingsCatalog(source: BundleHeadingTableSource()).headings(for: "it")
        for (name, _, design) in try await Self.packages() {
            let html = DocumentHTMLBuilder().build(ContractFixture.document, stylesheet: design.stylesheet, palette: ContractFixture.palette, headings: headings)
            try GoldenFile.updateIfRequested("design-\(name).html", with: html)
            let url = try #require(Bundle.module.url(forResource: "Golden/design-\(name)", withExtension: "html"), "no golden file for \(name)")
            #expect(html == (try String(contentsOf: url, encoding: .utf8)), "\(name)")
        }
    }
}
