import Foundation
import Testing

/// A test that reads the pixels of a view draws it with `ImageRenderer.render`, with Core Graphics, into a bitmap of its
/// own. The image of an `ImageRenderer` (`cgImage`, `uiImage`, `nsImage`) is drawn on the GPU, which waits a bounded time
/// for the Metal pipelines it needs: on a freshly erased simulator, while the Metal compiler is busy, the wait can run out
/// and the image comes back empty.
@Suite("Off-screen rendering in tests - pixels drawn by Core Graphics, not by the GPU")
struct OffscreenRenderingTests {

    /// The folders of the test code.
    static let testFolders = ["PrestoCVTests", "PrestoCVUITests", "PrestoCVCore/Tests", "CVPDFExporter/Tests", "CVGeneratorAI/Tests"]

    /// The tests that take the image of an `ImageRenderer` and read none of its pixels: the file, and what it reads.
    static let sizeOnly: [(path: String, reason: String)] = [
        ("PrestoCVTests/DesignSystem/WholeWordsTextSizeTests.swift", "the image's size, which the layout sets"),
    ]

    @Test("No test takes the image of an ImageRenderer to read its pixels: it draws the view with render(rasterizationScale:renderer:)")
    func testsDrawPixelsWithCoreGraphics() throws {
        let files = try Self.testFolders.flatMap { try RepositorySources.swiftFiles(in: $0) }
        try #require(files.contains { $0.text.contains("ImageRenderer") }, "The tests that render views are in the repository")

        let reads = try files.flatMap { file in try Self.imageReads(in: file.text).map { (path: file.path, line: $0) } }
        let offending = reads.filter { read in !Self.sizeOnly.contains { $0.path == read.path } }
        let stale = Self.sizeOnly.filter { entry in !reads.contains { $0.path == entry.path } }

        #expect(offending.isEmpty, "Draw these views with ImageRenderer.render into a CGContext:\n\(offending.map { "\($0.path):\($0.line)" }.joined(separator: "\n"))")
        #expect(stale.isEmpty, "These exceptions take no image of a renderer: \(stale.map(\.path))")
    }

    @Test("The scan finds the image of a renderer, named or not, and no other image", arguments: [
        ("let renderer = ImageRenderer(content: view)\nlet image = renderer.cgImage", [2]),
        ("var r = ImageRenderer(content: Text(\"A\"))\nr.scale = 2\nlet size = r.uiImage?.size", [3]),
        ("let image = ImageRenderer(content: view).nsImage", [1]),
        ("let renderer = ImageRenderer(content: view)\nrenderer.render(rasterizationScale: 2) { _, render in render(context) }", []),
        ("let renderer = ImageRenderer(content: view) // not renderer.cgImage", []),
        ("let image = UIImage(named: \"photo\")?.cgImage", []),
    ])
    func scanFindsTheImagesOfRenderers(source: String, lines: [Int]) throws {
        #expect(try Self.imageReads(in: source) == lines)
    }

    /// The lines of a source, from 1, whose code takes an image from an `ImageRenderer`: from a renderer the source names,
    /// or from one made on the same line.
    static func imageReads(in source: String) throws -> [Int] {
        let named = try NSRegularExpression(pattern: #"\b(?:let|var)\s+(\w+)\s*=\s*ImageRenderer\b"#)
        let names = named.matches(in: source, range: NSRange(source.startIndex..., in: source)).compactMap { match in
            Range(match.range(at: 1), in: source).map { #"\b"# + NSRegularExpression.escapedPattern(for: String(source[$0])) }
        }
        let renderers = (names + [#"\bImageRenderer\(.*\)"#]).joined(separator: "|")
        let image = try NSRegularExpression(pattern: #"(?:"# + renderers + #")\??\.(?:cgImage|uiImage|nsImage)\b"#)
        return source.components(separatedBy: .newlines).enumerated().compactMap { index, line in
            let code = line.components(separatedBy: "//").first ?? ""
            return image.firstMatch(in: code, range: NSRange(code.startIndex..., in: code)) == nil ? nil : index + 1
        }
    }
}
