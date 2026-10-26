import Foundation
import Testing

/// A test that renders a view off screen does it with `ImageRenderer.render`: it draws the view with Core Graphics into
/// a context of its own, or reads only the size the view is laid out at. The image of an `ImageRenderer` (`cgImage`,
/// `uiImage`, `nsImage`) is drawn on the GPU, which waits a bounded time for the Metal pipelines it needs: on a freshly
/// erased simulator, while the Metal compiler is busy, the wait can run out and the image comes back empty.
@Suite("Off-screen rendering in tests - views drawn by Core Graphics, not by the GPU")
struct OffscreenRenderingTests {

    @Test("No test takes the image of an ImageRenderer: it renders the view with render(rasterizationScale:renderer:)")
    func testsRenderWithCoreGraphics() throws {
        let files = try RepositorySources.testFiles()
        try #require(files.contains { $0.path.hasPrefix("PrestoCVTests/") && $0.text.contains("ImageRenderer") },
                     "The tests that render views are in the repository")

        let offending = try files.flatMap { file in try Self.imageReads(in: file.text).map { "\(file.path):\($0)" } }
        #expect(offending.isEmpty, "Render these views with ImageRenderer.render, into a CGContext of the test's own:\n\(offending.joined(separator: "\n"))")
    }

    @Test("The scan finds every image taken in a file that uses an ImageRenderer, and none in another file", arguments: [
        ("let renderer = ImageRenderer(content: view)\nlet image = renderer.cgImage", [2]),
        ("var r: ImageRenderer<Text>? = ImageRenderer(content: Text(\"A\"))\nlet size = r!.uiImage?.size", [2]),
        ("let image = SwiftUI.ImageRenderer(\n    content: view\n)\n.nsImage", [4]),
        ("func pixels(_ renderer: ImageRenderer<some View>) -> CGImage? { renderer.cgImage }", [1]),
        ("let renderer = ImageRenderer(content: view)\nlet photo = UIImage(named: \"photo\")?.cgImage", [2]),
        ("let renderer = ImageRenderer(content: view)\nrenderer.render(rasterizationScale: 2) { _, render in render(context) }", []),
        ("// ImageRenderer(content: view).cgImage\nlet text = \"ImageRenderer(content: view).cgImage\"", []),
        ("let image = UIImage(named: \"photo\")?.cgImage", []),
    ])
    func scanFindsTheImagesOfRenderers(source: String, lines: [Int]) throws {
        #expect(try Self.imageReads(in: source) == lines)
    }

    /// The lines of a source, from 1, whose code takes an image, if its code uses an `ImageRenderer` anywhere. A renderer
    /// can reach the image through a property, a parameter or a chain of calls over several lines, which a scan of text
    /// can't follow: in a file that renders views, no image is taken at all.
    static func imageReads(in source: String) throws -> [Int] {
        let renderer = try NSRegularExpression(pattern: #"\bImageRenderer\b"#)
        let image = try NSRegularExpression(pattern: #"\.(?:cgImage|uiImage|nsImage)\b"#)
        guard source.contains("ImageRenderer") else { return [] }
        let code = SwiftCode(source).skeleton.joined(separator: "\n")
        guard renderer.firstMatch(in: code, range: NSRange(code.startIndex..., in: code)) != nil else { return [] }
        return code.components(separatedBy: "\n").enumerated().compactMap { index, line in
            image.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) == nil ? nil : index + 1
        }
    }
}
