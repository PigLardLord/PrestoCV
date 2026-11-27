import UIKit
import XCTest

/// The open CV's details are stored by themselves as the person types, and the line under the title says so. Leaving the
/// CV right after an edit stores that edit. Each field has the keyboard of its text and a Done button above it, reads its
/// label to VoiceOver, and stays tall enough to tap at the largest text size. A field whose text cannot be read is named
/// once the person leaves it, never while they type. A field of one line wraps onto more lines at the largest text
/// size, so that its whole text can be read; a drag on it scrolls the form, and its return key moves to the next field
/// and keeps no line break.
final class EditorDetailsUITests: RuntimeIssueFailingTestCase {

    /// A CV the launch fixture stores before the app starts.
    private struct StoredCV {
        let identity: String
        let title: String
        let person: String
        /// When it was last saved, as the store writes it.
        let saved: String
        var role = ""
        var email: String?
        var summary = ""
    }

    private let backendEngineer = StoredCV(
        identity: "6B1F6C1E-1B8C-4C1B-9D55-1F3B2C8B7A01", title: "Backend Engineer", person: "Mara Ellison",
        saved: "2026-01-02T00:00:00Z")
    private let dataAnalyst = StoredCV(
        identity: "7C2A7D2F-2C9D-4D2C-8E66-2A4C3D9C8B02", title: "Data Analyst", person: "Orla Penhaligon",
        saved: "2026-01-01T00:00:00Z")
    /// A CV whose job title and e-mail address take more than a line at the largest text size.
    private let paymentsLead = StoredCV(
        identity: "8D3B8E3A-3DAE-4E3D-9F77-3B5D4EAD9C03", title: "Payments Lead", person: "Mara Ellison",
        saved: "2026-01-03T00:00:00Z", role: "Senior Backend Engineer, Payments Platform",
        email: "mara.ellison@example.com")
    /// A CV whose summary takes many more lines than an empty summary, at every text size and on every screen.
    private let platformLead = StoredCV(
        identity: "9E4C9F4B-4EBF-4F4E-8A88-4C6E5FBE8D04", title: "Platform Lead", person: "Ines Corr",
        saved: "2026-01-04T00:00:00Z",
        summary: "Backend engineer with ten years in payments and banking. I lead a team of six that runs the card "
            + "platform, from the first design to the nights on call. I moved our settlement jobs to a queue that "
            + "never loses a payment, cut the time of a release from a day to an hour, and wrote the guide our new "
            + "engineers follow in their first month. I review each change with care and keep the tests close to "
            + "the code they check. Before payments I built the booking system of a regional rail company, where I "
            + "learned to plan a migration in small steps that can each be undone. I like plain code, short "
            + "meetings, clear notes and teams that share what they learn.")

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
        app.launchArguments += [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVNextEmptyStorage", "-PrestoCVNextReadyDesigns",
        ]
        if !cvs.isEmpty {
            app.launchArguments += ["-PrestoCVNextSeed", try seed(cvs)]
        }
        // The default size is named too, so that a test can measure text at the size the app shows it
        let size = largestText ? UIContentSizeCategory.accessibilityExtraExtraExtraLarge : .large
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", size.rawValue]
        app.launch()
        return app
    }

    private func seed(_ cvs: [StoredCV]) throws -> String {
        var files: [String: String] = [:]
        for cv in cvs {
            // The store leaves out an e-mail address the CV does not have
            let email = cv.email.map { #""email":"\#($0)","# } ?? ""
            // The store reads a CV from the file named by its identity
            files["\(cv.identity).cv.json"] = """
            {"schemaVersion":1,"id":"\(cv.identity)","revision":1,
             "createdAt":"2026-01-01T00:00:00Z","updatedAt":"\(cv.saved)","title":"\(cv.title)",
             "personal":{"fullName":"\(cv.person)","professionalTitle":"\(cv.role)",\(email)"location":"",
                         "summary":"\(cv.summary)"},
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
        let title = textInput("editor.field.title", in: app)
        XCTAssertTrue(title.waitForExistence(timeout: 30), "The form of \(cv.title) opens")
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

    /// The text input with this identifier, of either kind: a field of one line wraps at the largest text sizes, and
    /// XCUITest may then show it as a text view.
    private func textInput(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        let kinds = NSPredicate(
            format: "elementType == %lu OR elementType == %lu",
            XCUIElement.ElementType.textField.rawValue, XCUIElement.ElementType.textView.rawValue)
        return app.descendants(matching: .any).matching(identifier: identifier).matching(kinds).firstMatch
    }

    private func status(of app: XCUIApplication) -> XCUIElement {
        app.staticTexts["editor.status"]
    }

    /// The key of the on-screen keyboard with this character, in either case.
    private func key(_ character: String, in app: XCUIApplication) -> XCUIElement {
        app.keyboards.keys.matching(NSPredicate(format: "label ==[c] %@", character)).firstMatch
    }

    /// The return key of the on-screen keyboard, a button or a key: "next" where the field moves on, "return" where the
    /// system words it so.
    private func returnKey(in app: XCUIApplication) -> XCUIElement {
        let returnKey = NSPredicate(
            format: "(elementType == %lu OR elementType == %lu) AND (label ==[c] 'next' OR label ==[c] 'return')",
            XCUIElement.ElementType.button.rawValue, XCUIElement.ElementType.key.rawValue)
        return app.keyboards.descendants(matching: .any).matching(returnKey).firstMatch
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

    @MainActor
    private func waitUntilFocused(_ element: XCUIElement) -> Bool {
        let focused = expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: element)
        return XCTWaiter().wait(for: [focused], timeout: 30) == .completed
    }

    /// Puts the cursor after the text of the field and types: a tap near its end, past the last word, and low in the
    /// field, on its last line where the field wraps. A tap at the middle of a field of two lines lands at the end of
    /// the first.
    @MainActor
    private func append(_ text: String, to field: XCUIElement) {
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.9)).tap()
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
            app.backButton.tap()
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
            app.backButton.tap()
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
        app.scrollForm(until: field, named: name)
        field.tap()
        XCTAssertTrue(keyboard.waitForExistence(timeout: 30), "\(name) brings up the software keyboard")
        if isCompact(app) {
            checkKeys()
        }
        XCTAssertTrue(done.waitForExistence(timeout: 30), "A Done button is above the keyboard of \(name)")
        done.tap()
        XCTAssertTrue(waitUntilGone(keyboard), "Done puts the keyboard of \(name) away")
    }

    /// An e-mail address being typed is not one yet: the line under the title says the text is not stored, and names no
    /// problem. Once the person leaves the field (here with Done), the line points to the note under it. The note itself
    /// is hidden from accessibility, since the field carries its words for VoiceOver, so it is not in the tree a UI test
    /// reads; which field has a note is the editor's (`FieldProblemTests`).
    @MainActor
    func testEmailProblemIsNamedOnlyAfterLeavingTheField() throws {
        let app = try launch([backendEngineer], largestText: false)
        open(backendEngineer, in: app)

        let email = app.textFields["editor.field.email"]
        app.scrollForm(until: email, named: "The e-mail address")
        email.tap()
        email.typeText("mara.at.example")

        // No problem is named while the person types
        XCTAssertTrue(waitUntil(status(of: app), reads: unsavedChanges), status(of: app).label)

        app.buttons["keyboard.done"].tap()

        XCTAssertTrue(waitUntil(status(of: app), reads: oneFieldNotSaved), status(of: app).label)
        XCTAssertTrue(email.exists, "The note under the field leaves its identifier on the text field")
    }

    // MARK: Moving on

    /// The return key of a field of one line moves to the next field and leaves the text as it was: the CV name keeps
    /// no line break, and nothing is left to store.
    @MainActor
    func testReturnKeyMovesToTheNextField() throws {
        try checkReturnKeyMovesOn(largestText: false)
    }

    /// The same where the field wraps onto more lines, at the largest text size, and its return key would start a new
    /// line.
    @MainActor
    func testReturnKeyMovesOnWhereTheFieldWraps() throws {
        try checkReturnKeyMovesOn(largestText: true)
    }

    @MainActor
    private func checkReturnKeyMovesOn(largestText: Bool) throws {
        let app = try launch([backendEngineer], largestText: largestText)
        open(backendEngineer, in: app)
        XCTAssertTrue(waitUntil(status(of: app), reads: saved), status(of: app).label)

        let title = textInput("editor.field.title", in: app)
        app.scrollForm(until: title, named: "The CV name")
        title.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.9)).tap()
        let next = returnKey(in: app)
        XCTAssertTrue(next.waitForExistence(timeout: 30), "The keyboard of the CV name has a return key")
        next.tap()

        let fullName = textInput("editor.field.fullName", in: app)
        XCTAssertTrue(waitUntilFocused(fullName), "The return key moves to the full name")
        XCTAssertEqual(title.value as? String, backendEngineer.title, "The CV name keeps no line break")
        let statusLine = status(of: app)
        app.scrollForm(until: statusLine, named: "The status", forward: false)
        XCTAssertEqual(statusLine.label, saved, "Nothing is left to store")
    }

    /// A text of two lines pasted into a field of one line keeps its words, with a space for the break, also where the
    /// field wraps and would keep the break. The text is put on the pasteboard as another app would put it.
    @MainActor
    func testPastedLineBreakBecomesASpace() throws {
        let app = try launch([backendEngineer], largestText: true)
        open(backendEngineer, in: app)
        UIPasteboard.general.string = "Payments platform.\nTeam of six."

        let location = textInput("editor.field.location", in: app)
        app.scrollForm(until: location, named: "The location")
        location.tap()
        XCTAssertTrue(waitUntilFocused(location), "A tap gives the location the keyboard focus")
        // A tap on the caret of a focused field opens its menu. The caret of the empty field is at its leading edge, and
        // the tap goes there, high in the field: on an iPhone at the largest size the keyboard's Done bar reaches up to
        // the middle of the field, and a tap at the middle did not reach the field.
        location.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.2)).tap()
        tapPaste(of: "The location", in: app)

        let oneLine = "Payments platform. Team of six."
        let pasted = expectation(for: NSPredicate(format: "value == %@", oneLine), evaluatedWith: location)
        XCTAssertEqual(XCTWaiter().wait(for: [pasted], timeout: 30), .completed, String(describing: location.value))
        let statusLine = status(of: app)
        app.scrollForm(until: statusLine, named: "The status", forward: false)
        XCTAssertTrue(waitUntil(statusLine, reads: saved), statusLine.label)
    }

    /// Taps Paste in the edit menu once it shows. Paste is the first item of the menu at a caret, so it shows also where
    /// the menu is too narrow for its items: on an iPhone at the largest text size the menu shows only its first item
    /// and an arrow, the arrow opens the others as a list that scrolls, and only the rows in view can be found.
    @MainActor
    private func tapPaste(of name: String, in app: XCUIApplication) {
        let paste = app.menuItems["Paste"]
        XCTAssertTrue(paste.waitForExistence(timeout: 30), "The menu of \(name) offers Paste")
        paste.tap()
    }

    // MARK: Accessibility

    /// At the largest text size every field can be reached and tapped, and is at least as tall as the smallest tap target.
    @MainActor
    func testDetailsAtTheLargestTextSize() throws {
        let app = try launch([backendEngineer], largestText: true)
        open(backendEngineer, in: app)

        for field in fields {
            let element = textInput(field.identifier, in: app)
            app.scrollForm(until: element, named: field.identifier)
            // A frame comes as a float: 44 points read 43.99…
            XCTAssertGreaterThan(element.frame.height, 43.99, "\(field.identifier) is tall enough to tap")
        }
    }

    /// At the largest text size a field of one line wraps onto more lines, so that a long job title and e-mail address
    /// can be read whole without editing them (#402): each holds its whole text and is taller than an empty field,
    /// which takes one line.
    @MainActor
    func testLongDetailsWrapAtTheLargestTextSize() throws {
        let app = try launch([paymentsLead], largestText: true)
        open(paymentsLead, in: app)

        let role = textInput("editor.field.professionalTitle", in: app)
        app.scrollForm(until: role, named: "The job title")
        XCTAssertEqual(role.value as? String, paymentsLead.role)
        let roleHeight = role.frame.height
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "A long job title at the largest text size"
        shot.lifetime = .keepAlways
        add(shot)

        let email = textInput("editor.field.email", in: app)
        app.scrollForm(until: email, named: "The e-mail address")
        XCTAssertEqual(email.value as? String, paymentsLead.email)
        let emailHeight = email.frame.height

        let location = textInput("editor.field.location", in: app)
        app.scrollForm(until: location, named: "The location")
        let oneLine = location.frame.height

        XCTAssertGreaterThan(roleHeight, oneLine * 1.5, "The job title takes more lines than an empty field")
        XCTAssertGreaterThan(emailHeight, oneLine * 1.5, "The e-mail address takes more lines than an empty field")
    }

    /// At the largest text size a drag that starts on a field of several lines scrolls the form, as on any other row:
    /// the field does not keep the drag to scroll its own text, which it shows whole.
    @MainActor
    func testADragOnAWrappedFieldScrollsTheForm() throws {
        let app = try launch([paymentsLead], largestText: true)
        open(paymentsLead, in: app)
        let role = textInput("editor.field.professionalTitle", in: app)
        checkADragScrollsTheForm(from: role, named: "The job title", in: app)
    }

    /// The same from a long summary, a field of several lines that grows with its text: at the largest text size it is
    /// taller than the screen and its text fills it, so it could scroll that text if it came out shorter than it. An
    /// empty summary is taller than its text and could never take the drag.
    @MainActor
    func testADragOnTheSummaryScrollsTheForm() throws {
        let app = try launch([platformLead], largestText: true)
        open(platformLead, in: app)
        checkADragScrollsTheForm(from: app.textViews["editor.field.summary"], named: "The summary", in: app)
    }

    /// A long summary shows whole, at the default text size: the summary grows with its text, which it never scrolls
    /// (#402), so it is at least as tall as its text laid out at the field's width, on a narrow screen and a wide one
    /// alike, while an empty one is about four lines tall.
    /// - The text is measured at the field's whole width, wider than the text view lays it out in, which keeps a margin
    ///   on each side: it breaks into no more lines than the field's, so its height is a floor of the field's.
    /// - XCUITest reads the frame of a field partly off the screen clipped to the screen, so the form first scrolls
    ///   until the whole field lies on it.
    @MainActor
    func testALongSummaryShowsWhole() throws {
        let app = try launch([platformLead], largestText: false)
        open(platformLead, in: app)
        let form = element("shell.detail.opened", in: app)
        let summary = app.textViews["editor.field.summary"]
        app.scrollForm(
            until: {
                summary.exists && form.frame.minY < summary.frame.minY && summary.frame.maxY + 10 < form.frame.maxY
            },
            named: "The whole summary")
        XCTAssertEqual(summary.value as? String, platformLead.summary)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "A long summary"
        shot.lifetime = .keepAlways
        add(shot)

        let body = UIFont.preferredFont(
            forTextStyle: .body, compatibleWith: UITraitCollection(preferredContentSizeCategory: .large))
        let text = (platformLead.summary as NSString).boundingRect(
            with: CGSize(width: summary.frame.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: body], context: nil)
        XCTAssertGreaterThan(text.height, body.lineHeight * 5, "The summary's text takes more lines than an empty one")
        XCTAssertGreaterThanOrEqual(summary.frame.height, text.height, "The summary is as tall as its text")
    }

    /// Scrolls until the field's top lies on the form, more than 250 pt below the form's top and 150 pt above its
    /// bottom, and drags the form up 200 pt from 40 pt under the field's top, held at the end so that the form does not
    /// glide on: the field's top moves up with the form by more than 50 pt.
    /// - The drag starts near the field's top: a field that can be tapped may still have its middle off the screen,
    ///   and a drag from there never touches the field.
    /// - The field's top stays on the screen through the drag: once the top of a field taller than the screen passes
    ///   above the screen, XCUITest clips the field's frame to the screen, and its top then reads 0 however far the
    ///   form moved.
    /// - The drag goes up, toward the text's end: a text view whose text starts at its top lets a drag down pass to
    ///   the form, so only a drag up shows whether it scrolls its own text.
    @MainActor
    private func checkADragScrollsTheForm(from field: XCUIElement, named name: String, in app: XCUIApplication) {
        let form = element("shell.detail.opened", in: app)
        app.scrollForm(
            until: {
                guard field.exists else { return false }
                let top = field.frame.minY
                return form.frame.minY + 250 < top && top + 150 < form.frame.maxY
            },
            named: name)
        let top = field.frame.minY
        let start = field.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: field.frame.width / 2, dy: min(40, field.frame.height / 2)))
        start.press(
            forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -200)), withVelocity: .slow,
            thenHoldForDuration: 0.2)
        XCTAssertLessThan(field.frame.minY, top - 50, "A drag on \(name.lowercased()) scrolls the form")
    }

    /// VoiceOver reads each field by its label, the summary's text view included.
    @MainActor
    func testDetailsLabelsForVoiceOver() throws {
        let app = try launch([backendEngineer], largestText: false)
        open(backendEngineer, in: app)

        for field in fields {
            let element = app.descendants(matching: field.type)[field.identifier]
            app.scrollForm(until: element, named: field.identifier)
            XCTAssertEqual(element.label, field.label, field.identifier)
        }
    }
}
