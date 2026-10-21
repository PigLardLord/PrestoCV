import Testing
import SwiftUI
@testable import PrestoCV

@Suite("EditorChrome Tests - how the editor spends the height it has")
struct EditorChromeTests {

    @Test("In portrait at the normal text size the tab bar stays put")
    func portraitKeepsTheTabBarAsItIs() {
        let chrome = EditorChrome(verticalSizeClass: .regular, dynamicTypeSize: .large)

        #expect(!chrome.minimizesTabBar)
    }

    @Test("In landscape the tab bar shrinks while scrolling")
    func landscapeGivesTheFormTheHeight() {
        let chrome = EditorChrome(verticalSizeClass: .compact, dynamicTypeSize: .large)

        #expect(chrome.minimizesTabBar)
    }

    @Test("At an accessibility size in portrait the tab bar shrinks while scrolling")
    func accessibilitySizeShrinksTheTabBar() {
        for size in [DynamicTypeSize.accessibility1, .accessibility3, .accessibility5] {
            let chrome = EditorChrome(verticalSizeClass: .regular, dynamicTypeSize: size)

            #expect(chrome.minimizesTabBar, "\(size)")
        }
    }

    @Test("A size class that is not known yet leaves the tab bar as it is")
    func unknownSizeClassLeavesTheTabBar() {
        let chrome = EditorChrome(verticalSizeClass: nil, dynamicTypeSize: .large)

        #expect(!chrome.minimizesTabBar)
    }
}
