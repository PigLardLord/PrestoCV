import Testing
import SwiftUI
@testable import PrestoCV

@Suite("EditorChrome Tests - how the editor spends the height it has")
struct EditorChromeTests {

    @Test("In portrait at the normal text size the export button stays below the form and the tab bar stays put")
    func portraitKeepsTheBarsAsTheyAre() {
        let chrome = EditorChrome(verticalSizeClass: .regular, dynamicTypeSize: .large)

        #expect(!chrome.exportsFromNavigationBar)
        #expect(!chrome.minimizesTabBar)
    }

    @Test("In landscape the export button moves into the navigation bar and the tab bar shrinks while scrolling")
    func landscapeGivesTheFormTheHeight() {
        let chrome = EditorChrome(verticalSizeClass: .compact, dynamicTypeSize: .large)

        #expect(chrome.exportsFromNavigationBar)
        #expect(chrome.minimizesTabBar)
    }

    @Test("At an accessibility size in portrait the tab bar shrinks while scrolling, and the export button stays below the form")
    func accessibilitySizeShrinksTheTabBar() {
        for size in [DynamicTypeSize.accessibility1, .accessibility3, .accessibility5] {
            let chrome = EditorChrome(verticalSizeClass: .regular, dynamicTypeSize: size)

            #expect(!chrome.exportsFromNavigationBar, "\(size)")
            #expect(chrome.minimizesTabBar, "\(size)")
        }
    }

    @Test("A size class that is not known yet leaves the bars as they are")
    func unknownSizeClassLeavesTheBars() {
        let chrome = EditorChrome(verticalSizeClass: nil, dynamicTypeSize: .large)

        #expect(!chrome.exportsFromNavigationBar)
        #expect(!chrome.minimizesTabBar)
    }
}
