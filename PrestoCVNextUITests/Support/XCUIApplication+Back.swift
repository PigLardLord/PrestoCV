import XCTest

extension XCUIApplication {
    /// The navigation bar's Back, as the system draws it. Its identifier stays the same whatever it reads (the title of the
    /// screen before, or Back), so another button of the bar, such as the editor's Edit, is never taken for it.
    var backButton: XCUIElement {
        navigationBars.buttons["BackButton"]
    }

    /// The identifiers of the navigation bar's buttons, in order: what a failure about Back reports.
    var barButtonIdentifiers: [String] {
        navigationBars.buttons.allElementsBoundByIndex.map(\.identifier)
    }
}

extension XCUIApplication {
    /// Whether the list is a screen of its own: on a narrow window the editor comes after it and has Back and the edge
    /// swipe; on a wide one the list stands beside the editor.
    @MainActor
    var isCompactWidth: Bool {
        windows.firstMatch.horizontalSizeClass != .regular
    }

    /// Swipes from the left edge to the right, as the system's Back gesture does, a third of the way down: above the keyboard, which a swipe that starts on it
    /// would belong to.
    @MainActor
    func swipeBackFromTheLeftEdge() {
        let edge = coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.3))
        edge.press(forDuration: 0.05, thenDragTo: coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.3)))
    }
}
