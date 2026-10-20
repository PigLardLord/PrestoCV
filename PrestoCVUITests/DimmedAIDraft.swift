import XCTest

/// What the dimmed AI draft says in English, for each availability of the debug override that leaves it off.
struct DimmedAIDraft {
    /// The value of `-AIAvailabilityOverride`.
    let override: String
    /// The line shown in place.
    let line: String
    /// The full explanation that a tap shows.
    let explanation: String

    /// What VoiceOver reads after the title: that the AI draft is unavailable, and why.
    var announcement: String { "Unavailable. \(explanation)" }

    static let modelNotReady = DimmedAIDraft(
        override: "modelNotReady",
        line: "Getting ready, available soon",
        explanation: "The Apple Intelligence model is still downloading. Try again later."
    )
    static let appleIntelligenceNotEnabled = DimmedAIDraft(
        override: "appleIntelligenceNotEnabled",
        line: "Turn on Apple Intelligence",
        explanation: "Apple Intelligence is turned off. To use this, open Settings, tap Apple Intelligence & Siri, "
            + "and turn on Apple Intelligence."
    )
    static let deviceNotEligible = DimmedAIDraft(
        override: "deviceNotEligible",
        line: "Needs Apple Intelligence",
        explanation: "This device doesn't support AI drafts. You can create your CV by hand or start from an example."
    )
    static let unknown = DimmedAIDraft(
        override: "unknown",
        line: "Not available right now",
        explanation: "AI drafting isn't available right now."
    )
}

extension XCUIApplication {
    /// A text on screen, by its whole label. A query by a label longer than 128 characters needs a predicate.
    func text(_ label: String) -> XCUIElement {
        staticTexts.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    /// Checks that `entry` is the dimmed AI draft of `draft` as VoiceOver reads it, that it can be activated, that a
    /// tap on it shows the line and the full explanation, and that Done closes them.
    func checkDimmedAIDraft(_ entry: XCUIElement, says draft: DimmedAIDraft, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(entry.elementType, .button, "Assistive technologies should find a button", file: file, line: line)
        XCTAssertTrue(entry.isEnabled, "Voice Control and Switch Control should be able to activate the AI draft", file: file, line: line)
        XCTAssertEqual(entry.value as? String, draft.announcement, "VoiceOver should read that it is unavailable, and why", file: file, line: line)
        let explanation = text(draft.explanation)
        XCTAssertFalse(explanation.exists, "The full explanation should wait for a tap", file: file, line: line)

        entry.tap()

        XCTAssertTrue(explanation.waitForExistence(timeout: 10), "A tap should show the full explanation", file: file, line: line)
        XCTAssertTrue(text(draft.line).exists, "The explanation should open with the line shown in place", file: file, line: line)
        navigationBars.buttons["Done"].tap()
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: explanation)
        XCTAssertEqual(XCTWaiter().wait(for: [closed], timeout: 10), .completed, "Done should close the explanation", file: file, line: line)
    }

    /// Activates `entry` at its activation point, the middle of its element, where Voice Control and Switch Control act
    /// on a button they found in the accessibility tree, and checks that the explanation opens. A disabled control would
    /// be read as dimmed and could not be activated.
    func activateAsAnAssistiveTechnology(_ entry: XCUIElement, says draft: DimmedAIDraft, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(entry.elementType, .button, "Assistive technologies should find a button", file: file, line: line)
        XCTAssertTrue(entry.isEnabled, "An assistive technology can activate only an enabled element", file: file, line: line)

        entry.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        XCTAssertTrue(text(draft.explanation).waitForExistence(timeout: 10), "The activation should show the explanation", file: file, line: line)
    }
}
