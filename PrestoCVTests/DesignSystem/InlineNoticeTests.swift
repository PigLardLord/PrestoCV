import Testing
import SwiftUI
@testable import PrestoCV

/// A notice can be the way to recover someone's edits, so its action is a target a finger can hit at every text size.
@Suite("InlineNotice Tests - the action is a target of at least 44 points")
struct InlineNoticeTests {

    @Test("The action of a notice is a target of at least 44 points each way")
    func actionTargetIsAtLeast44Points() {
        #expect(InlineNotice.minimumActionTarget >= 44)
    }

    @Test("The message and the action sit side by side at every size but the accessibility ones, where the action goes under the message")
    func layoutFollowsTheTextSize() {
        let regular: [DynamicTypeSize] = [.xSmall, .small, .medium, .large, .xLarge, .xxLarge, .xxxLarge]
        for size in regular {
            #expect(InlineNoticeLayout.resolve(textSize: size) == .sideBySide, "At \(size)")
        }
        let accessibility: [DynamicTypeSize] = [.accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5]
        for size in accessibility {
            #expect(InlineNoticeLayout.resolve(textSize: size) == .stacked, "At \(size)")
        }
    }
}
