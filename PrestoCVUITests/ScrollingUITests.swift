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
    /// back, or when the scroll is told not to ask for the upper half, it may stay in the lower half.
    func testWithoutTheKeyboardAnElementComesToTheUpperHalf() {
        XCTAssertEqual(withoutTheKeyboard.tops(forHeight: 44, upwards: false), 100...317)
        XCTAssertEqual(withoutTheKeyboard.tops(forHeight: 44, upwards: true), 100...634)
        XCTAssertEqual(withoutTheKeyboard.tops(forHeight: 44, upwards: false, toTheUpperHalf: false), 100...634)
        XCTAssertTrue(withoutTheKeyboard.holds(place(top: 500, height: 44), upwards: false, toTheUpperHalf: false))
        XCTAssertFalse(withoutTheKeyboard.holds(place(top: 500, height: 44), upwards: false))
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

    // MARK: - Where a swipe along a row starts

    /// On an iPhone the content runs to the margin, and the swipe starts where it always did: at nine tenths of the
    /// row's width, a tenth of its height down.
    func testASwipeOnAnIPhoneStartsAtNineTenthsOfTheRow() {
        let iPhone = TapRoom(top: 103, bottom: 874, screen: CGRect(x: 0, y: 0, width: 402, height: 874))
        let row = CGRect(x: 0, y: 300, width: 402, height: 95)
        let start = iPhone.swipeStart(in: row, contentRight: 386)
        XCTAssertEqual(start.x, 361.8, accuracy: 0.01)
        XCTAssertEqual(start.y, 311.4, accuracy: 0.01)
        XCTAssertEqual(iPhone.swipeStart(in: row, contentRight: nil), start, "Without the content, as before")
    }

    /// On the outer screen of the iPhone Duo the content ends well left of nine tenths of the row: the swipe starts
    /// inside it, not in the margin beside it.
    func testASwipeStartsInsideTheContentOfARowWhoseMarginIsWide() {
        let row = CGRect(x: 0, y: 200.7, width: 466, height: 95)
        let start = withoutTheKeyboard.swipeStart(in: row, contentRight: 382)
        XCTAssertEqual(start.x, 374, accuracy: 0.01)
        XCTAssertEqual(start.y, 212.1, accuracy: 0.01)
    }

    /// A row whose content ends far to the left is still swiped from its upper part, not from its left end.
    func testASwipeNeverStartsLeftOfThreeTenthsOfTheRow() {
        let row = CGRect(x: 16, y: 200, width: 434, height: 95)
        XCTAssertEqual(withoutTheKeyboard.swipeStart(in: row, contentRight: 40).x, 16 + 434 * 0.3, accuracy: 0.01)
    }

    /// A row scrolled up leaves its upper part under the navigation bar, and a swipe there lands on the bar: it starts
    /// below it. At the other end it stays above the strip of the keyboard, and inside the row.
    func testASwipeStartsWhereATouchLandsOnTheRow() {
        let bar = TapRoom(top: 126, bottom: 678, screen: screen)
        let tall = CGRect(x: 0, y: 82, width: 466, height: 270)
        XCTAssertEqual(bar.swipeStart(in: tall, contentRight: 382).y, 134, accuracy: 0.01, "Not at 114, under the bar")

        let low = CGRect(x: 0, y: 320, width: 466, height: 95)
        XCTAssertEqual(withTheKeyboard.swipeStart(in: low, contentRight: 382).y, 324, accuracy: 0.01, "Above the strip at 332")

        let short = CGRect(x: 0, y: 300, width: 466, height: 20)
        XCTAssertEqual(withoutTheKeyboard.swipeStart(in: short, contentRight: 382).y, 304, accuracy: 0.01, "Inside a row 20 points tall")
    }

    // MARK: - Where a tap closes a popover

    /// On the outer screen of the iPhone Duo the question about a row is a popover of 240 by 227 points beside the row.
    /// The tap goes to the middle of the largest band outside it, here the one above it. Before, it went low on the
    /// screen, at 95 hundredths of its height, which is inside the popover when the row is low in the list.
    func testATapThatClosesAPopoverFallsInTheLargestBandAroundIt() {
        let popover = CGRect(x: 71, y: 425.7, width: 240, height: 227.3)
        let point = withoutTheKeyboard.pointOutside(popover)
        XCTAssertEqual(point.x, 233, accuracy: 0.01)
        XCTAssertEqual(point.y, 212.85, accuracy: 0.01)
        XCTAssertFalse(popover.contains(point), "The tap would land in the popover")
        XCTAssertTrue(screen.contains(point))
    }

    /// The largest band may also be beside the popover: on a wide screen a popover by the left edge leaves most of the
    /// screen to its right.
    func testATapThatClosesAPopoverMayFallBesideIt() {
        let wide = CGRect(x: 0, y: 0, width: 820, height: 1180)
        let popover = CGRect(x: 100, y: 300, width: 300, height: 400)
        let point = TapRoom(top: 70, bottom: 1180, screen: wide).pointOutside(popover)
        XCTAssertEqual(point.x, 610, accuracy: 0.01, "The middle of the band to the right: 400 to 820")
        XCTAssertEqual(point.y, 590, accuracy: 0.01)
        XCTAssertFalse(popover.contains(point), "The tap would land in the popover")
    }

    /// Without a popover to avoid, because there is none or it is not on the screen, or when it covers the whole screen
    /// and leaves no band, the tap falls low on the screen, as it did.
    func testATapThatClosesAPopoverFallsLowWhereNothingIsToBeAvoided() {
        let low = withoutTheKeyboard.pointOutside(nil)
        XCTAssertEqual(low.x, 233, accuracy: 0.01)
        XCTAssertEqual(low.y, 644.1, accuracy: 0.01)

        let everything = CGRect(x: -10, y: -10, width: 500, height: 700)
        XCTAssertEqual(withoutTheKeyboard.pointOutside(everything), low, "No band is left")
        let elsewhere = CGRect(x: 1000, y: 0, width: 100, height: 100)
        XCTAssertEqual(withoutTheKeyboard.pointOutside(elsewhere), low, "A popover that is not on the screen is nothing to avoid")
    }

    // MARK: - When the element cannot be reached

    /// A scroll that ends without the element where it can be tapped fails the test, instead of letting the next tap
    /// land elsewhere.
    func testAScrollThatCannotReachTheElementFailsTheTest() {
        let app = launchedOnTheFirstRun()

        // Only the failure of the scroll is expected: any other, as a drag that fails, fails the test
        let options = XCTExpectedFailure.Options()
        options.issueMatcher = { $0.compactDescription.contains("cannot be scrolled to a place where a tap lands on it") }
        XCTExpectFailure("The element is not in the app", options: options) {
            app.scrollTo(app.buttons["An element that is not in the app"], maxSteps: 2)
        }
    }

    // MARK: - Walking the form

    /// A list is lazy: a short screen holds only some of the rows of a tab in the tree at a time. Walking the form from its
    /// top to its end shows all of them at some stop, and ends.
    func testWalkingTheFormShowsEveryRowOfATab() throws {
        continueAfterFailure = false
        let app = launchedOnTheFirstRun()
        app.buttons["Create My First CV"].tap()
        let experience = app.buttons["Experience"].firstMatch
        XCTAssertTrue(experience.waitForExistence(timeout: 10), "The editor should show its tabs")
        experience.tap()

        let adds = ["Add Experience", "Add Education", "Add Skill"]
        var seen = Set<String>()
        var stops = 0
        app.walkTheForm {
            stops += 1
            seen.formUnion(app.buttons.matching(NSPredicate(format: "label IN %@", adds)).allElementsBoundByIndex.map(\.label))
        }
        XCTAssertGreaterThanOrEqual(stops, 1, "The form should be visited at its top at least")
        XCTAssertEqual(seen, Set(adds), "Every button that adds a row should be seen at some stop of the walk, in \(stops) stops")
    }

    // MARK: - Where the tab bar is

    /// The tab bar bounds the room only while it floats over the lower part of the screen. The editor's tabs show where
    /// the bar is: side by side in the lower half on an iPhone, side by side at the top on an iPad in a wide window,
    /// and one above the other in the side bar of the outer screen of the iPhone Duo.
    func testTheTabBarBoundsTheRoomOnlyOverTheLowerPart() throws {
        continueAfterFailure = false
        let app = launchedOnTheFirstRun()
        app.buttons["Create My First CV"].tap()
        let basics = app.buttons["Basics"].firstMatch
        let experience = app.buttons["Experience"].firstMatch
        XCTAssertTrue(experience.waitForExistence(timeout: 10), "The editor should show its tabs")
        XCTAssertTrue(basics.exists, "The editor should show its tabs")
        XCTAssertNil(app.keyboardTop, "The editor should open with the keyboard down")

        let first = basics.frame, second = experience.frame
        let sideBySide = abs(first.midY - second.midY) < 1 && first.midX != second.midX
        if sideBySide, first.midY > app.frame.midY {
            try XCTContext.runActivity(named: "The tabs float over the lower part") { _ in
                let top = try XCTUnwrap(app.tabBarTop, "A tab bar over the lower part should bound the room")
                XCTAssertLessThanOrEqual(top, min(first.minY, second.minY), "The bar should start above its tabs")
                XCTAssertEqual(TapRoom(in: app).bottom, top, "The room should end at the bar")
            }
        } else {
            XCTContext.runActivity(named: "The tabs are at the top or at the side") { _ in
                XCTAssertNil(app.tabBarTop, "Tabs at the top or at the side should leave the room as it is")
                XCTAssertEqual(TapRoom(in: app).bottom, app.frame.maxY, "The room should end at the bottom of the screen")
            }
        }
    }

    // MARK: - Launching

    /// The app on its first run, in English.
    private func launchedOnTheFirstRun() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVUITestsEmptyStorage"]
        app.launch()
        XCTAssertTrue(app.buttons["Create My First CV"].waitForExistence(timeout: 20), "The first run should show")
        return app
    }
}
