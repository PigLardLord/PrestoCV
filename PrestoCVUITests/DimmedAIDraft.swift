import XCTest

/// What the dimmed AI draft says in English, for each availability of the debug override that leaves it off.
struct DimmedAIDraft {
    /// The value of `-AIAvailabilityOverride`.
    let override: String
    /// The line shown in place.
    let line: String
    /// The full explanation that a tap shows and that VoiceOver reads.
    let explanation: String

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

    /// Checks that `entry` is the dimmed AI draft of `draft` as VoiceOver reads it, that a tap on it shows the line
    /// and the full explanation, and that Done closes them.
    func checkDimmedAIDraft(_ entry: XCUIElement, says draft: DimmedAIDraft, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(entry.isEnabled, "VoiceOver should read the AI draft as dimmed", file: file, line: line)
        XCTAssertEqual(entry.value as? String, draft.explanation, "VoiceOver should read why, after the title", file: file, line: line)
        let explanation = text(draft.explanation)
        XCTAssertFalse(explanation.exists, "The full explanation should wait for a tap", file: file, line: line)

        entry.tap()

        XCTAssertTrue(explanation.waitForExistence(timeout: 10), "A tap should show the full explanation", file: file, line: line)
        XCTAssertTrue(text(draft.line).exists, "The explanation should open with the line shown in place", file: file, line: line)
        navigationBars.buttons["Done"].tap()
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: explanation)
        XCTAssertEqual(XCTWaiter().wait(for: [closed], timeout: 10), .completed, "Done should close the explanation", file: file, line: line)
    }
}
