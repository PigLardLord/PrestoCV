import XCTest

/// The open CV's details are stored by themselves as the person types, and the line under the title says so. Leaving the
/// CV right after an edit stores that edit. Each field has the keyboard of its text and a Done button above it, reads its
/// label to VoiceOver, and stays tall enough to tap at the largest text size. A field whose text cannot be read is named
/// once the person leaves it, never while they type.
final class EditorDetailsUITests: XCTestCase {

    /// A CV the launch fixture stores before the app starts.
    private struct StoredCV {
        let identity: String
        let title: String
        let person: String
        /// When it was last saved, as the store writes it.
        let saved: String
    }

    private let backendEngineer = StoredCV(
        identity: "6B1F6C1E-1B8C-4C1B-9D55-1F3B2C8B7A01", title: "Backend Engineer", person: "Mara Ellison",
        saved: "2026-01-02T00:00:00Z")
    private let dataAnalyst = StoredCV(
        identity: "7C2A7D2F-2C9D-4D2C-8E66-2A4C3D9C8B02", title: "Data Analyst", person: "Orla Penhaligon",
        saved: "2026-01-01T00:00:00Z")

    /// The English words of the status line.
    private let saved = "Saved on this device"
    private let unsavedChanges = "Unsaved changes"
    private let oneFieldNotSaved = "One field is not saved: see the note under it. The rest is saved."

    /// The fields of the details, in the order of the form, with the label VoiceOver reads for each. The summary, of
    /// several lines, is a text view.
    private let fields: [(type: XCUIElement.ElementType, identifier: String, label: String)] = [
        (.textField, "editor.field.title", "CV name"),
        (.textField, "editor.field.fullName", "Full name"),
        (.textField, "editor.field.professionalTitle", "Job title"),
        (.textField, "editor.field.email", "Email"),
        (.textField, "editor.field.phone", "Phone"),
        (.textField, "editor.field.location", "Location"),
        (.textField, "editor.field.website", "Website"),
        (.textView, "editor.field.summary", "Summary"),
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: Launching

    /// A store folder of its own with the given CVs, in English. With no CV the store is empty: a first run.
    @MainActor
    private func launch(_ cvs: [StoredCV], largestText: Bool) throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVNextEmptyStorage"]
        if !cvs.isEmpty {
            app.launchArguments += ["-PrestoCVNextSeed", try seed(cvs)]
        }
        if largestText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        return app
    }

    private func seed(_ cvs: [StoredCV]) throws -> String {
        var files: [String: String] = [:]
        for cv in cvs {
            // The store reads a CV from the file named by its identity
            files["\(cv.identity).cv.json"] = """
            {"schemaVersion":1,"id":"\(cv.identity)","revision":1,
             "createdAt":"2026-01-01T00:00:00Z","updatedAt":"\(cv.saved)","title":"\(cv.title)",
             "personal":{"fullName":"\(cv.person)","professionalTitle":"","location":"","summary":""},
             "experiences":[],"education":[],"skills":[],"languages":[],"certifications":[],"profiles":[],"interests":[]}
            """
        }
        // The fixture takes a JSON map from file name to content, in base 64
        return try JSONEncoder().encode(files).base64EncodedString()
    }

