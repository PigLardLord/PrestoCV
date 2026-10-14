import Testing
import Foundation
@testable import CVPDFExporter

/// The preview image of each bundled design, which the template carousel shows
@Suite("Bundled design thumbnails")
struct BundledThumbnailTests {

    private static let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

    /// The width and the height that the header of a PNG states, which are the 32-bit integers after the signature
    /// and the name of the header chunk
    private static func size(ofPNG data: Data) -> (width: Int, height: Int)? {
        let bytes = [UInt8](data)
        guard bytes.count >= 24, Array(bytes.prefix(8)) == pngSignature else { return nil }

        func integer(at offset: Int) -> Int {
            bytes[offset..<offset + 4].reduce(0) { $0 << 8 | Int($1) }
        }
        return (integer(at: 16), integer(at: 20))
    }

    @Test("the preview image is an A4 page at one pixel per point", arguments: ["professional", "modern", "minimal"])
    func previewImageIsAnA4Page(id: String) throws {
        let url = try #require(
            Bundle.module.url(forResource: id, withExtension: "mcvt", subdirectory: "Templates/Bundled"),
            "Bundled template '\(id)' should be in the module bundle"
        )
        let package = try JSONDecoder().decode(TemplatePackage.self, from: Data(contentsOf: url))
        let preview = try #require(package.embeddedPreviewBase64.flatMap { Data(base64Encoded: $0) }, "\(id) has a preview image")

        let size = try #require(Self.size(ofPNG: preview), "The preview image of \(id) is a PNG")
        #expect(size.width == 595, "\(id) is \(size.width) pixels wide")
        #expect(size.height == 842, "\(id) is \(size.height) pixels high")
    }
}
