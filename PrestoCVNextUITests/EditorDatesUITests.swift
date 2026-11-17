import XCTest

/// The dates of the rows. A period is a start and an end, each a month menu, with no month too, and a year typed on the
/// number pad; "currently here" hides the end and clears it. An end before the start is named once the person leaves the
/// period, and no longer once it is right. Every control stays tall enough to tap, and inside the screen, at the largest
/// text size and in landscape. On a narrow screen the dates are on the page of the row, and so is the status line.
final class EditorDatesUITests: RuntimeIssueFailingTestCase {

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

    /// Adds a row from the CV's form, leaving the page of a row first where one is open, and types in its first field. On
    /// a narrow screen the new row's page opens.
    @MainActor
    private func addRow(to section: String, typing text: String, in app: XCUIApplication) {
        if app.entryPage.exists { app.leaveEntryPage() }
        let add = app.buttons["editor.add.\(section)"]
        app.scrollForm(until: add, named: "The add button of \(section)")
        add.tap()
        if app.opensOnAPage(section) {
            XCTAssertTrue(app.entryPage.waitForExistence(timeout: 30), "A new row of \(section) opens its page")
        }
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 30), "A new row of \(section) takes the keyboard")
        app.typeText(text)
        putKeyboardAway(in: app)
    }

    @MainActor
    private func putKeyboardAway(in app: XCUIApplication) {
        app.buttons["keyboard.done"].tap()
        XCTAssertTrue(wait(for: NSPredicate(format: "exists == false"), app.keyboards.firstMatch), "Done puts it away")
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
        app.scrollForm(until: menu, named: "The month of \(date)")
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
        app.scrollForm(until: field, named: "The year of \(date)")
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
        app.scrollForm(until: status, named: "The status line", forward: false)
        XCTAssertTrue(wait(for: NSPredicate(format: "label == %@", saved), status), status.label)
    }

    @MainActor
    func testCurrentlyHereHidesTheEnd() throws {
        let app = try launchWithAJob(largestText: false)
        type("2018", in: start, app)
        type("2022", in: end, app)
        let toggle = app.switches[current]
        app.scrollForm(until: toggle, named: "The switch")
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

        app.scrollForm(until: status, named: "The status line", forward: false)
        XCTAssertTrue(wait(for: NSPredicate(format: "label == %@", oneFieldNotSaved), status), status.label)

        type("2023", in: end, app)
        app.scrollForm(until: status, named: "The status line", forward: false)
        XCTAssertTrue(wait(for: NSPredicate(format: "label == %@", saved), status), "Named no more: \(status.label)")
    }

    /// The menu closes on the pick, so an end month picked before the start month is named at once: the year was left
    /// before, and nothing else is touched after the pick.
    @MainActor
    func testEndMonthPickedBeforeTheStartIsNamed() throws {
        let app = try launchWithAJob(largestText: false)
        let status = app.staticTexts["editor.status"]
        pick("March", in: start, app)
        type("2020", in: start, app)
        type("2020", in: end, app)
        app.scrollForm(until: status, named: "The status line", forward: false)
        XCTAssertTrue(wait(for: NSPredicate(format: "label == %@", saved), status), "No month, no problem: \(status.label)")

        pick("January", in: end, app)

        app.scrollForm(until: status, named: "The status line", forward: false)
        XCTAssertTrue(wait(for: NSPredicate(format: "label == %@", oneFieldNotSaved), status), status.label)
    }

    /// Taps near the end of the field, past the last word, once the field is well inside the screen: a field that can be
    /// hit may still sit at the very edge, where a tap takes no focus. The form is moved on in steps like `scroll`.
    @MainActor
    private func tapTheEnd(of field: XCUIElement, in app: XCUIApplication) {
        let form = app.openForm
        let low = form.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
        let high = form.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
        let screen = app.windows.firstMatch.frame
        for _ in 0..<10 where field.frame.maxY > screen.minY + screen.height * 0.7 {
            low.press(forDuration: 0.05, thenDragTo: high, withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        XCTAssertLessThan(field.frame.maxY, screen.maxY, "The link is inside the screen")
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
    }

    /// A link that is no address is named once the person leaves its field, and no more once it reads, for a certification
    /// and for a profile. The note is for the eye; the status line points to it. Scrolling the form puts the keyboard
    /// away, so the form is not scrolled while the person types.
    @MainActor
    func testLinkNoteAppearsOnlyAfterLeavingTheField() throws {
        let app = try launchWithAJob(largestText: false)
        let status = app.staticTexts["editor.status"]
        // A profile exists only with a link, so its row is added when its turn comes
        for (section, name, link) in [
            ("certifications", "Rigging", "editor.field.certificationLink"), ("profiles", "Portfolio", "editor.field.profileLink"),
        ] {
            addRow(to: section, typing: name, in: app)
            let field = app.textFields[link]
            app.scrollForm(until: field, named: "The link \(link)")
            tapTheEnd(of: field, in: app)
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 30), "The link takes the keyboard")
            field.typeText("not an address")
            putKeyboardAway(in: app)
            app.scrollForm(until: status, named: "The status line", forward: false)
            XCTAssertTrue(wait(for: NSPredicate(format: "label == %@", oneFieldNotSaved), status), status.label)

            app.scrollForm(until: field, named: "The link \(link)")
            tapTheEnd(of: field, in: app)
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 30), "The link takes the keyboard")
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "not an address".count))
            field.typeText("https://example.com")
            putKeyboardAway(in: app)
            let reads = field.value as? String ?? ""
            app.scrollForm(until: status, named: "The status line", forward: false)
            XCTAssertTrue(
                wait(for: NSPredicate(format: "label == %@", saved), status),
                "Named no more: \(status.label); the link reads \(reads)"
            )
        }
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

        let turned = try app.turnsToLandscape()
        XCTAssertTrue(turned, "The form turns with the device, as Safari does")
        check(app.textFields[issued], named: "The year issued in landscape", app)
    }

    @MainActor
    private func check(_ target: XCUIElement, named name: String, _ app: XCUIApplication) {
        // A turn of the screen can leave it above the form: its place gives the way
        app.scrollForm(until: target, named: name)
        // A frame comes as a float: 44 points read 43.99…
        XCTAssertGreaterThan(target.frame.height, 43.99, "\(name) is tall enough to tap")
        XCTAssertLessThanOrEqual(target.frame.maxX, app.windows.firstMatch.frame.maxX + 0.5, "\(name) fits the screen")
    }
}
