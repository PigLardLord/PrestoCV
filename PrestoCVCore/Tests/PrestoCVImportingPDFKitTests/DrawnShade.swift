#if canImport(PDFKit)
import CoreGraphics
import CoreText
import Foundation
import Testing

/// A band of grey that the PDFKit tests draw behind a line of text, as a table row or a highlight does, and a hairline
/// they draw across one, as an underline does.
enum DrawnShade {

    /// How far the band reaches into the box of the words of the line.
    enum Reach {
        /// From below the baseline to a fifth of the size above it: the band crosses the boxes of the words.
        case foot
        /// Past the whole box of the words: the words stand on a ground of their own.
        case box
    }

    /// Fills the band, of the grey level `gray` (0 black, 1 white), behind `line` as it will be drawn from `origin`.
    static func fill(_ gray: CGFloat, reach: Reach, behind line: CTLine, at origin: CGPoint, size: CGFloat, in context: CGContext) {
        let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        let (below, height) = switch reach {
        case .foot: (size * 0.25, size * 0.45)
        case .box: (size * 0.4, size * 1.3)
        }
        context.saveGState()
        context.setFillColor(gray: gray, alpha: 1)
        context.fill(CGRect(x: origin.x - 2, y: origin.y - below, width: width + 4, height: height))
        context.restoreGState()
    }

    /// Where a hairline crosses the box of the words of a line.
    enum Hairline: CaseIterable, CustomTestStringConvertible {
        /// Under the baseline, as an underline.
        case under
        /// Through the letters, as a line struck through them.
        case through

        var testDescription: String {
            switch self {
            case .under: "an underline"
            case .through: "a line through the letters"
            }
        }

        /// The height of the hairline above the baseline, in sizes.
        var height: CGFloat {
            switch self {
            case .under: -0.12
            case .through: 0.3
            }
        }
    }

    /// Draws a black hairline of half a point across `line`, inside the box of its words.
    static func hairline(_ hairline: Hairline = .under, across line: CTLine, at origin: CGPoint, size: CGFloat, in context: CGContext) {
        let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        context.saveGState()
        context.setStrokeColor(gray: 0, alpha: 1)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: origin.x, y: origin.y + size * hairline.height))
        context.addLine(to: CGPoint(x: origin.x + width, y: origin.y + size * hairline.height))
        context.strokePath()
        context.restoreGState()
    }
}
#endif
