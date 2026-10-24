import XCTest

/// A row of the editor is deleted in one deliberate way: a swipe opens the row, the button that names it is tapped, and
/// a row with content is asked about by kind ("Delete this certification?"). A tap on the row itself deletes nothing,
/// and there is no trash button beside the fields to be hit by mistake.
final class EditorRowDeletionUITests: XCTestCase {

    /// One kind of row of the editor, as the person sees it.
    private struct Kind {
        /// The tab of the editor that holds the rows.
        let tab: String
        let add: String
        /// The field that names the row, by its placeholder.
        let field: String
        /// What is typed into that field.
        let name: String
        /// The question that is asked before a row with content goes.
        let question: String
        /// What the delete button of the blank row says.
        let blankLabel: String
    }

    private static let experience = Kind(
        tab: "Experience", add: "Add Experience", field: "Job Title", name: "Ward Nurse",
        question: "Delete this experience?", blankLabel: "Delete Job Title")
    private static let skill = Kind(
        tab: "Experience", add: "Add Skill", field: "Skill", name: "Swift",
        question: "Delete this skill?", blankLabel: "Delete Skill")
    private static let education = Kind(
        tab: "Experience", add: "Add Education", field: "Degree", name: "BSc Nursing",
        question: "Delete this education entry?", blankLabel: "Delete Degree")
    private static let language = Kind(
        tab: "Details", add: "Add Language", field: "Language", name: "Italian",
        question: "Delete this language?", blankLabel: "Delete Language")
    private static let certification = Kind(
        tab: "Details", add: "Add Certification", field: "Certification Name", name: "AWS Architect",
        question: "Delete this certification?", blankLabel: "Delete Certification Name")
    private static let socialLink = Kind(
        tab: "Details", add: "Add Social Link", field: "Platform", name: "LinkedIn",
        question: "Delete this social link?", blankLabel: "Delete Platform")
    private static let interest = Kind(
        tab: "Details", add: "Add Interest", field: "Interest", name: "Chess",
        question: "Delete this interest?", blankLabel: "Delete Interest")

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 300
        app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVUITestsEmptyStorage"]
        app.launch()
        let start = app.buttons["Create My First CV"]
        XCTAssertTrue(start.waitForExistence(timeout: 20), "The first-run screen should offer to create a CV")
        start.tap()
    }

    // MARK: - Helpers

    /// Adds a row of the kind, types `text` into its first field (nothing for a blank row) and ends the entry.
    private func addRow(_ kind: Kind, typing text: String?) {
        app.buttons[kind.tab].firstMatch.tap()
        let add = app.buttons[kind.add]
        app.scrollTo(add)
        add.tap()

        let field = app.textFields[kind.field]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "A new row should have a \(kind.field) to type into")
        XCTAssertTrue(
            field.waitForKeyboardFocus(true),
            "The first field of a new row should take the focus. " + XCUIApplication.noSoftwareKeyboard)
        app.typeText((text ?? "") + "\n")
        XCTAssertTrue(field.waitForKeyboardFocus(false), "Return should end the entry")
        app.scrollTo(field)
    }

    /// The row of the kind, as the list of the editor holds it.
    private func row(of kind: Kind) -> XCUIElement {
        app.cells.containing(.textField, identifier: kind.field).firstMatch
    }

    /// Swipes the row open from its upper part, clear of the fields' text.
    private func swipeOpen(_ row: XCUIElement) {
        let start = row.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.12))
        let end = row.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.12))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    /// Opens the row and taps the delete button that the swipe reveals, which has to name the row.
    private func tapDelete(named label: String, on row: XCUIElement) {
        swipeOpen(row)
        let delete = app.buttons[label]
        XCTAssertTrue(delete.waitForExistence(timeout: 10), "A swipe should reveal a delete button that says \"\(label)\"")
        delete.tap()
    }

    /// A text of the screen, whatever it is made of: the confirmation of the iPhone and the popover of the iPad differ.
    private func text(_ label: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    /// Answers the question with Cancel. The question is a popover beside the row, which has no Cancel button: a tap
    /// outside it, low on the screen, closes it and keeps the row.
    private func cancelTheQuestion() {
        let cancel = app.buttons["Cancel"]
        if cancel.waitForExistence(timeout: 1) {
            cancel.tap()
            return
        }
        let outside = app.otherElements["PopoverDismissRegion"]
        XCTAssertTrue(outside.waitForExistence(timeout: 5), "The question should close with a tap outside it\n\(app.debugDescription)")
        outside.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)).tap()
    }

    /// The delete buttons that sit in the rows, whatever they are called: a swipe has not opened any of them.
    private var inlineDeleteButtons: XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Delete' OR identifier == 'trash'"))
    }

    // MARK: - A row with content

    private func checkARowWithContentIsDeletedAfterTheQuestion(_ kind: Kind) {
        addRow(kind, typing: kind.name)
        let field = app.textFields[kind.field]
        let row = row(of: kind)
        XCTAssertTrue(row.exists, "The new row should be a row of the list")

        XCTAssertEqual(inlineDeleteButtons.count, 0, "A row with a swipe should not have a trash button as well")

        // Cancel keeps the row
        tapDelete(named: "Delete \(kind.name)", on: row)
        XCTAssertTrue(text(kind.question).waitForExistence(timeout: 10), "The question should name the kind of row: \(kind.question)")
        cancelTheQuestion()
        XCTAssertTrue(text(kind.question).waitForNonExistence(timeout: 10), "Cancel should close the question")
        XCTAssertTrue(field.exists, "Cancel should keep the row")
        XCTAssertEqual(field.value as? String, kind.name, "Cancel should keep what is in the row")

        // Delete removes it
        tapDelete(named: "Delete \(kind.name)", on: row)
        XCTAssertTrue(text(kind.question).waitForExistence(timeout: 10), "The question should come again: \(kind.question)")
        app.buttons["Delete"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 10), "Delete should remove the row")
    }

    func testAnExperienceIsDeletedAfterTheQuestion() throws {
        checkARowWithContentIsDeletedAfterTheQuestion(Self.experience)
    }

    func testASkillIsDeletedAfterTheQuestion() throws {
        checkARowWithContentIsDeletedAfterTheQuestion(Self.skill)
    }

    func testAnEducationIsDeletedAfterTheQuestion() throws {
        checkARowWithContentIsDeletedAfterTheQuestion(Self.education)
    }

    func testALanguageIsDeletedAfterTheQuestion() throws {
        checkARowWithContentIsDeletedAfterTheQuestion(Self.language)
    }

    func testACertificationIsDeletedAfterTheQuestion() throws {
        checkARowWithContentIsDeletedAfterTheQuestion(Self.certification)
    }

    func testASocialLinkIsDeletedAfterTheQuestion() throws {
        checkARowWithContentIsDeletedAfterTheQuestion(Self.socialLink)
    }

    func testAnInterestIsDeletedAfterTheQuestion() throws {
        checkARowWithContentIsDeletedAfterTheQuestion(Self.interest)
    }

    // MARK: - A blank row

    private func checkABlankRowIsDeletedAtOnce(_ kind: Kind) {
        addRow(kind, typing: nil)
        let field = app.textFields[kind.field]
        XCTAssertTrue(field.exists, "The new row should be there")

        tapDelete(named: kind.blankLabel, on: row(of: kind))

        XCTAssertTrue(field.waitForNonExistence(timeout: 10), "A row with nothing in it should go without a question")
        XCTAssertFalse(text(kind.question).exists, "A row with nothing in it loses nothing, so nothing is asked")
    }

    func testABlankSkillIsDeletedAtOnce() throws {
        checkABlankRowIsDeletedAtOnce(Self.skill)
    }

    func testABlankCertificationIsDeletedAtOnce() throws {
        checkABlankRowIsDeletedAtOnce(Self.certification)
    }

    // MARK: - A tap beside the controls

    /// Taps the places of the row that are not a control: the margins and the line of the stars or the picker.
    private func tapBesideTheControls(of row: XCUIElement, question: String) {
        for (dx, dy) in [(0.97, 0.85), (0.6, 0.85), (0.03, 0.85), (0.97, 0.15)] {
            row.coordinate(withNormalizedOffset: CGVector(dx: dx, dy: dy)).tap()
            XCTAssertFalse(
                text(question).waitForExistence(timeout: 1.5),
                "A tap at \(dx), \(dy) of the row should not ask to delete it")
        }
    }

    /// A tap next to the stars of a skill used to be a tap on the delete button of the whole row.
    func testATapBesideTheStarsDeletesNothing() throws {
        let kind = Self.skill
        addRow(kind, typing: kind.name)

        tapBesideTheControls(of: row(of: kind), question: kind.question)

        XCTAssertEqual(app.textFields[kind.field].value as? String, kind.name, "The skill should still be there")
    }

    /// The same, next to the level of a language.
    func testATapBesideTheLanguagePickerDeletesNothing() throws {
        let kind = Self.language
        addRow(kind, typing: kind.name)

        tapBesideTheControls(of: row(of: kind), question: kind.question)

        XCTAssertEqual(app.textFields[kind.field].value as? String, kind.name, "The language should still be there")
    }
}
