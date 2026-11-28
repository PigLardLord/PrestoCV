import XCTest

/// The order of a section's rows: a row moves up or down from its context menu, which stands in for its VoiceOver
/// actions (XCUITest has no call for a custom action), or by a drag of its handle once the person taps Edit. A move the
/// row cannot make is not offered, and Edit is off until a section has two rows.
final class EditorReorderUITests: RuntimeIssueFailingTestCase {

    private let identity = "5B0C2F7E-91D4-4C6A-8E3B-2A7D9F1C4E60"
    private let title = "Site Foreman"
    private let skills = ["Sketching", "Prototyping", "Research"]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: Launching

    /// A store folder of its own with one CV whose sections are empty, in English, opened.
    @MainActor
    private func launchAndOpen() throws -> XCUIApplication {
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
        app.launch()
        let row = app.descendants(matching: .any).matching(identifier: "shell.row")
            .matching(NSPredicate(format: "label BEGINSWITH %@", title + ", ")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 30), "The list shows \(title)")
        row.tap()
        XCTAssertTrue(app.textFields["editor.field.title"].waitForExistence(timeout: 30), "The form of \(title) opens")
        return app
    }

    /// The CV opened, with the three skills added.
    @MainActor
    private func launchWithSkills() throws -> XCUIApplication {
        let app = try launchAndOpen()
        for skill in skills {
            addSkill(skill, in: app)
        }
        XCTAssertTrue(waitForOrder(skills, in: app), "A new skill goes last: \(order(in: app))")
        return app
    }

    /// Adds a skill, types its name, and puts the keyboard away.
    @MainActor
    private func addSkill(_ name: String, in app: XCUIApplication) {
        let add = app.buttons["editor.add.skills"]
        scrollUntilHittable(add, in: app)
        add.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 30), "A new skill takes the keyboard")
        app.typeText(name)
        app.buttons["keyboard.done"].tap()
        XCTAssertTrue(waitUntilGone(app.keyboards.firstMatch), "Done puts the keyboard away")
    }

    // MARK: Edit

    /// Edit is off while no section has two rows: with no skill and with one. A second skill turns it on.
    @MainActor
    func testEditNeedsTwoRows() throws {
        let app = try launchAndOpen()
        let edit = app.buttons["editor.edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 30), "The bar has Edit")
        XCTAssertFalse(edit.isEnabled, "No row: nothing to move")

        addSkill(skills[0], in: app)
        XCTAssertFalse(edit.isEnabled, "One row cannot move")

        addSkill(skills[1], in: app)
        let on = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: edit)
        XCTAssertEqual(XCTWaiter().wait(for: [on], timeout: 30), .completed, "Two rows can move")
    }

    // MARK: Moving

    /// The last skill offers Move up and no Move down, and moves one place up.
    @MainActor
    func testMoveByAccessibilityAction() throws {
        let app = try launchWithSkills()
        let research = field("Research", in: app)

        // The long press lands on the label above the field, away from its text
        research.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: -0.3)).press(forDuration: 1.2)
        let up = app.buttons["Move Research Up"]
        XCTAssertTrue(up.waitForExistence(timeout: 30), "The menu names the row")
        XCTAssertFalse(app.buttons["Move Research Down"].exists, "The last row cannot move down")
        up.tap()

        let moved = ["Sketching", "Research", "Prototyping"]
        XCTAssertTrue(waitForOrder(moved, in: app), "Research moves one place up: \(order(in: app))")
    }

    /// Once the person taps Edit, a drag of the last skill's handle onto the first one's puts it first. The skills are
    /// brought clear of the form's edges first: the last one added stays in view above the keyboard, which leaves the
    /// first above the screen, and a drag that ends near an edge scrolls the form instead of moving the row.
    @MainActor
    func testDragReorders() throws {
        let app = try launchWithSkills()
        bringClearOfTheEdges(from: field("Sketching", in: app), to: field("Research", in: app), in: app)
        let edit = app.buttons["editor.edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 30), "The bar has Edit")
        edit.tap()

        let handles = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Reorder"))
        XCTAssertTrue(handles.firstMatch.waitForExistence(timeout: 30), "Edit shows the handles of the rows")
        let first = try handle(of: "Sketching", among: handles, in: app)
        let last = try handle(of: "Research", among: handles, in: app)
        last.press(forDuration: 1, thenDragTo: first, withVelocity: .slow, thenHoldForDuration: 0.5)

        let moved = ["Research", "Sketching", "Prototyping"]
        XCTAssertTrue(waitForOrder(moved, in: app), "Research moves first: \(order(in: app))")
        edit.tap()
    }

    // MARK: Reading the order

    @MainActor
    private func field(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.textFields.matching(identifier: "editor.field.skillName")
            .matching(NSPredicate(format: "value == %@", name)).firstMatch
    }

    /// The names of the skills on screen, from the top.
    @MainActor
    private func order(in app: XCUIApplication) -> [String] {
        app.textFields.matching(identifier: "editor.field.skillName").allElementsBoundByIndex
            .sorted { $0.frame.minY < $1.frame.minY }
            .map { $0.value as? String ?? "" }
    }

    /// The handle on the row of the skill: the one whose middle is nearest the middle of its field.
    @MainActor
    private func handle(of name: String, among handles: XCUIElementQuery,
                        in app: XCUIApplication) throws -> XCUIElement {
        let middle = field(name, in: app).frame.midY
        let onScreen = handles.allElementsBoundByIndex.filter(\.isHittable)
        return try XCTUnwrap(onScreen.min { abs($0.frame.midY - middle) < abs($1.frame.midY - middle) },
                             "The row of \(name) has a handle")
    }

    @MainActor
    private func waitForOrder(_ names: [String], in app: XCUIApplication) -> Bool {
        let holds = NSPredicate { _, _ in self.order(in: app) == names }
        return XCTWaiter().wait(for: [expectation(for: holds, evaluatedWith: app)], timeout: 30) == .completed
    }

    // MARK: Waiting and moving

    @MainActor
    private func waitUntilGone(_ element: XCUIElement) -> Bool {
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element)
        return XCTWaiter().wait(for: [gone], timeout: 30) == .completed
    }

    /// Scrolls the form up in steps shorter than the screen until the element can be tapped. A form shows only the rows
    /// on screen. The drag stays in the form, away from the list beside it.
    @MainActor
    private func scrollUntilHittable(_ element: XCUIElement, in app: XCUIApplication) {
        let form = app.descendants(matching: .any).matching(identifier: "shell.detail.opened").firstMatch
        let from = form.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
        let to = form.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
        for _ in 0..<15 where !(element.exists && element.isHittable) {
            // Held at the end, so the form does not glide on
            from.press(forDuration: 0.05, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        XCTAssertTrue(element.exists && element.isHittable, "The add button of the skills comes into view")
    }

    /// Scrolls the form in short steps until the rows from `top` to `bottom` stand clear of the bar and of the form's
    /// bottom edge, back while `top` is above the room and on while `bottom` is below it.
    @MainActor
    private func bringClearOfTheEdges(from top: XCUIElement, to bottom: XCUIElement, in app: XCUIApplication) {
        let form = app.descendants(matching: .any).matching(identifier: "shell.detail.opened").firstMatch
        let margin: CGFloat = 88
        let upper = app.navigationBars.firstMatch.frame.maxY + margin
        let lower = form.frame.maxY - margin
        let higher = form.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
        let deeper = form.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
        let topIsClear = { top.exists && top.isHittable && top.frame.minY > upper }
        let bottomIsClear = { bottom.exists && bottom.isHittable && bottom.frame.maxY < lower }
        for _ in 0..<20 where !(topIsClear() && bottomIsClear()) {
            // Back moves the rows down, on moves them up; held at the end, so the form does not glide on
            let (from, to) = topIsClear() ? (deeper, higher) : (higher, deeper)
            from.press(forDuration: 0.05, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        XCTAssertTrue(topIsClear() && bottomIsClear(), "The skills stand clear of the form's edges")
    }
}
