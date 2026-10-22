import XCTest

/// `scrollTo` brings an element to a place where a tap lands on it, or fails the test: a tap after it never lands on
/// the bar, on the strip above the keyboard or beside the element.
///
/// The room is measured on the outer screen of the iPhone Duo, 466 by 678 points: the bar ends at 100 while it is
/// shown, and the strip of the keyboard starts at 332, above the middle of the screen.
final class ScrollingUITests: XCTestCase {

    private let screen = CGRect(x: 0, y: 0, width: 466, height: 678)
    private var withTheKeyboard: TapRoom { TapRoom(top: 100, bottom: 332, screen: screen) }
    private var withoutTheKeyboard: TapRoom { TapRoom(top: 100, bottom: 678, screen: screen) }

    private func place(top: CGFloat, height: CGFloat) -> CGRect {
        CGRect(x: 16, y: top, width: 434, height: height)
    }

    // MARK: - Where an element can be tapped

    /// A field fits between the bar and the strip, and is tapped only there.
    func testAnElementThatFitsIsWhollyBetweenTheBarAndTheKeyboard() {
        for upwards in [false, true] {
            XCTAssertEqual(withTheKeyboard.tops(forHeight: 44, upwards: upwards), 100...288)
            XCTAssertTrue(withTheKeyboard.holds(place(top: 100, height: 44), upwards: upwards))
            XCTAssertFalse(withTheKeyboard.holds(place(top: 99, height: 44), upwards: upwards), "Under the bar")
            XCTAssertFalse(withTheKeyboard.holds(place(top: 289, height: 44), upwards: upwards), "Under the strip")
        }
    }

    /// Without the keyboard an element is brought to the upper half, clear of a tab bar over the lower part; scrolling
    /// back, it may stay in the lower half.
    func testWithoutTheKeyboardAnElementComesToTheUpperHalf() {
        XCTAssertEqual(withoutTheKeyboard.tops(forHeight: 44, upwards: false), 100...317)
        XCTAssertEqual(withoutTheKeyboard.tops(forHeight: 44, upwards: true), 100...634)
    }

    /// An element too tall to have its middle in the upper half while it is below the bar may be anywhere it fits below
    /// the bar instead, rather than turned back and forth between the two.
    func testAnElementTooTallForTheUpperHalfIsWhollyOnTheScreen() {
        XCTAssertEqual(withoutTheKeyboard.tops(forHeight: 500, upwards: false), 100...178)
    }

    /// An element taller than the room between the bar and the strip is tapped at its middle, where a tap lands, with
    /// all of it on the screen. Before, it had to fit wholly in the room, and the scroll turned it back and forth,
    /// from under the bar to under the strip, until it stopped with its middle on the strip.
    func testAnElementTallerThanTheRoomIsTappedAtItsMiddle() {
        for upwards in [false, true] {
            let tops = withTheKeyboard.tops(forHeight: 500, upwards: upwards)
            XCTAssertEqual(tops, 0...82)
            XCTAssertFalse(withTheKeyboard.holds(place(top: 110, height: 500), upwards: upwards), "Its middle, at 360, is on the strip")
            XCTAssertFalse(withTheKeyboard.scrollsBack(towards: place(top: 110, height: 500), upwards: upwards), "It comes up")
            XCTAssertTrue(withTheKeyboard.scrollsBack(towards: place(top: -25, height: 500), upwards: upwards), "It comes down")
            XCTAssertTrue(withTheKeyboard.holds(place(top: 43, height: 500), upwards: upwards), "Its middle, at 293, is in the room")
        }
    }

    /// An element taller than the screen has no place where all of it shows.
    func testAnElementTallerThanTheScreenIsNeverInReach() {
        for upwards in [false, true] {
            XCTAssertNil(withoutTheKeyboard.tops(forHeight: 700, upwards: upwards))
            XCTAssertFalse(withoutTheKeyboard.holds(place(top: 0, height: 700), upwards: upwards))
        }
    }

    // MARK: - When the element cannot be reached

    /// A scroll that ends without the element where it can be tapped fails the test, instead of letting the next tap
    /// land elsewhere.
    func testAScrollThatCannotReachTheElementFailsTheTest() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVUITestsEmptyStorage"]
        app.launch()
        XCTAssertTrue(app.buttons["Create My First CV"].waitForExistence(timeout: 20), "The first run should show")

        // Only the failure of the scroll is expected: any other, as a drag that fails, fails the test
        let options = XCTExpectedFailure.Options()
        options.issueMatcher = { $0.compactDescription.contains("cannot be scrolled to a place where a tap lands on it") }
        XCTExpectFailure("The element is not in the app", options: options) {
            app.scrollTo(app.buttons["An element that is not in the app"], maxSteps: 2)
        }
    }
}
