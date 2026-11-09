import XCTest

/// The dates of the rows. A period is a start and an end, each a month menu, with no month too, and a year typed on the
/// number pad; "currently here" hides the end and clears it. An end before the start is named once the person leaves the
/// period, and no longer once it is right. Every control stays tall enough to tap, and inside the screen, at the largest
/// text size and in landscape.
final class EditorDatesUITests: XCTestCase {

    private let identity = "5B1F3C2E-7A4D-4F0B-9C6E-2D8A1E4B7C05"
    private let title = "Crane Operator"
    /// A date's month menu is a button and its year a text field, under one identifier.
    private let start = "editor.field.experiencePeriod.start"
    private let end = "editor.field.experiencePeriod.end"
    private let current = "editor.field.experiencePeriod.current"
    private let issued = "editor.field.certificationIssued"
    private let saved = "Saved on this device"
    private let oneFieldNotSaved = "One field is not saved: see the note under it. The rest is saved."

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDown() async throws {
        await MainActor.run { XCUIDevice.shared.orientation = .portrait }
    }

    // MARK: Launching and moving

    /// A store folder of its own with one CV whose sections are empty, in English, opened, with a job added.
    @MainActor
    private func launchWithAJob(largestText: Bool) throws -> XCUIApplication {
        let app = XCUIApplication()
        let cv = """
        {"schemaVersion":1,"id":"\(identity)","revision":1,
         "createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-02T00:00:00Z","title":"\(title)",
         "personal":{"fullName":"Ines Corr","professionalTitle":"","location":"","summary":""},
         "experiences":[],"education":[],"skills":[],"languages":[],"certifications":[],"profiles":[],"interests":[]}
        """
        let seed = try JSONEncoder().encode(["\(identity).cv.json": cv]).base64EncodedString()
        app.launchArguments += [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVNextEmptyStorage", "-PrestoCVNextSeed", seed,
        ]
        if largestText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        let row = app.descendants(matching: .any).matching(identifier: "shell.row")
            .matching(NSPredicate(format: "label BEGINSWITH %@", title + ", ")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 30), "The list shows \(title)")
        row.tap()
        XCTAssertTrue(app.textFields["editor.field.title"].waitForExistence(timeout: 30), "The form of \(title) opens")
        addRow(to: "experiences", typing: "Crane driver", in: app)
        return app
    }

    @MainActor
    private func addRow(to section: String, typing text: String, in app: XCUIApplication) {
        let add = app.buttons["editor.add.\(section)"]
        scroll(until: add, named: "The add button of \(section)", forward: true, in: app)
        add.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 30), "A new row of \(section) takes the keyboard")
        app.typeText(text)
        putKeyboardAway(in: app)
    }

    @MainActor
    private func putKeyboardAway(in app: XCUIApplication) {
        app.buttons["keyboard.done"].tap()
        XCTAssertTrue(wait(for: NSPredicate(format: "exists == false"), app.keyboards.firstMatch), "Done puts it away")
    }

    /// Scrolls the form, on or back, in steps shorter than the screen until the element can be tapped. A form shows only
    /// the rows on screen. The drag stays in the form, away from the list beside it.
    @MainActor
    private func scroll(until element: XCUIElement, named name: String, forward: Bool, in app: XCUIApplication) {
        let form = app.descendants(matching: .any).matching(identifier: "shell.detail.opened").firstMatch
        let low = form.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
        let high = form.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
        for _ in 0..<15 where !(element.exists && element.isHittable) {
            // Held at the end, so the form does not glide on
            (forward ? low : high).press(forDuration: 0.05, thenDragTo: forward ? high : low, withVelocity: .slow,
                                         thenHoldForDuration: 0.2)
        }
        XCTAssertTrue(element.exists && element.isHittable, "\(name) comes into view")
    }

    @MainActor
    private func wait(for predicate: NSPredicate, _ element: XCUIElement) -> Bool {
        XCTWaiter().wait(for: [expectation(for: predicate, evaluatedWith: element)], timeout: 30) == .completed
    }

    // MARK: Dates

    /// Opens the month menu of the date, checks that it offers no month, and picks `month`.
    @MainActor
    private func pick(_ month: String, in date: String, _ app: XCUIApplication) {
        let menu = app.buttons.matching(identifier: date).firstMatch
        scroll(until: menu, named: "The month of \(date)", forward: true, in: app)
        menu.tap()
        XCTAssertTrue(app.buttons["No month"].waitForExistence(timeout: 30), "The menu offers no month")
        app.buttons[month].tap()
        let shows = NSPredicate(format: "label CONTAINS %@ OR value == %@", month, month)
        XCTAssertTrue(wait(for: shows, menu), "The month of \(date) shows \(month): \(menu.label)")
    }

    /// Types `year` in place of the year of the date, on the number pad, and puts the keyboard away.
    @MainActor
    private func type(_ year: String, in date: String, _ app: XCUIApplication) {
        let field = app.textFields[date]
        scroll(until: field, named: "The year of \(date)", forward: true, in: app)
        field.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 30), "The year takes the keyboard")
        if app.windows.firstMatch.horizontalSizeClass != .regular {
            let letter = app.keyboards.keys.matching(NSPredicate(format: "label ==[c] %@", "a")).firstMatch
            XCTAssertFalse(letter.exists, "The year takes the number pad, which has no letters")
        }
        let typed = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: typed.count) + year)
        putKeyboardAway(in: app)
    }

    /// Flips the switch by the switch itself: a tap on its words does not.
    @MainActor
    private func flip(_ toggle: XCUIElement) {
        let was = toggle.value as? String ?? ""
        let knob = toggle.switches.firstMatch
        if knob.exists {
            knob.tap()
        } else {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
        }
        XCTAssertTrue(wait(for: NSPredicate(format: "value != %@", was), toggle), "The switch flips")
    }

    @MainActor
    func testStartAndEndMonthYear() throws {
        let app = try launchWithAJob(largestText: false)

        pick("March", in: start, app)
        type("2019", in: start, app)
        pick("June", in: end, app)
        type("2021", in: end, app)

        XCTAssertEqual(app.textFields[start].value as? String, "2019")
        XCTAssertEqual(app.textFields[start].label, "Start year", "VoiceOver reads the year by its label")
        XCTAssertEqual(app.textFields[end].value as? String, "2021")
        let status = app.staticTexts["editor.status"]
        scroll(until: status, named: "The status line", forward: false, in: app)
        XCTAssertTrue(wait(for: NSPredicate(format: "label == %@", saved), status), status.label)
    }

    @MainActor
    func testCurrentlyHereHidesTheEnd() throws {
        let app = try launchWithAJob(largestText: false)
        type("2018", in: start, app)
        type("2022", in: end, app)
        let toggle = app.switches[current]
        scroll(until: toggle, named: "The switch", forward: true, in: app)
        XCTAssertEqual(toggle.label, "I work here now")

        flip(toggle)
        XCTAssertTrue(wait(for: NSPredicate(format: "exists == false"), app.textFields[end]), "The end goes")
        XCTAssertFalse(app.buttons.matching(identifier: end).firstMatch.exists, "with its month")

        flip(toggle)
        XCTAssertTrue(app.textFields[end].waitForExistence(timeout: 30), "The end comes back")
        XCTAssertEqual(app.textFields[end].value as? String ?? "", "", "The switch cleared the end")
    }

    /// The problem is named in the status line, which a UI test can read: the note under the period is for the eye, and
    /// VoiceOver reads it as custom content, which XCUITest does not show.
    @MainActor
    func testEndBeforeStartIsNamed() throws {
        let app = try launchWithAJob(largestText: false)
        let status = app.staticTexts["editor.status"]
        type("2021", in: start, app)
        type("2019", in: end, app)

        scroll(until: status, named: "The status line", forward: false, in: app)
        XCTAssertTrue(wait(for: NSPredicate(format: "label == %@", oneFieldNotSaved), status), status.label)

        type("2023", in: end, app)
        scroll(until: status, named: "The status line", forward: false, in: app)
        XCTAssertTrue(wait(for: NSPredicate(format: "label == %@", saved), status), "Named no more: \(status.label)")
    }

    /// At the largest text size each control of a period and of a certification's date can be reached, is at least as
    /// tall as the smallest tap target, and stays inside the screen; in landscape too.
    @MainActor
    func testDatesAtTheLargestTextSize() throws {
        let app = try launchWithAJob(largestText: true)
        // In the order of the form
        check(app.buttons.matching(identifier: start).firstMatch, named: "The start month", app)
        check(app.textFields[start], named: "The start year", app)
        check(app.switches[current], named: "The switch", app)
        check(app.buttons.matching(identifier: end).firstMatch, named: "The end month", app)
        check(app.textFields[end], named: "The end year", app)

        addRow(to: "certifications", typing: "Rigging", in: app)
        check(app.buttons.matching(identifier: issued).firstMatch, named: "The month issued", app)
        check(app.textFields[issued], named: "The year issued", app)

        XCUIDevice.shared.orientation = .landscapeLeft
        check(app.textFields[issued], named: "The year issued in landscape", app)
    }

    @MainActor
    private func check(_ target: XCUIElement, named name: String, _ app: XCUIApplication) {
        // On, unless it went above the form, as a turn of the screen can take it
        let form = app.descendants(matching: .any).matching(identifier: "shell.detail.opened").firstMatch
        let above = target.exists && !target.isHittable && target.frame.midY < form.frame.midY
        scroll(until: target, named: name, forward: !above, in: app)
        // A frame comes as a float: 44 points read 43.99…
        XCTAssertGreaterThan(target.frame.height, 43.99, "\(name) is tall enough to tap")
        XCTAssertLessThanOrEqual(target.frame.maxX, app.windows.firstMatch.frame.maxX + 0.5, "\(name) fits the screen")
    }
}
