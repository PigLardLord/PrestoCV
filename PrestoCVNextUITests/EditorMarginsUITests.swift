import XCTest

/// The cards of an open CV keep the margins of the system and stay clear of what covers the screen's edges. On a wide
/// screen the list beside the form lies over the form's leading edge: the cards start right of it, centred in the space
/// it leaves and no wider than the readable width. On a narrow screen the cards keep a gap from both edges.
final class EditorMarginsUITests: RuntimeIssueFailingTestCase {

    private let identity = "6B1F6C1E-1B8C-4C1B-9D55-1F3B2C8B7A01"
    private let title = "Backend Engineer"

    /// The readable width of the design system (`ReadableWidth.maximum`).
    private let readableWidth: CGFloat = 560

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// The first card, the CV's name and save status, starts right of the list and is centred in the space the list
    /// leaves; on a narrow screen it keeps a gap from both edges of the window.
    @MainActor
    func testTheCardsStayClearOfTheEdges() throws {
        let app = try launch()
        let row = app.descendants(matching: .any).matching(identifier: "shell.row")
            .matching(NSPredicate(format: "label BEGINSWITH %@", title + ", ")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 30), "The list shows \(title)")
        row.tap()
        let card = app.cells.containing(NSPredicate(format: "identifier == %@", "shell.detail.title")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30), "The form of \(title) opens")

        let window = app.windows.firstMatch.frame
        let edges = "card \(card.frame.minX)-\(card.frame.maxX), window \(window.minX)-\(window.maxX)"
        if app.windows.firstMatch.horizontalSizeClass == .regular {
            let list = app.collectionViews.containing(NSPredicate(format: "identifier == %@", "shell.row")).firstMatch
            XCTAssertTrue(list.exists, "The list shows beside the form")
            let leading = card.frame.minX - list.frame.maxX
            let trailing = window.maxX - card.frame.maxX
            let measured = "\(edges), list ends at \(list.frame.maxX)"
            XCTAssertGreaterThanOrEqual(leading, 0, "The card starts right of the list: \(measured)")
            XCTAssertEqual(leading, trailing, accuracy: 1, "The card is centred right of the list: \(measured)")
            XCTAssertLessThanOrEqual(
                card.frame.width, readableWidth + 1, "The card keeps the readable width: \(measured)")
        } else {
            XCTAssertGreaterThan(card.frame.minX, window.minX, "The card keeps a gap from the leading edge: \(edges)")
            XCTAssertLessThan(card.frame.maxX, window.maxX, "The card keeps a gap from the trailing edge: \(edges)")
        }
    }

    /// A store folder of its own with one CV, in English.
    @MainActor
    private func launch() throws -> XCUIApplication {
        // The store reads a CV from the file named by its identity
        let stored = """
        {"schemaVersion":1,"id":"\(identity)","revision":1,
         "createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-02T00:00:00Z","title":"\(title)",
         "personal":{"fullName":"Mara Ellison","professionalTitle":"","location":"","summary":""},
         "experiences":[],"education":[],"skills":[],"languages":[],"certifications":[],"profiles":[],"interests":[]}
        """
        // The fixture takes a JSON map from file name to content, in base 64
        let seed = try JSONEncoder().encode(["\(identity).cv.json": stored]).base64EncodedString()
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVNextEmptyStorage", "-PrestoCVNextReadyDesigns",
            "-PrestoCVNextSeed", seed,
        ]
        app.launch()
        return app
    }
}
