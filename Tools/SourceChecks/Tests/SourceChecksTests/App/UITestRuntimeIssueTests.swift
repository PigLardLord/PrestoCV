import Testing
import Foundation

// MARK: - Runtime issues in the UI tests of the new stack

/// Every UI test of the new stack fails on a runtime issue of the app (#478). XCTest records a runtime issue, such as SwiftUI's
/// "Invalid frame dimension (negative or non-finite).", without failing the test; `RuntimeIssueFailingTestCase` records it as a
/// failure. A test class that inherits `XCTestCase` itself would skip it, so the check reads every class of the target.
///
/// The check reads the code of the files, not their comments (`SwiftCode`).
@Suite("UI tests of the new stack - a runtime issue fails the test")
struct UITestRuntimeIssueTests {

    // MARK: - The rule

    private static let folder = "PrestoCVNextUITests/"

    /// The one class that inherits XCTestCase itself: the base that fails a test on a runtime issue.
    private static let baseClassFile = "PrestoCVNextUITests/RuntimeIssueFailingTestCase.swift"

    /// A class that inherits `XCTestCase` itself, with or without its module in front.
    private static let directTestCase = try! NSRegularExpression(pattern: #"\bclass\s+\w+\s*:\s*(?:XCTest\s*\.\s*)?XCTestCase\b"#)

    /// The lines of `source` that declare a class inheriting `XCTestCase` itself, counted from 1
    static func problems(in source: String) -> [Int] {
        SwiftCode(source).lines(matching: directTestCase).map { $0 + 1 }
    }

    private static func swiftFiles() throws -> [String] {
        try Repository.presentFiles().filter { $0.hasPrefix(folder) && $0.hasSuffix(".swift") }
    }

    // MARK: - Tests

    @Test("the check reads the UI tests of the new stack, so that a wrong folder does not pass it")
    func checkReadsTheUITests() throws {
        let files = try Self.swiftFiles()

        #expect(files.count >= 10, "Only \(files.count) Swift files under \(Self.folder)")
        #expect(files.contains(Self.baseClassFile))
        #expect(files.contains("PrestoCVNextUITests/EditorDetailsUITests.swift"))
    }

    @Test("the base class inherits XCTestCase, so that the rule names a class that is there")
    func baseClassIsThere() throws {
        #expect(Self.problems(in: try Repository.text(Self.baseClassFile)).count == 1)
    }

    @Test("every UI test class of the new stack inherits the class that fails a test on a runtime issue")
    func everyTestClassFailsOnARuntimeIssue() throws {
        var found: [String] = []
        for path in try Self.swiftFiles() where path != Self.baseClassFile {
            found += Self.problems(in: try Repository.text(path)).map { "\(path):\($0)" }
        }

        #expect(found.isEmpty, "Inherit RuntimeIssueFailingTestCase instead of XCTestCase: \(found)")
    }

    // MARK: - The check itself

    @Test("the check finds a class that inherits XCTestCase itself", arguments: [
        "final class ShellUITests: XCTestCase {",
        "class ShellUITests : XCTestCase {",
        "final class ShellUITests: XCTest.XCTestCase {",
        "@MainActor final class ShellUITests: XCTestCase, Sendable {",
    ])
    func findsADirectTestCase(source: String) {
        #expect(Self.problems(in: source) == [1], "\(source)")
    }

    @Test("the check does not mind a class that inherits the base, a comment, or a longer name")
    func ignoresWhatIsNotADirectTestCase() {
        let source = """
        final class ShellUITests: RuntimeIssueFailingTestCase {}
        // final class OldUITests: XCTestCase {}
        final class Helper: XCTestCaseRun {}
        let type: XCTestCase.Type = ShellUITests.self
        """

        #expect(Self.problems(in: source).isEmpty, "\(Self.problems(in: source))")
    }
}
