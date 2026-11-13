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
