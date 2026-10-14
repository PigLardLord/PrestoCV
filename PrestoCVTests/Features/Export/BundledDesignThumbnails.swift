import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore
@testable import CVPDFExporter

/// Regenerates the preview image of each bundled design, which the template carousel of the export sheet shows.
///
/// It is not a check of the code, and it does nothing unless `PRESTOCV_REGENERATE_THUMBNAILS=1` is set: the real renderer
/// makes the PDF of the example CV with the options of the export sheet, and its first page, one pixel per point,
/// goes into `previewImageBase64` of the package in `CVPDFExporter/Resources/Templates/Bundled`. The rest of the file
/// is left as it is. See "Regenerating the thumbnails" in `CVPDFExporter/TEMPLATE_SYSTEM_ARCHITECTURE.md`.
@Suite("Bundled design thumbnails", .serialized)
struct BundledDesignThumbnails {

    private static let isRequested = ProcessInfo.processInfo.environment["PRESTOCV_REGENERATE_THUMBNAILS"] == "1"

    /// The size of a thumbnail: the A4 page in points
    static let longerSide: CGFloat = 842

    private static var bundledDesigns: URL {
        URL(fileURLWithPath: #filePath).resolvingSymlinksInPath()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("CVPDFExporter/Resources/Templates/Bundled", isDirectory: true)
    }

    @Test("write the thumbnail of a design from the real renderer", .enabled(if: isRequested), .timeLimit(.minutes(2)),
          arguments: ["professional", "modern", "minimal"])
    func regenerate(design: String) async throws {
        let environment = try await ExportTestEnvironment.make()
        defer { environment.cleanUp() }
        let service = environment.makeService()
        let options = await environment.exportOptions(for: design)
        let example = CVDocumentAdapter().convertToCVModel(from: SampleCVData.complete)

        let exported = try await service.export(cv: example, templateId: design, options: options)
        let pdf = try Data(contentsOf: exported.url)
        let png = try #require(await PDFThumbnail.pngData(from: pdf, longerSide: Self.longerSide))

        let file = Self.bundledDesigns.appendingPathComponent("\(design).mcvt")
        let package = try String(contentsOf: file, encoding: .utf8)
        let field = try NSRegularExpression(pattern: #"("previewImageBase64"\s*:\s*")[^"]*(")"#)
        let range = NSRange(package.startIndex..., in: package)
        #expect(field.numberOfMatches(in: package, range: range) == 1, "\(design).mcvt has one previewImageBase64")

        let replaced = field.stringByReplacingMatches(
            in: package, range: range, withTemplate: "$1\(png.base64EncodedString())$2"
        )
        try replaced.write(to: file, atomically: true, encoding: .utf8)
    }
}
