import XCTest

/// The rows of the open CV's sections. A row the person adds comes into view with the cursor in its first field. A row
/// with something in it goes only once the person confirms, in a dialog that names it; a blank row goes at once. Delete is
/// behind a swipe, in the row's context menu and among its VoiceOver actions. The level of a skill and of a language are
/// menus, and every field stays tall enough to tap at the largest text size.
final class EditorRowsUITests: XCTestCase {

    private let identity = "8D3A8E3A-3DAE-4E3D-9F77-3B5D4EAD9C03"
    private let title = "Site Foreman"

    /// Each section with the first field of a new row, the label VoiceOver reads for it, and a text to type in it.
    private let sections: [(name: String, first: String, label: String, text: String)] = [
        ("experiences", "editor.field.experienceRole", "Role", "Foreman"),
        ("education", "editor.field.educationDegree", "Degree", "Surveying"),
        ("skills", "editor.field.skillName", "Skill", "Welding"),
        ("languages", "editor.field.language", "Language", "German"),
        ("certifications", "editor.field.certificationName", "Certification", "Rigging"),
        ("profiles", "editor.field.profilePlatform", "Platform", "Mastodon"),
        ("interests", "editor.field.interest", "Interest", "Cycling"),
    ]

    /// The menu of a row of the section, where it has one.
    private let menus = ["skills": "editor.field.skillLevel", "languages": "editor.field.languageProficiency"]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: Launching

