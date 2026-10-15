import Testing
import SwiftUI
@testable import PrestoCV

@Suite("ScreenTitlePlacement Tests - a title that stays whole at the largest text sizes")
struct ScreenTitlePlacementTests {

    private let accessibilitySizes: [DynamicTypeSize] = [
        .accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5,
    ]
    private let regularSizes: [DynamicTypeSize] = [
        .xSmall, .small, .medium, .large, .xLarge, .xxLarge, .xxxLarge,
    ]

    @Test("A screen with a large title keeps it at the sizes the bar can hold")
    func largeTitleStaysLarge() {
        for size in regularSizes {
            #expect(ScreenTitlePlacement.resolve(wantsLargeTitle: true, dynamicTypeSize: size) == .large, "\(size)")
        }
    }

    @Test("A screen with an inline title keeps it at the sizes the bar can hold")
    func inlineTitleStaysInline() {
        for size in regularSizes {
            #expect(ScreenTitlePlacement.resolve(wantsLargeTitle: false, dynamicTypeSize: size) == .inline, "\(size)")
        }
    }

    @Test("At an accessibility size the title wraps in the middle of the bar, whichever title the screen wants")
    func accessibilitySizesWrapTheTitle() {
        for size in accessibilitySizes {
            #expect(ScreenTitlePlacement.resolve(wantsLargeTitle: true, dynamicTypeSize: size) == .wrapped, "\(size)")
            #expect(ScreenTitlePlacement.resolve(wantsLargeTitle: false, dynamicTypeSize: size) == .wrapped, "\(size)")
        }
    }
}
