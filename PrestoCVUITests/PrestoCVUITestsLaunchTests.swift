//
//  PrestoCVUITestsLaunchTests.swift
//  PrestoCVUITests
//
//  Created by Giovanni Trovato on 30/11/21.
//

import XCTest

class PrestoCVUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// The configurations include landscape: the tests that run next start in portrait, as on a device held upright.
    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
    }

    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