    /// A store folder of its own with one CV whose sections are empty, in English, opened.
    @MainActor
    private func launchAndOpen(largestText: Bool = false) throws -> XCUIApplication {
        let app = XCUIApplication()
        // The store reads a CV from the file named by its identity; the fixture takes a JSON map from file name to
        // content, in base 64
        let cv = """
        {"schemaVersion":1,"id":"\(identity)","revision":1,
         "createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-02T00:00:00Z","title":"\(title)",
         "personal":{"fullName":"Dario Venn","professionalTitle":"","location":"","summary":""},
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
        return app
    }

    // MARK: Rows

    /// Adds a row to the section and waits for the keyboard of its first field.
    @MainActor
    private func addRow(to section: String, in app: XCUIApplication) {
        let add = app.buttons["editor.add.\(section)"]
        app.scrollForm(until: add, named: "The add button of \(section)")
        add.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 30), "A new row of \(section) takes the keyboard")
    }

    /// Adds a row, types in its first field, and puts the keyboard away.
    @MainActor
    private func addRow(to section: String, typing text: String, in app: XCUIApplication) {
        addRow(to: section, in: app)
        app.typeText(text)
        putKeyboardAway(in: app)
    }

    @MainActor
    private func putKeyboardAway(in app: XCUIApplication) {
        app.buttons["keyboard.done"].tap()
        XCTAssertTrue(waitUntilGone(app.keyboards.firstMatch), "Done puts the keyboard away")
    }

    /// The Delete of the dialog: the swipe's own Delete, closed once tapped, may stay in the tree.
    @MainActor
    private func confirmDelete(in app: XCUIApplication) {
        let delete = app.buttons.matching(NSPredicate(format: "label == %@", "Delete")).allElementsBoundByIndex
            .last { $0.canBeTapped(in: app) }
        XCTAssertNotNil(delete, "The dialog offers Delete")
        delete?.tap()
    }

    /// Closes the dialog without deleting: its Cancel where it has one, else a tap outside the popover it is.
    @MainActor
    private func cancelDialog(in app: XCUIApplication) {
        let cancel = app.buttons["Cancel"]
        if cancel.exists {
            cancel.tap()
        } else {
            app.otherElements["PopoverDismissRegion"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)).tap()
        }
    }

    // MARK: Waiting and moving

    @MainActor
    private func waitUntil(_ element: XCUIElement, holds value: String) -> Bool {
        let holds = expectation(for: NSPredicate(format: "value == %@", value), evaluatedWith: element)
        return XCTWaiter().wait(for: [holds], timeout: 30) == .completed
    }

    @MainActor
    private func waitUntilGone(_ element: XCUIElement) -> Bool {
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element)
        return XCTWaiter().wait(for: [gone], timeout: 30) == .completed
    }

    // MARK: Adding

    /// Each section adds a row whose first field takes the cursor: what the person types lands there. VoiceOver reads
    /// the field by its label. A new study shows its description and a new certification its year, which is empty.
    @MainActor
    func testAddRowFocusesItsFirstField() throws {
        let app = try launchAndOpen()

        for section in sections {
            addRow(to: section.name, in: app)
            app.typeText(section.text)
            let first = app.textFields[section.first]
            XCTAssertTrue(waitUntil(first, holds: section.text), "The new row of \(section.name) has the cursor")
            XCTAssertEqual(first.label, section.label, section.first)
            putKeyboardAway(in: app)
            // Checked while the new row is in view: the form loads only the rows on screen
            switch section.name {
            case "education":
                let description = app.textViews["editor.field.educationDescription"]
                XCTAssertTrue(description.exists, "A new study shows its description")
            case "certifications":
                let year = app.textFields["editor.field.certificationIssued"]
                XCTAssertTrue(year.exists, "A new certification shows its year")
                XCTAssertEqual(year.value as? String ?? "", "", "An empty year is empty, never 0")
            default: break
            }
        }
    }

    /// Rows added one after another to a long section: the add button sits at the foot of the screen, and each new row
    /// still comes into view above the keyboard, with the cursor in its first field.
    @MainActor
    func testAddedRowsOfALongSectionComeIntoView() throws {
        let app = try launchAndOpen()

        for number in 1...4 {
            addRow(to: "experiences", in: app)
            let text = "Foreman \(number)"
            app.typeText(text)
            let role = app.textFields.matching(identifier: "editor.field.experienceRole")
                .matching(NSPredicate(format: "value == %@", text)).firstMatch
            XCTAssertTrue(role.waitForExistence(timeout: 30), "Row \(number) has the cursor")
            let inView = expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: role)
            XCTAssertEqual(XCTWaiter().wait(for: [inView], timeout: 30), .completed, "Row \(number) is in view")
            putKeyboardAway(in: app)
        }
    }

    // MARK: Removing

    /// A swipe offers Delete; a row with text goes only once the person confirms, in a dialog that names it. Cancel
    /// keeps it.
    @MainActor
    func testRemoveAsksAndNamesTheRow() throws {
        let app = try launchAndOpen()
        addRow(to: "skills", typing: "Welding", in: app)
        let skill = app.textFields["editor.field.skillName"]
        let question = app.staticTexts["Delete “Welding”?"]

        skill.swipeLeft()
        app.buttons["Delete"].tap()
        XCTAssertTrue(question.waitForExistence(timeout: 30), "The dialog names the row")
        XCTAssertTrue(app.staticTexts["This cannot be undone."].exists)
        cancelDialog(in: app)
        XCTAssertTrue(waitUntilGone(question))
        XCTAssertEqual(skill.value as? String, "Welding", "Cancel keeps the row")

        skill.swipeLeft()
        app.buttons["Delete"].tap()
        XCTAssertTrue(question.waitForExistence(timeout: 30))
        confirmDelete(in: app)
        XCTAssertTrue(waitUntilGone(skill), "The row goes once the person confirms")
    }

    /// A row with nothing in it goes at once: there is nothing to lose, so no dialog asks.
    @MainActor
    func testBlankRowGoesAtOnce() throws {
        let app = try launchAndOpen()
        addRow(to: "interests", in: app)
        putKeyboardAway(in: app)
        let interest = app.textFields["editor.field.interest"]

        interest.swipeLeft()
        app.buttons["Delete"].tap()

        XCTAssertTrue(waitUntilGone(interest), "The blank row goes")
        XCTAssertFalse(app.staticTexts["Delete “Unnamed interest”?"].exists, "No dialog asks")
    }

    /// VoiceOver's action "Delete <name>" is the context menu's button, which a UI test can reach: XCUITest has no call
    /// for a custom action. The long press lands on the label above the field, away from its text.
    @MainActor
    func testRowDeleteByAccessibilityAction() throws {
        let app = try launchAndOpen()
        addRow(to: "languages", typing: "German", in: app)
        let language = app.textFields["editor.field.language"]

        language.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: -0.3)).press(forDuration: 1.2)
        let delete = app.buttons["Delete German"]
        XCTAssertTrue(delete.waitForExistence(timeout: 30), "The menu names the row")
        delete.tap()

        XCTAssertTrue(app.staticTexts["Delete “German”?"].waitForExistence(timeout: 30))
        confirmDelete(in: app)
        XCTAssertTrue(waitUntilGone(language), "The row goes once the person confirms")
    }

    // MARK: Choosing

    /// The level of a skill and of a language are menus of words: "3 of 5", and the levels of the European framework.
    @MainActor
    func testLevelAndProficiencyPickers() throws {
        let app = try launchAndOpen()
        addRow(to: "skills", typing: "Welding", in: app)
        choose("3 of 5", in: "skills", label: "Level", app)
        addRow(to: "languages", typing: "German", in: app)
        choose("B2 – Upper intermediate", in: "languages", label: "Proficiency", app)
    }

    /// Opens the menu of the section's row, checks that it offers no level too, picks `choice`, and checks that the menu
    /// shows it.
    @MainActor
    private func choose(_ choice: String, in section: String, label: String, _ app: XCUIApplication) {
        let menu = app.buttons.matching(identifier: menus[section] ?? "").firstMatch
        app.scrollForm(until: menu, named: "The menu \(label)")
        XCTAssertTrue(menu.label.contains(label), "\(menu.label) reads its name")
        menu.tap()
        XCTAssertTrue(app.buttons["Not set"].waitForExistence(timeout: 30), "The menu \(label) offers no level")
        app.buttons[choice].tap()
        let shows = NSPredicate { element, _ in
            guard let element = element as? XCUIElement else { return false }
            return element.label.contains(choice) || (element.value as? String) == choice
        }
        XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: shows, evaluatedWith: menu)], timeout: 30), .completed,
                       "The menu \(label) shows \(choice)")
    }

    // MARK: Accessibility

    /// At the largest text size the first field of each new row, its menu and its section's add button can be reached,
    /// and are at least as tall as the smallest tap target.
    @MainActor
    func testRowsAtTheLargestTextSize() throws {
        let app = try launchAndOpen(largestText: true)

        for section in sections {
            addRow(to: section.name, in: app)
            putKeyboardAway(in: app)
            // In the order of the form, since the form only scrolls on
            var targets = [(section.first, app.textFields[section.first])]
            if let menu = menus[section.name] {
                targets.append((menu, app.buttons.matching(identifier: menu).firstMatch))
            }
            targets.append(("editor.add.\(section.name)", app.buttons["editor.add.\(section.name)"]))
            for (name, target) in targets {
                app.scrollForm(until: target, named: name)
                // A frame comes as a float: 44 points read 43.99…
                XCTAssertGreaterThan(target.frame.height, 43.99, "\(name) is tall enough to tap")
            }
        }
    }
}
