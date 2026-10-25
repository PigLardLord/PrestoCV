import XCTest

/// A row of the editor is deleted in one deliberate way: a swipe opens the row, the button that names it is tapped, and
/// a row with content is asked about by kind ("Delete this certification?"). A tap on the row itself deletes nothing,
/// and there is no trash button beside the fields to be hit by mistake.
///
/// Two of these tests are guards, not tests that fail on the code before the swipe: a tap beside the stars and a tap
/// beside the language picker ask nothing there either. They pin that no control a tap can reach asks to delete a row.
/// The tests of a swipe that starts on a control, and of the rows around a deleted one, pin what the swipe must keep
/// true as rows come and go.
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

    /// The fields that name the rows of the kind, in the order of the screen.
    private func fields(of kind: Kind) -> XCUIElementQuery {
        app.textFields.matching(identifier: kind.field)
    }

    /// What the fields of the rows of the kind hold, in the order of the screen.
    private func names(of kind: Kind) -> [String] {
        let fields = fields(of: kind)
        return (0..<fields.count).map { fields.element(boundBy: $0).value as? String ?? "" }
    }

    /// Whether the fields of the kind come to hold exactly `names`, within `timeout`.
    private func waitForNames(of kind: Kind, toBe names: [String], timeout: TimeInterval = 10) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while self.names(of: kind) != names && Date() < deadline {
            _ = XCTWaiter().wait(for: [XCTestExpectation()], timeout: 0.3)
        }
        return self.names(of: kind) == names
    }

    /// Adds a row of the kind after the ones there, types `text` into its first field (nothing for a blank row) and
    /// ends the entry.
    private func addRow(_ kind: Kind, typing text: String?) {
        app.buttons[kind.tab].firstMatch.tap()
        let add = app.buttons[kind.add]
        app.scrollTo(add)
        let before = fields(of: kind).count
        add.tap()

        // The new row is the last one, and it takes the focus
        let fields = fields(of: kind)
        XCTAssertTrue(
            waitForCount(of: fields, toBe: before + 1),
            "A new row should have a \(kind.field) to type into, after the \(before) there")
        let field = fields.element(boundBy: before)
        XCTAssertTrue(
            field.waitForKeyboardFocus(true),
            "The first field of a new row should take the focus. " + XCUIApplication.noSoftwareKeyboard)
        app.typeText((text ?? "") + "\n")
        XCTAssertTrue(field.waitForKeyboardFocus(false), "Return should end the entry")
        app.scrollTo(field)
    }

    private func waitForCount(of query: XCUIElementQuery, toBe count: Int, timeout: TimeInterval = 10) -> Bool {
        let condition = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count == %d", count), object: query)
        return XCTWaiter().wait(for: [condition], timeout: timeout) == .completed
    }

    /// The row of the kind, as the list of the editor holds it.
    private func row(of kind: Kind) -> XCUIElement {
        app.cells.containing(.textField, identifier: kind.field).firstMatch
    }

    /// The row whose field holds `name`, whichever rows are around it.
    private func row(holding name: String) -> XCUIElement {
        app.cells.containing(NSPredicate(format: "value == %@", name)).firstMatch
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
        XCTAssertEqual(names(of: kind), [], "No row of the kind should be left, and none that holds what the removed row held")
        XCTAssertEqual(
            app.textFields.matching(NSPredicate(format: "value == %@", kind.name)).count, 0,
            "What was typed in the removed row should not be on the screen any more")
        XCTAssertTrue(app.buttons[kind.add].exists, "The section should stay, to add a row again")
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

    /// A guard, not a test that fails on the code before the swipe: a tap beside the stars of a skill asks nothing there
    /// either. It is here so that a delete control put back into the row, which a tap beside the stars could reach,
    /// is caught.
    func testATapBesideTheStarsDeletesNothing() throws {
        let kind = Self.skill
        addRow(kind, typing: kind.name)

        tapBesideTheControls(of: row(of: kind), question: kind.question)

        XCTAssertEqual(app.textFields[kind.field].value as? String, kind.name, "The skill should still be there")
    }

    /// The same guard, next to the level of a language.
    func testATapBesideTheLanguagePickerDeletesNothing() throws {
        let kind = Self.language
        addRow(kind, typing: kind.name)

        tapBesideTheControls(of: row(of: kind), question: kind.question)

        XCTAssertEqual(app.textFields[kind.field].value as? String, kind.name, "The language should still be there")
    }

    // MARK: - A swipe that starts on a control

    /// Swipes from the right part of `control` towards the left, along its line, 160 points or as far as the row allows.
    /// The distance is from the start, not to a place in the row: on an iPad a control sits in the left part of a wide
    /// row, and a "swipe" to a place right of its start is a tap.
    private func swipe(from control: XCUIElement, in row: XCUIElement) {
        let startX = control.frame.minX + control.frame.width * 0.9
        let endX = max(row.frame.minX + 24, startX - 160)
        let y = control.frame.midY - row.frame.minY
        let origin = row.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: startX - row.frame.minX, dy: y))
        let end = origin.withOffset(CGVector(dx: endX - row.frame.minX, dy: y))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    /// What a control says and holds, for telling that a swipe did not press it.
    private func state(of control: XCUIElement) -> String {
        "\(control.label)|\(control.value as? String ?? "")"
    }

    /// A swipe is for the row: started on a control of the row, it opens the row, and neither presses the control nor
    /// deletes the row.
    private func checkASwipeFromAControlOpensTheRowAndChangesNothing(_ kind: Kind, control: (XCUIElement) -> XCUIElement) {
        addRow(kind, typing: kind.name)
        let row = row(of: kind)
        let control = control(row)
        XCTAssertTrue(control.waitForExistence(timeout: 10), "The row should have the control to swipe from")
        let before = state(of: control)

        swipe(from: control, in: row)

        XCTAssertTrue(
            app.buttons["Delete \(kind.name)"].waitForExistence(timeout: 10),
            "A swipe that starts on the control should open the row, as one that starts beside it does")
        XCTAssertFalse(text(kind.question).exists, "A swipe alone should not ask to delete the row")
        XCTAssertEqual(names(of: kind), [kind.name], "The row should still be there")
        XCTAssertEqual(state(of: control), before, "A swipe should not press the control it starts on")
    }

    func testASwipeFromTheStarsOpensTheRowAndChangesNothing() throws {
        checkASwipeFromAControlOpensTheRowAndChangesNothing(Self.skill) { row in
            row.descendants(matching: .any).matching(NSPredicate(format: "label == 'Skill level selector'")).firstMatch
        }
    }

    func testASwipeFromTheLanguagePickerOpensTheRowAndChangesNothing() throws {
        checkASwipeFromAControlOpensTheRowAndChangesNothing(Self.language) { row in
            row.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Level'")).firstMatch
        }
    }

    func testASwipeFromTheDescriptionOpensTheRowAndChangesNothing() throws {
        checkASwipeFromAControlOpensTheRowAndChangesNothing(Self.certification) { row in row.textViews.firstMatch }
    }

    // MARK: - The rows around a deleted one

    func testDeletingARowKeepsItsNeighboursAndTheNextRowComesUpClosed() throws {
        let kind = Self.skill
        for name in ["Swift", "Kotlin", "Rust"] {
            addRow(kind, typing: name)
        }
        XCTAssertEqual(names(of: kind), ["Swift", "Kotlin", "Rust"])

        tapDelete(named: "Delete Kotlin", on: row(holding: "Kotlin"))
        XCTAssertTrue(text(kind.question).waitForExistence(timeout: 10), "The question should come: \(kind.question)")
        app.buttons["Delete"].tap()

        XCTAssertTrue(waitForNames(of: kind, toBe: ["Swift", "Rust"]), "Only the row asked about should go: \(names(of: kind))")
        // Rust now sits where Kotlin sat: it is a row of its own, not the open row of Kotlin, and it holds no focus
        XCTAssertFalse(app.buttons["Delete Rust"].exists, "The row that took the place should not be left swiped open")
        XCTAssertFalse(app.buttons["Delete Kotlin"].exists)
        XCTAssertFalse(text(kind.question).exists, "Nothing more should be asked")
        let rust = fields(of: kind).element(boundBy: 1)
        XCTAssertEqual(rust.value as? String, "Rust")
        XCTAssertTrue(rust.waitForKeyboardFocus(false, timeout: 5), "The row that took the place should not take the focus")

        // Its button names it, and a Cancel keeps it
        tapDelete(named: "Delete Rust", on: row(holding: "Rust"))
        XCTAssertTrue(text(kind.question).waitForExistence(timeout: 10), "The question should come for Rust")
        cancelTheQuestion()
        XCTAssertTrue(text(kind.question).waitForNonExistence(timeout: 10), "Cancel should close the question")
        XCTAssertEqual(names(of: kind), ["Swift", "Rust"], "Cancel should keep the rows")
    }

    func testCancellingKeepsEveryRowOfSeveral() throws {
        let kind = Self.skill
        for name in ["Swift", "Kotlin"] {
            addRow(kind, typing: name)
        }

        tapDelete(named: "Delete Swift", on: row(holding: "Swift"))
        XCTAssertTrue(text(kind.question).waitForExistence(timeout: 10))
        cancelTheQuestion()

        XCTAssertTrue(text(kind.question).waitForNonExistence(timeout: 10))
        XCTAssertEqual(names(of: kind), ["Swift", "Kotlin"])
    }

    func testAddingARowWhileAnotherIsSwipedOpenKeepsBothAndFocusesTheNewOne() throws {
        let kind = Self.skill
        addRow(kind, typing: "Swift")
        swipeOpen(row(holding: "Swift"))
        XCTAssertTrue(app.buttons["Delete Swift"].waitForExistence(timeout: 10), "The swipe should open the row")

        let add = app.buttons[kind.add]
        app.scrollTo(add)
        add.tap()
        // A tap beside an open row may only close it; the row is added by the next tap
        if !waitForCount(of: fields(of: kind), toBe: 2, timeout: 3) {
            add.tap()
        }

        XCTAssertTrue(waitForCount(of: fields(of: kind), toBe: 2), "The new row should be added")
        let new = fields(of: kind).element(boundBy: 1)
        XCTAssertTrue(new.waitForKeyboardFocus(true), "The new row should take the focus. " + XCUIApplication.noSoftwareKeyboard)
        app.typeText("Kotlin")
        XCTAssertEqual(names(of: kind), ["Swift", "Kotlin"], "What is typed should go to the new row, and the open row stays as it was")
        XCTAssertFalse(text(kind.question).exists, "Adding a row should not ask to delete one")
    }
}
