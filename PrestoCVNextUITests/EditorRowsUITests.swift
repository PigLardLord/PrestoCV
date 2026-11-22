import XCTest

/// The rows of the open CV's sections. A row the person adds comes into view with the cursor in its first field. A row
/// with something in it goes only once the person confirms, in a dialog that names it; a blank row goes at once. Delete is
/// behind a swipe, in the row's context menu and among its VoiceOver actions. The level of a skill and of a language are
/// menus, and every field stays tall enough to tap at the largest text size. On a narrow screen a new job, study,
/// language, certification or profile opens on a page of its own, and its row in the form names what was typed.
final class EditorRowsUITests: RuntimeIssueFailingTestCase {

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
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVNextEmptyStorage", "-PrestoCVNextReadyDesigns",
            "-PrestoCVNextSeed", seed,
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

    /// Adds a row to the section from the CV's form, leaving the page of a row first where one is open, and waits for
    /// the keyboard of its first field. On a narrow screen the new row's page opens.
    @MainActor
    private func addRow(to section: String, in app: XCUIApplication) {
        if app.entryPage.exists { app.leaveEntryPage() }
        let add = app.buttons["editor.add.\(section)"]
        app.scrollForm(until: add, named: "The add button of \(section)")
        add.tap()
        if app.opensOnAPage(section) {
            XCTAssertTrue(app.entryPage.waitForExistence(timeout: 30), "A new row of \(section) opens its page")
        }
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 30), "A new row of \(section) takes the keyboard")
    }

    /// Goes back from the page of a row, where one is open, and checks that the row in the form names `text`.
    @MainActor
    private func leavePage(of section: String, naming text: String, in app: XCUIApplication) {
        guard app.entryPage.exists else { return }
        app.leaveEntryPage()
        let row = app.buttons["editor.entry.\(section)"]
        app.scrollForm(until: row, named: "The row of \(section)", forward: false)
        XCTAssertTrue(row.label.contains(text), "\(row.label) names \(text)")
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
        XCTAssertTrue(app.keyboards.firstMatch.waitUntilGone(), "Done puts the keyboard away")
    }

    /// The Delete of the dialog: the swipe's own Delete, closed once tapped, may stay in the tree.
    @MainActor
    private func confirmDelete(in app: XCUIApplication) {
        let delete = app.buttons.matching(NSPredicate(format: "label == %@", "Delete")).allElementsBoundByIndex
            .last { $0.canBeTapped(in: app) }
        XCTAssertNotNil(delete, "The dialog offers Delete")
        delete?.tap()
    }

    // MARK: Adding

    /// Each section adds a row whose first field takes the cursor: what the person types lands there. VoiceOver reads
    /// the field by its label. A new study shows its description and a new certification its year, which is empty. Where
    /// the row opened on a page, back shows it in the form under what was typed.
    @MainActor
    func testAddRowFocusesItsFirstField() throws {
        let app = try launchAndOpen()

        for section in sections {
            addRow(to: section.name, in: app)
            app.typeText(section.text)
            let first = app.textFields[section.first]
            XCTAssertTrue(first.waitUntil(holds: section.text), "The new row of \(section.name) has the cursor")
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
            leavePage(of: section.name, naming: section.text, in: app)
        }
    }

    /// Rows added one after another to a long section: the add button sits at the foot of the screen, and each new row
    /// still comes into view above the keyboard, with the cursor in its first field. Skills stay in the form on every
    /// screen.
    @MainActor
    func testAddedRowsOfALongSectionComeIntoView() throws {
        let app = try launchAndOpen()

        for number in 1...4 {
            addRow(to: "skills", in: app)
            let text = "Welding \(number)"
            app.typeText(text)
            let skill = app.textFields.matching(identifier: "editor.field.skillName")
                .matching(NSPredicate(format: "value == %@", text)).firstMatch
            XCTAssertTrue(skill.waitForExistence(timeout: 30), "Row \(number) has the cursor")
            let inView = expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: skill)
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
        app.cancelDialog(showing: question)
        XCTAssertTrue(question.waitUntilGone())
        XCTAssertEqual(skill.value as? String, "Welding", "Cancel keeps the row")

        skill.swipeLeft()
        app.buttons["Delete"].tap()
        XCTAssertTrue(question.waitForExistence(timeout: 30))
        confirmDelete(in: app)
        XCTAssertTrue(skill.waitUntilGone(), "The row goes once the person confirms")
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

        XCTAssertTrue(interest.waitUntilGone(), "The blank row goes")
        XCTAssertFalse(app.staticTexts["Delete “Unnamed interest”?"].exists, "No dialog asks")
    }

    /// VoiceOver's action "Delete <name>" is the context menu's button, which a UI test can reach: XCUITest has no call
    /// for a custom action. The long press lands on the label above the field, away from its text. A skill stays in the
    /// form on every screen; the menu of a row on a page is in `EntryPageUITests`.
    @MainActor
    func testRowDeleteByAccessibilityAction() throws {
        let app = try launchAndOpen()
        addRow(to: "skills", typing: "Welding", in: app)
        let skill = app.textFields["editor.field.skillName"]

        skill.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: -0.3)).press(forDuration: 1.2)
        let delete = app.buttons["Delete Welding"]
        XCTAssertTrue(delete.waitForExistence(timeout: 30), "The menu names the row")
        delete.tap()

        XCTAssertTrue(app.staticTexts["Delete “Welding”?"].waitForExistence(timeout: 30))
        confirmDelete(in: app)
        XCTAssertTrue(skill.waitUntilGone(), "The row goes once the person confirms")
    }

    // MARK: Staying

    /// What is typed is stored, and an app ended in the background does not lose it: the next launch on the same store
    /// folder lists the CV under its new title.
    @MainActor
    func testWhatIsTypedSurvivesTheAppBeingEndedInTheBackground() throws {
        let folder = "rows-\(UUID().uuidString)"
        let app = XCUIApplication()
        let file = XCUIApplication.storedCV(identity: identity, title: title)
        app.launchArguments += [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVNextStorage", folder,
            "-PrestoCVNextSeed", try XCUIApplication.seed(["\(identity).cv.json": file]),
        ]
        app.launch()
        app.openCV(titled: title)
        let field = app.textInput("editor.field.title")
        field.tap()
        field.append(" Lead")
        XCTAssertTrue(app.staticTexts["editor.status"].waitUntil(reads: "Saved on this device"), "The text is stored")

        app.terminate()
        app.launchArguments = [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVNextStorage", folder,
        ]
        app.launch()

        XCTAssertTrue(app.listRow(titled: "\(title) Lead").waitForExistence(timeout: 30), "The next launch lists the new title")
    }

    /// The swipe from the left edge leaves like Back, once the text is stored; a wide window shows the list beside.
    @MainActor
    func testTheEdgeSwipeLeavesLikeBack() throws {
        let app = try launchAndOpen()
        try XCTSkipUnless(app.isCompactWidth, "Only a narrow window has the edge swipe")
        let field = app.textInput("editor.field.title")
        field.tap()
        field.append(" Lead")
        XCTAssertTrue(app.staticTexts["editor.status"].waitUntil(reads: "Saved on this device"), "The text is stored")
        putKeyboardAway(in: app)

        app.swipeBackFromTheLeftEdge()

        XCTAssertTrue(app.listRow(titled: "\(title) Lead").waitForExistence(timeout: 30), "The edge swipe leaves to the list")
    }

    /// The swipe from the edge before the pause that stores the text stores it first, then leaves.
    @MainActor
    func testTheEdgeSwipeBeforeThePauseStoresThenLeaves() throws {
        let app = try launchAndOpen()
        try XCTSkipUnless(app.isCompactWidth, "Only a narrow window has the edge swipe")
        let field = app.textInput("editor.field.title")
        field.tap()
        field.append(" Lead")

        app.swipeBackFromTheLeftEdge()

        XCTAssertTrue(app.listRow(titled: "\(title) Lead").waitForExistence(timeout: 30), "The list shows the typed title")
    }

    // MARK: Describing

    /// The description of a study takes text, loses it letter by letter, and takes new text.
    @MainActor
    func testEducationDescriptionCanBeTypedClearedAndTypedAgain() throws {
        let app = try launchAndOpen()
        addRow(to: "education", in: app)
        let description = app.textViews["editor.field.educationDescription"]
        app.scrollForm(until: description, named: "The description of a study")
        description.tap()

        app.typeText("Thesis on triage")
        XCTAssertTrue(description.waitUntil(holds: "Thesis on triage"), "The description takes the text")
        app.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Thesis on triage".count))
        XCTAssertTrue(description.waitUntil(holds: ""), "The description empties")
        app.typeText("Second thought")
        XCTAssertTrue(description.waitUntil(holds: "Second thought"), "The description takes new text")
    }

    // MARK: Removing more

    /// The control of a section's row in the form: the row that opens a page where the section opens on one, the first
    /// field where it stays in place.
    @MainActor
    private func control(of section: String, in app: XCUIApplication) -> XCUIElement {
        if app.opensOnAPage(section) { return app.buttons["editor.entry.\(section)"] }
        let first = sections.first { $0.name == section }?.first ?? ""
        return app.textFields[first]
    }

    /// Adds a row of the section with this text, goes back to the form, and swipes the row to Delete.
    @MainActor
    private func swipeToDelete(_ section: String, typing text: String, in app: XCUIApplication) -> XCUIElement {
        addRow(to: section, typing: text, in: app)
        if app.entryPage.exists { app.leaveEntryPage() }
        let row = control(of: section, in: app)
        app.scrollForm(until: row, named: "The row of \(section)", forward: false)
        row.swipeLeft()
        app.buttons["Delete"].tap()
        return row
    }

    @MainActor
    private func assertDeletedAfterTheQuestion(_ section: String, typing text: String) throws {
        let app = try launchAndOpen()
        let row = swipeToDelete(section, typing: text, in: app)
        let question = app.staticTexts["Delete “\(text)”?"]
        XCTAssertTrue(question.waitForExistence(timeout: 30), "The dialog names the row")
        XCTAssertTrue(row.exists, "The row stays until the person confirms")

        confirmDelete(in: app)

        XCTAssertTrue(row.waitUntilGone(), "The row goes once the person confirms")
    }

    @MainActor
    func testAnEducationIsDeletedAfterTheQuestion() throws {
        try assertDeletedAfterTheQuestion("education", typing: "Surveying")
    }

    @MainActor
    func testACertificationIsDeletedAfterTheQuestion() throws {
        try assertDeletedAfterTheQuestion("certifications", typing: "Rigging")
    }

    @MainActor
    func testASocialLinkIsDeletedAfterTheQuestion() throws {
        try assertDeletedAfterTheQuestion("profiles", typing: "Mastodon")
    }

    /// A certification with nothing in it goes at once: no dialog asks.
    @MainActor
    func testABlankCertificationIsDeletedAtOnce() throws {
        let app = try launchAndOpen()
        addRow(to: "certifications", in: app)
        putKeyboardAway(in: app)
        if app.entryPage.exists { app.leaveEntryPage() }
        let row = control(of: "certifications", in: app)
        app.scrollForm(until: row, named: "The row of certifications", forward: false)

        row.swipeLeft()
        app.buttons["Delete"].tap()

        XCTAssertTrue(row.waitUntilGone(), "The blank row goes")
        XCTAssertFalse(app.staticTexts["Delete “Unnamed certification”?"].exists, "No dialog asks")
    }

    // MARK: Swiping and tapping beside

    /// Adds a row of the section with this text, leaves it open (on a narrow screen its page), and returns the app with
    /// the row's menu.
    @MainActor
    private func launchWithARowOf(_ section: String, typing text: String) throws -> (XCUIApplication, XCUIElement) {
        let app = try launchAndOpen()
        addRow(to: section, typing: text, in: app)
        let menu = app.buttons.matching(identifier: menus[section] ?? "").firstMatch
        app.scrollForm(until: menu, named: "The menu of \(section)")
        return (app, menu)
    }

    /// The words that name where the control stands: a menu reads its choice, a text view its text.
    @MainActor
    private func state(of element: XCUIElement) -> String {
        "\(element.label)|\(element.value as? String ?? "")"
    }

    /// Taps next to the control, at the corners of its frame, and checks that no row went and no dialog asked.
    @MainActor
    private func assertTapsBesideDeleteNothing(_ control: XCUIElement, in app: XCUIApplication, kept: String) {
        let before = state(of: control)
        for offset in [(0.97, 0.85), (0.6, 0.85), (0.03, 0.85), (0.97, 0.15)] {
            control.coordinate(withNormalizedOffset: CGVector(dx: offset.0, dy: offset.1)).tap()
            if app.buttons["Not set"].exists { app.buttons["Not set"].tap() }
            XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Delete “")).firstMatch.exists,
                           "No dialog asks")
        }
        XCTAssertTrue(control.exists, "The control stays")
        XCTAssertEqual(state(of: control), before, "Nothing changed")
        XCTAssertTrue(app.textFields.matching(NSPredicate(format: "value == %@", kept)).firstMatch.exists, "\(kept) stays")
    }

    /// Swipes left from the control's right end, far enough to open the row's actions, and checks that the row opened
    /// with its Delete, nothing was asked and the control changed nothing.
    @MainActor
    private func assertSwipeFromOpensTheRowAndChangesNothing(
        _ control: XCUIElement, in app: XCUIApplication, kept: String, opensActions: Bool
    ) {
        let before = state(of: control)
        let start = control.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: -160, dy: 0)))

        if opensActions {
            XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 30), "The swipe opens the row to Delete")
        }
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Delete “")).firstMatch.exists,
                       "Nothing is asked")
        XCTAssertEqual(state(of: control), before, "The control is unchanged")
        XCTAssertFalse(app.buttons["Not set"].exists, "No menu opened")
        XCTAssertTrue(app.textFields.matching(NSPredicate(format: "value == %@", kept)).firstMatch.exists, "\(kept) stays")
    }

    @MainActor
    func testATapBesideTheLevelDeletesNothing() throws {
        let (app, level) = try launchWithARowOf("skills", typing: "Welding")
        assertTapsBesideDeleteNothing(level, in: app, kept: "Welding")
    }

    @MainActor
    func testATapBesideTheLanguagePickerDeletesNothing() throws {
        let (app, picker) = try launchWithARowOf("languages", typing: "German")
        assertTapsBesideDeleteNothing(picker, in: app, kept: "German")
    }

    @MainActor
    func testASwipeFromTheLevelOpensTheRowAndChangesNothing() throws {
        let (app, level) = try launchWithARowOf("skills", typing: "Welding")
        assertSwipeFromOpensTheRowAndChangesNothing(level, in: app, kept: "Welding", opensActions: true)
    }

    /// A language opens on a page on a narrow screen, where a row has no swipe actions to open.
    @MainActor
    func testASwipeFromTheLanguagePickerOpensTheRowAndChangesNothing() throws {
        let (app, picker) = try launchWithARowOf("languages", typing: "German")
        assertSwipeFromOpensTheRowAndChangesNothing(
            picker, in: app, kept: "German", opensActions: !app.opensOnAPage("languages"))
    }

    /// A study's description is a page's field on a narrow screen, where a row has no swipe actions to open.
    @MainActor
    func testASwipeFromTheDescriptionOpensTheRowAndChangesNothing() throws {
        let app = try launchAndOpen()
        addRow(to: "education", typing: "Surveying", in: app)
        let description = app.textViews["editor.field.educationDescription"]
        app.scrollForm(until: description, named: "The description of a study")
        description.tap()
        app.typeText("Thesis on triage")
        putKeyboardAway(in: app)

        assertSwipeFromOpensTheRowAndChangesNothing(
            description, in: app, kept: "Surveying", opensActions: !app.opensOnAPage("education"))
    }

    // MARK: Neighbours

    /// Deleting the middle of three rows keeps the others, and the row that comes up into its place is closed.
    @MainActor
    func testDeletingARowKeepsItsNeighboursAndTheNextRowComesUpClosed() throws {
        let app = try launchAndOpen()
        for name in ["Welding", "Rigging", "Surveying"] { addRow(to: "skills", typing: name, in: app) }
        func skill(_ name: String) -> XCUIElement {
            app.textFields.matching(identifier: "editor.field.skillName").matching(NSPredicate(format: "value == %@", name)).firstMatch
        }
        skill("Rigging").swipeLeft()
        app.buttons["Delete"].tap()
        XCTAssertTrue(app.staticTexts["Delete “Rigging”?"].waitForExistence(timeout: 30))

        confirmDelete(in: app)

        XCTAssertTrue(skill("Rigging").waitUntilGone(), "The row goes")
        XCTAssertTrue(skill("Welding").exists, "The row before stays")
        XCTAssertTrue(skill("Surveying").exists, "The row after stays")
        let open = app.buttons.matching(NSPredicate(format: "label == %@", "Delete")).allElementsBoundByIndex
            .contains { $0.canBeTapped(in: app) }
        XCTAssertFalse(open, "The row that came up is closed")
    }

    /// Adding a row while another is swiped open keeps both, and the new row takes the cursor.
    @MainActor
    func testAddingARowWhileAnotherIsSwipedOpenKeepsBothAndFocusesTheNewOne() throws {
        let app = try launchAndOpen()
        addRow(to: "skills", typing: "Welding", in: app)
        let welding = app.textFields.matching(identifier: "editor.field.skillName")
            .matching(NSPredicate(format: "value == %@", "Welding")).firstMatch
        welding.swipeLeft()
        XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 30), "The row is open")

        // A tap beside an open row may only close it, as the system does for a swiped row; the row is then added by the
        // next tap. Where the first tap added it already, the next one would add a second.
        let add = app.buttons["editor.add.skills"]
        app.scrollForm(until: add, named: "The add button of skills")
        add.tap()
        XCTAssertTrue(app.buttons["Delete"].waitUntilGone(), "The first tap closes the open row")
        let names = app.textFields.matching(identifier: "editor.field.skillName")
        if names.count < 2 { addRow(to: "skills", in: app) }
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 30), "A new row of skills takes the keyboard")
        app.typeText("Rigging")

        let rigging = app.textFields.matching(identifier: "editor.field.skillName")
            .matching(NSPredicate(format: "value == %@", "Rigging")).firstMatch
        XCTAssertTrue(rigging.waitForExistence(timeout: 30), "The new row has the cursor")
        XCTAssertTrue(welding.exists, "The open row stays")
    }

    // MARK: Return

    /// Return in a field of a row ends the entry: the field lets go of the focus, the keyboard closes and it adds no line, at the normal and the largest size.
    @MainActor
    private func assertReturnEndsTheEntry(largestText: Bool) throws {
        let app = try launchAndOpen(largestText: largestText)
        addRow(to: "skills", in: app)

        app.typeText("Welding\n")

        let skill = app.textInput("editor.field.skillName")
        XCTAssertTrue(skill.waitUntilUnfocused(), "Return ends the entry of the field")
        XCTAssertTrue(app.keyboards.firstMatch.waitUntilGone(), "Return closes the keyboard")
        XCTAssertTrue(skill.waitUntil(holds: "Welding"), "Return adds no line to the field")
        XCTAssertEqual(app.textFields.matching(identifier: "editor.field.skillName").count
                       + app.textViews.matching(identifier: "editor.field.skillName").count, 1, "Return adds no row")
    }

    @MainActor
    func testReturnEndsTheEntryOfARowFieldInsteadOfAddingALine() throws {
        try assertReturnEndsTheEntry(largestText: false)
    }

    @MainActor
    func testReturnEndsTheEntryOfARowFieldAtTheLargestTextSize() throws {
        try assertReturnEndsTheEntry(largestText: true)
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
    /// and are at least as tall as the smallest tap target; so is the row in the form, where the new row opened on a
    /// page.
    @MainActor
    func testRowsAtTheLargestTextSize() throws {
        let app = try launchAndOpen(largestText: true)

        for section in sections {
            addRow(to: section.name, in: app)
            putKeyboardAway(in: app)
            // In the order of the form or the page, since the form only scrolls on
            var targets = [(section.first, app.textFields[section.first])]
            if let menu = menus[section.name] {
                targets.append((menu, app.buttons.matching(identifier: menu).firstMatch))
            }
            checkTall(targets, in: app)
            targets = []
            if app.entryPage.exists {
                app.leaveEntryPage()
                let row = "editor.entry.\(section.name)"
                app.scrollForm(until: app.buttons[row], named: row, forward: false)
                targets.append((row, app.buttons[row]))
            }
            targets.append(("editor.add.\(section.name)", app.buttons["editor.add.\(section.name)"]))
            checkTall(targets, in: app)
        }
    }

    /// Scrolls to each target in turn and checks that it is at least as tall as the smallest tap target.
    @MainActor
    private func checkTall(_ targets: [(String, XCUIElement)], in app: XCUIApplication) {
        for (name, target) in targets {
            app.scrollForm(until: target, named: name)
            // A frame comes as a float: 44 points read 43.99…
            XCTAssertGreaterThan(target.frame.height, 43.99, "\(name) is tall enough to tap")
        }
    }
}
