import XCTest

extension XCUIApplication {
    /// The screen as it is, kept with the results even when the test passes, so that its layout can be looked at.
    func keptScreenshot(named name: String) -> XCTAttachment {
        let attachment = XCTAttachment(screenshot: screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        return attachment
    }
}
