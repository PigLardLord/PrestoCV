import Foundation
import PDFKit
import UIKit

/// A small picture of the first page of a PDF
enum PDFThumbnail {

    /// The longer side of the picture, in pixels: enough for the share sheet on a 3x screen
    static let longerSide: CGFloat = 256

    /// - Parameter longerSide: The longer side of the picture, in pixels
    /// - Returns: The first page as PNG data, or nil when the data is not a PDF with a page
    @MainActor
    static func pngData(from pdf: Data, longerSide: CGFloat = PDFThumbnail.longerSide) -> Data? {
        guard let page = PDFDocument(data: pdf)?.page(at: 0) else { return nil }
        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0 else { return nil }

        let scale = longerSide / max(bounds.width, bounds.height)
        let size = CGSize(width: (bounds.width * scale).rounded(), height: (bounds.height * scale).rounded())

        // One pixel per point, whatever the screen: the size of the picture does not depend on the device
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            // PDF space has its origin at the bottom left
            context.cgContext.translateBy(x: 0, y: size.height)
            context.cgContext.scaleBy(x: scale, y: -scale)
            context.cgContext.translateBy(x: -bounds.minX, y: -bounds.minY)
            page.draw(with: .mediaBox, to: context.cgContext)
        }
        return image.pngData()
    }
}
