import XCTest

/// What every screen's test does to start the app and to find its parts, once.
extension XCUIApplication {

    /// The stored file of a CV with these sections empty, as the fixture's seed holds it: the JSON of the CV.
    /// `sections` adds the arrays and fields of the sections the test needs, as JSON members without a leading comma,
    /// for example `"skills":[...]`; a section left out is empty.
    static func storedCV(
        identity: String, title: String, person: String = "Dario Venn", sections: [String: String] = [:],
        updated: String = "2026-01-02T00:00:00Z"
    ) -> String {
        let names = ["experiences", "education", "skills", "languages", "certifications", "profiles", "interests"]
        let lists = names.map { "\"\($0)\":\(sections[$0] ?? "[]")" }.joined(separator: ",")
        let personal = sections["personal"]
            ?? "{\"fullName\":\"\(person)\",\"professionalTitle\":\"\",\"location\":\"\",\"summary\":\"\"}"
        return """
            {"schemaVersion":1,"id":"\(identity)","revision":1,"createdAt":"2026-01-01T00:00:00Z",\
            "updatedAt":"\(updated)","title":"\(title)","personal":\(personal),\(lists)}
            """
    }

    /// The seed argument of the launch fixture: the stored files by name, as base 64 of a JSON object.
    static func seed(_ files: [String: String]) throws -> String {
        try JSONEncoder().encode(files).base64EncodedString()
    }

    /// An app that starts in English on a store folder of its own, seeded with `cvs` (each file named by its identity),
    /// with `arguments` after them. The caller launches it.
    static func seeded(
        _ cvs: [(identity: String, json: String)], largestText: Bool = false, arguments: [String] = []
    ) throws -> XCUIApplication {
        let app = XCUIApplication()
        var files: [String: String] = [:]
        for cv in cvs { files["\(cv.identity).cv.json"] = cv.json }
        app.launchArguments += [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVNextEmptyStorage",
            "-PrestoCVNextSeed", try seed(files),
        ]
        if largestText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launchArguments += arguments
        return app
    }

    /// The first element with this identifier, whatever its kind.
    func element(_ identifier: String) -> XCUIElement {
        descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// The text input with this identifier, of either kind: a field of one line wraps at the largest text sizes, and
    /// XCUITest may then show it as a text view.
    func textInput(_ identifier: String) -> XCUIElement {
        let kinds = NSPredicate(
            format: "elementType == %lu OR elementType == %lu",
            XCUIElement.ElementType.textField.rawValue, XCUIElement.ElementType.textView.rawValue)
        return descendants(matching: .any).matching(identifier: identifier).matching(kinds).firstMatch
    }

    /// The row of the CV list titled `title`.
    func listRow(titled title: String) -> XCUIElement {
        descendants(matching: .any).matching(identifier: "shell.row")
            .matching(NSPredicate(format: "label BEGINSWITH %@", title + ", ")).firstMatch
    }

    /// Opens the CV titled `title` from the list and waits for its form.
    @MainActor
    func openCV(titled title: String, file: StaticString = #filePath, line: UInt = #line) {
        let row = listRow(titled: title)
        XCTAssertTrue(row.waitForExistence(timeout: 30), "The list shows \(title)", file: file, line: line)
        row.tap()
        XCTAssertTrue(
            textInput("editor.field.title").waitForExistence(timeout: 30), "The form of \(title) opens", file: file,
            line: line)
    }
}
