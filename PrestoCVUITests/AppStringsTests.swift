import XCTest

/// `AppStrings` hands the screenshot test the app's own texts. A key the tool did not hand over must stop the test and
/// name the key: handed back as itself, it would be searched for as a label that does not exist, or, in a check that a
/// label does not mention a text, pass for the wrong reason. These tests do not launch the app.
final class AppStringsTests: XCTestCase {

    private func handedOver(_ texts: [String: String]) throws -> [String: String] {
        [AppStrings.environmentKey: try JSONEncoder().encode(texts).base64EncodedString()]
    }

    func testATextThatWasHandedOverIsReturned() throws {
        let strings = try AppStrings(environment: handedOver(["export.share": "Share"]))

        XCTAssertEqual(try strings.text("export.share"), "Share")
    }

    func testAKeyThatWasNotHandedOverIsAnErrorThatNamesIt() throws {
        let strings = try AppStrings(environment: handedOver(["export.share": "Share"]))

        XCTAssertThrowsError(try strings.text("export.shre")) { error in
            XCTAssertTrue("\(error)".contains("export.shre"), "The error should name the key: \(error)")
        }
    }

    func testPlaceholdersAreFilledIn() throws {
        let strings = try AppStrings(environment: handedOver(["accessibility.navigate_to": "Open %@"]))

        XCTAssertEqual(try strings.format("accessibility.navigate_to", with: ["Project Manager"]), "Open Project Manager")
    }

    func testFormattingAKeyThatWasNotHandedOverIsAnErrorThatNamesIt() throws {
        let strings = try AppStrings(environment: handedOver([:]))

        XCTAssertThrowsError(try strings.format("accessibility.navigate_to", with: ["Project Manager"])) { error in
            XCTAssertTrue("\(error)".contains("accessibility.navigate_to"), "The error should name the key: \(error)")
        }
    }

    func testWithoutTheTextsTheToolIsNamed() {
        XCTAssertThrowsError(try AppStrings(environment: [:])) { error in
            XCTAssertTrue("\(error)".contains("store-screenshots.sh"), "The error should name the tool that hands the texts over: \(error)")
        }
    }
}
