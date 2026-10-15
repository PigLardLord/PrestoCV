import Testing
import SwiftUI
@testable import PrestoCV

@Suite("BarButtonContent Tests - bar buttons that leave the title its room")
struct BarButtonContentTests {

    @Test("A bar button shows its words when the screen's text is at a regular size",
          arguments: [DynamicTypeSize.xSmall, .small, .medium, .large, .xLarge, .xxLarge, .xxxLarge])
    func wordsAtRegularSizes(size: DynamicTypeSize) {
        #expect(BarButtonContent.resolve(screenTextSize: size) == .words)
    }

    @Test("A bar button shows only its symbol when the screen's text is at an accessibility size",
          arguments: [DynamicTypeSize.accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5])
    func symbolAtAccessibilitySizes(size: DynamicTypeSize) {
        #expect(BarButtonContent.resolve(screenTextSize: size) == .symbol)
    }
}
