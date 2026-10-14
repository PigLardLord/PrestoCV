import Testing
import CoreGraphics
@testable import PrestoCV

@Suite("ReadableContentWidth Tests - the margins that keep a screen to a readable width")
struct ReadableContentWidthTests {

    private let readable = DesignTokens.Layout.readableContentWidth

    @Test("A screen that is not wider than the readable width gets no margin", arguments: [CGFloat(320), 430, 672])
    func narrowScreenHasNoMargin(width: CGFloat) {
        #expect(width <= readable)
        #expect(ReadableContentWidth.margin(forWidth: width) == 0)
    }

    @Test("A wider screen gets the same margin on both sides, so that the content is centred at the readable width")
    func wideScreenIsCentred() {
        let margin = ReadableContentWidth.margin(forWidth: readable + 200)

        #expect(margin == 100)
        #expect(2 * margin + readable == readable + 200)
    }

    @Test("The margin grows with the width of the screen, as on an iPad in portrait, in landscape and in Split View",
          arguments: [(CGFloat(1032), CGFloat(180)), (1376, 352), (694, 11)])
    func marginForIPadWidths(width: CGFloat, expected: CGFloat) {
        #expect(ReadableContentWidth.margin(forWidth: width) == expected)
    }

    @Test("A width that is not known yet gives no margin", arguments: [-1.0, 0, CGFloat.nan])
    func unknownWidthHasNoMargin(width: CGFloat) {
        #expect(ReadableContentWidth.margin(forWidth: width) == 0)
    }
}