    /// Opens the stored CV from its row and waits for its form.
    @MainActor
    private func open(_ cv: StoredCV, in app: XCUIApplication) {
        let row = row(titled: cv.title, in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 30), "The list shows \(cv.title)")
        row.tap()
        XCTAssertTrue(app.textFields["editor.field.title"].waitForExistence(timeout: 30), "The form of \(cv.title) opens")
    }

    // MARK: Elements

    /// The row whose label starts with the title: a row reads its label, then the person, then the time since its last
    /// save.
    private func row(titled title: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "shell.row")
            .matching(NSPredicate(format: "label BEGINSWITH %@", title + ", ")).firstMatch
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func status(of app: XCUIApplication) -> XCUIElement {
        app.staticTexts["editor.status"]
    }

    /// The key of the on-screen keyboard with this character, in either case.
    private func key(_ character: String, in app: XCUIApplication) -> XCUIElement {
        app.keyboards.keys.matching(NSPredicate(format: "label ==[c] %@", character)).firstMatch
    }

    private func isCompact(_ app: XCUIApplication) -> Bool {
        app.windows.firstMatch.horizontalSizeClass != .regular
    }

    // MARK: Waiting and moving

    @MainActor
    private func waitUntil(_ element: XCUIElement, reads label: String) -> Bool {
        let reads = expectation(for: NSPredicate(format: "label == %@", label), evaluatedWith: element)
        return XCTWaiter().wait(for: [reads], timeout: 30) == .completed
    }

    @MainActor
    private func waitUntilGone(_ element: XCUIElement) -> Bool {
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element)
        return XCTWaiter().wait(for: [gone], timeout: 30) == .completed
    }

    /// Scrolls the form up in steps shorter than the screen, so that no field is passed over, until the element can be
    /// tapped. A form shows only the rows on screen. The drag stays in the form, away from the list beside it.
    @MainActor
    private func scrollUntilHittable(_ element: XCUIElement, named name: String, in app: XCUIApplication) {
        let form = self.element("shell.detail.opened", in: app)
        let from = form.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
        let to = form.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
        for _ in 0..<15 where !(element.exists && element.isHittable) {
            // Held at the end, so the form does not glide on
            from.press(forDuration: 0.05, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        XCTAssertTrue(element.exists && element.isHittable, "\(name) comes into view")
    }

    /// Puts the cursor after the text of the field and types: a tap near its end, past the last word.
    @MainActor
    private func append(_ text: String, to field: XCUIElement) {
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        field.typeText(text)
    }

    // MARK: Storing

    /// The person types, and the edit is stored without a button: the list and the title of the form show the new
    /// name, and the line under it says where the text is.
    @MainActor
    func testTypingIsStoredAndShown() throws {
        let app = try launch([backendEngineer], largestText: false)
        open(backendEngineer, in: app)

        append(" Lead", to: app.textFields["editor.field.title"])

        XCTAssertTrue(
            waitUntil(app.staticTexts["shell.detail.title"], reads: "Backend Engineer Lead"),
            "The title of the form follows the stored name")
        XCTAssertTrue(waitUntil(status(of: app), reads: saved), status(of: app).label)
        XCTAssertEqual(app.textFields["editor.field.title"].value as? String, "Backend Engineer Lead")
        if !isCompact(app) {
            XCTAssertTrue(row(titled: "Backend Engineer Lead", in: app).waitForExistence(timeout: 30), "The list beside it too")
        }
    }

    /// The person leaves at once after typing, before the pause after which the edit is stored by itself: Back where one
    /// column shows, another CV of the list where both show. The edit is stored all the same.
    @MainActor
    func testBackRightAfterTheLastEditStores() throws {
        let app = try launch([backendEngineer, dataAnalyst], largestText: false)
        open(backendEngineer, in: app)

        append(" Lead", to: app.textFields["editor.field.title"])
        if isCompact(app) {
            app.navigationBars.buttons.firstMatch.tap()
        } else {
            row(titled: dataAnalyst.title, in: app).tap()
        }

        XCTAssertTrue(
            row(titled: "Backend Engineer Lead", in: app).waitForExistence(timeout: 30),
            "The list shows the name typed right before leaving")
    }

    /// A new CV is stored as soon as it has something to keep, a detail of its person (the CV's name only names it in the
    /// list), and its row joins the list: at once where the list shows beside it, after Back where one column shows.
    @MainActor
    func testNewCVAppearsInTheList() throws {
        let app = try launch([], largestText: false)
        let blank = app.buttons["start.blank"]
        XCTAssertTrue(blank.waitForExistence(timeout: 30))
        blank.tap()
        let title = app.textFields["editor.field.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 30), "A blank CV opens its form")

        title.tap()
        title.typeText("Night Shift Nurse")
        // The keyboard may cover the next field
        app.buttons["keyboard.done"].tap()
        let fullName = app.textFields["editor.field.fullName"]
        fullName.tap()
        fullName.typeText("Ines Calloway")

        XCTAssertTrue(waitUntil(status(of: app), reads: saved), status(of: app).label)
        if isCompact(app) {
            app.navigationBars.buttons.firstMatch.tap()
        }
        XCTAssertTrue(row(titled: "Night Shift Nurse", in: app).waitForExistence(timeout: 30), "The new CV is in the list")
    }

    // MARK: Typing

    /// Each field brings up the keyboard of its text: the e-mail keyboard has "@", the phone pad digits and no letters,
    /// a name the letters. Done puts the keyboard away, also from the summary, whose return key starts a new line.
    /// iPad keyboards differ by model, so the keys are checked where one column shows.
    @MainActor
    func testKeyboardsAndDoneButton() throws {
        let app = try launch([backendEngineer], largestText: false)
        open(backendEngineer, in: app)

        // In the order of the form, each with the keyboard put away first, so that no field is under it
        tapAndPutAway(app.textFields["editor.field.fullName"], named: "The full name", in: app) {
            XCTAssertTrue(key("q", in: app).waitForExistence(timeout: 30), "A name gets the letters")
            XCTAssertFalse(key("@", in: app).exists, "A name gets no e-mail keyboard")
        }
        tapAndPutAway(app.textFields["editor.field.email"], named: "The e-mail address", in: app) {
            XCTAssertTrue(key("@", in: app).waitForExistence(timeout: 30), "The e-mail keyboard has @")
        }
        tapAndPutAway(app.textFields["editor.field.phone"], named: "The phone", in: app) {
            XCTAssertTrue(key("1", in: app).waitForExistence(timeout: 30), "The phone pad has digits")
            XCTAssertFalse(key("q", in: app).exists, "The phone pad has no letters")
        }
        tapAndPutAway(app.textViews["editor.field.summary"], named: "The summary", in: app) {}
    }

    /// Taps the field, checks its keyboard where one column shows, and puts the keyboard away with Done.
    @MainActor
    private func tapAndPutAway(
        _ field: XCUIElement, named name: String, in app: XCUIApplication, checkKeys: () -> Void
    ) {
        let keyboard = app.keyboards.firstMatch
        let done = app.buttons["keyboard.done"]
        scrollUntilHittable(field, named: name, in: app)
        field.tap()
        XCTAssertTrue(keyboard.waitForExistence(timeout: 30), "\(name) brings up the software keyboard")
        if isCompact(app) {
            checkKeys()
        }
        XCTAssertTrue(done.waitForExistence(timeout: 30), "A Done button is above the keyboard of \(name)")
        done.tap()
        XCTAssertTrue(waitUntilGone(keyboard), "Done puts the keyboard of \(name) away")
    }

    /// An e-mail address being typed is not one yet: the line under the title says the text is not stored, and no note
    /// shows. Once the person leaves the field (here with Done), the note under it says what to write, and the line
    /// points to it.
    @MainActor
    func testEmailNoteAppearsOnlyAfterLeavingTheField() throws {
        let app = try launch([backendEngineer], largestText: false)
        open(backendEngineer, in: app)

        let email = app.textFields["editor.field.email"]
        scrollUntilHittable(email, named: "The e-mail address", in: app)
        email.tap()
        email.typeText("mara.at.example")

        XCTAssertTrue(waitUntil(status(of: app), reads: unsavedChanges), status(of: app).label)
        XCTAssertFalse(element("editor.note.email", in: app).exists, "No problem is named while the person types")

        app.buttons["keyboard.done"].tap()

        XCTAssertTrue(element("editor.note.email", in: app).waitForExistence(timeout: 30), "The note shows once the field is left")
        XCTAssertTrue(waitUntil(status(of: app), reads: oneFieldNotSaved), status(of: app).label)
    }

    // MARK: Accessibility

    /// At the largest text size every field can be reached and tapped, and is at least as tall as the smallest tap target.
    @MainActor
    func testDetailsAtTheLargestTextSize() throws {
        let app = try launch([backendEngineer], largestText: true)
        open(backendEngineer, in: app)

        for field in fields {
            let element = app.descendants(matching: field.type)[field.identifier]
            scrollUntilHittable(element, named: field.identifier, in: app)
            // A frame comes as a float: 44 points read 43.99…
            XCTAssertGreaterThan(element.frame.height, 43.99, "\(field.identifier) is tall enough to tap")
        }
    }

    /// VoiceOver reads each field by its label, the summary's text view included.
    @MainActor
    func testDetailsLabelsForVoiceOver() throws {
        let app = try launch([backendEngineer], largestText: false)
        open(backendEngineer, in: app)

        for field in fields {
            let element = app.descendants(matching: field.type)[field.identifier]
            scrollUntilHittable(element, named: field.identifier, in: app)
            XCTAssertEqual(element.label, field.label, field.identifier)
        }
    }
}
