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

    // MARK: - The notice above the form

    @Test("In portrait at the normal text size the notice above the form shows all its lines, as it is")
    func portraitShowsTheWholeNotice() {
        let chrome = EditorChrome(verticalSizeClass: .regular, dynamicTypeSize: .large)

        #expect(chrome.noticeHeight(fullHeight: 400, editorHeight: 760) == nil)
    }

    @Test("At an accessibility size the notice takes at most a quarter of the editor's height, and scrolls beyond it")
    func accessibilitySizeLimitsTheNotice() {
        for size in [DynamicTypeSize.accessibility1, .accessibility3, .accessibility5] {
            let chrome = EditorChrome(verticalSizeClass: .regular, dynamicTypeSize: size)

            #expect(chrome.noticeHeight(fullHeight: 400, editorHeight: 760) == 190, "\(size)")
        }
    }

    @Test("At an accessibility size a notice shorter than a quarter of the editor keeps its own height")
    func shortNoticeKeepsItsHeight() {
        let chrome = EditorChrome(verticalSizeClass: .regular, dynamicTypeSize: .accessibility5)

        #expect(chrome.noticeHeight(fullHeight: 120, editorHeight: 760) == 120)
    }

    @Test("In landscape the notice takes at most a quarter of the editor's height")
    func landscapeLimitsTheNotice() {
        let chrome = EditorChrome(verticalSizeClass: .compact, dynamicTypeSize: .large)

        #expect(chrome.noticeHeight(fullHeight: 200, editorHeight: 320) == 80)
    }

    @Test("Before the editor's height is known, the notice is not limited, so that it never starts with no room at all")
    func unknownHeightLeavesTheNotice() {
        let chrome = EditorChrome(verticalSizeClass: .regular, dynamicTypeSize: .accessibility5)

        #expect(chrome.noticeHeight(fullHeight: 400, editorHeight: 0) == nil)
    }
}
