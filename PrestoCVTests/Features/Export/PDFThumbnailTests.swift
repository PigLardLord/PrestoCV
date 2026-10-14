import Testing
import Foundation
import PDFKit
import UIKit
@testable import PrestoCV

/// The picture of a PDF's first page, for the share sheet
@MainActor
@Suite("PDFThumbnail Tests")
struct PDFThumbnailTests {

    private func makePDF(pageSizes: [CGSize]) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSizes[0]))
        return renderer.pdfData { context in
            for size in pageSizes {
                context.beginPage(withBounds: CGRect(origin: .zero, size: size), pageInfo: [:])
                UIColor.black.setFill()
                context.fill(CGRect(x: 10, y: 10, width: 100, height: 20))
            }
        }
    }

    @Test("the picture keeps the page's proportions and its longer side is the size asked for")
    func keepsProportions() throws {
        // Given
        let pdf = makePDF(pageSizes: [CGSize(width: 595, height: 842)])

        // When
        let image = try #require(PDFThumbnail.pngData(from: pdf).flatMap(UIImage.init(data:)))

        // Then
        let longerSide = max(image.size.width, image.size.height) * image.scale
        #expect(longerSide == PDFThumbnail.longerSide)
        #expect(image.size.height > image.size.width)
        #expect(abs(image.size.width / image.size.height - 595.0 / 842.0) < 0.01)
    }

    @Test("a wide page gets a wide picture")
    func widePage() throws {
        // Given
        let pdf = makePDF(pageSizes: [CGSize(width: 842, height: 595)])

        // When
        let image = try #require(PDFThumbnail.pngData(from: pdf).flatMap(UIImage.init(data:)))

        // Then
        #expect(image.size.width > image.size.height)
        #expect(max(image.size.width, image.size.height) * image.scale == PDFThumbnail.longerSide)
    }

    @Test("the picture is of the first page")
    func firstPage() throws {
        // Given: a first page that is small, and a second that is not
        let pdf = makePDF(pageSizes: [CGSize(width: 300, height: 400), CGSize(width: 800, height: 400)])

        // When
        let image = try #require(PDFThumbnail.pngData(from: pdf).flatMap(UIImage.init(data:)))

        // Then
        #expect(abs(image.size.width / image.size.height - 300.0 / 400.0) < 0.01)
    }

    @Test("data that is not a PDF has no picture")
    func notAPDF() {
        #expect(PDFThumbnail.pngData(from: Data("not a pdf".utf8)) == nil)
        #expect(PDFThumbnail.pngData(from: Data()) == nil)
    }
}
