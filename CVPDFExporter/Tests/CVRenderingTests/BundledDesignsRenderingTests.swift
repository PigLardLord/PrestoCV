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
        "minimal@1.1.0": "02fa1a03cf8c63eb44c541882ccc52a9e5878395e1640d32397151c4697f7ec5",
        "modern@1.1.0": "d41791a6cc1b331459fec039efad319589c7d00f39878764c518596954238721",
        "professional@1.1.0": "5d97d8a6c63e811b48521a4bd971d943ecfa7a2a2be0a0023282157ef431f8b7",
    ]

    static func packages() async throws -> [(name: String, data: Data, design: ValidatedDesign)] {
        try await BundleDesignSource().bundledPackages().map { ($0.name, $0.data, try DesignPackageValidator().validate($0.data)) }
    }

    /// The standard vectors, with lengths of 32 bytes and more (the length field then takes two bytes) and two blocks.
    @Test("SHA-256 is the standard one", arguments: [
        ("", "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"),
        ("abc", "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"),
        (String(repeating: "a", count: 55), "9f4390f8d30c2dd92ec9f095b65e2b9ae9b0a925a5258e241c9f1e910f734318"),
        ("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq", "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"),
        (String(repeating: "a", count: 1000), "41edece42d63e8d9bf515a9ba6932e1c20cbc9f5a5d134645adb5db1b9737ea3"),
    ])
    func sha256(text: String, hex: String) {
        #expect(SHA256.hex(Data(text.utf8)) == hex, "\(text.utf8.count) bytes")
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
