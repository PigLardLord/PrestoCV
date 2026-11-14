import Testing
import Foundation

// MARK: - Runtime issues in the UI tests of the new stack

/// Every UI test of the new stack fails on a runtime issue of the app (#478). XCTest records a runtime issue, such as SwiftUI's
/// "Invalid frame dimension (negative or non-finite).", without failing the test; `RuntimeIssueFailingTestCase` records it as a
/// failure. So every class of the target names that base in its inheritance clause, the base's own declaration aside: a class
/// that inherits `XCTestCase` itself, or through another name (a type alias, a class in between), would skip it. A helper of
/// the tests that is not a test case is a struct, an enum or an actor.
///
/// The check reads the code of the files without their comments and the text of their strings (`SwiftCode.skeleton`).
@Suite("UI tests of the new stack - a runtime issue fails the test")
struct UITestRuntimeIssueTests {

    // MARK: - The rule

    private static let folder = "PrestoCVNextUITests/"

    /// The base that fails a test on a runtime issue, and the file that declares it.
    private static let baseClass = "RuntimeIssueFailingTestCase"
    private static let baseClassFile = "PrestoCVNextUITests/RuntimeIssueFailingTestCase.swift"

    /// What may follow `class` without declaring a class: a member of one (`class func`, `override class var`)
    private static let member = #"(?!(?:func|var|let|subscript|override|final|static|private|fileprivate|internal|public|open|nonisolated|convenience|required)\b)"#

    /// A class declaration: its name, its generic parameters, and its inheritance clause up to its brace, over several lines
    /// if need be.
    private static let classDeclaration = try! NSRegularExpression(
        pattern: #"\bclass\s+"# + member + #"\w+\s*(?:<[^>{]*>)?\s*(?::[^{]*)?\{"#
    )

    /// A class declaration whose inheritance clause, if it has one, does not name the base.
    private static let classWithoutTheBase = try! NSRegularExpression(
        pattern: #"\bclass\s+"# + member + #"\w+\s*(?:<[^>{]*>)?\s*(?::(?:(?!\b"# + baseClass + #"\b)[^{])*)?\{"#
    )

    /// The lines of `source` that declare a class that does not inherit the base, counted from 1
    static func problems(in source: String) -> [Int] {
        SwiftCode(source).skeletonLines(matching: classWithoutTheBase).map { $0 + 1 }
    }

    /// The lines of `source` that declare a class, counted from 1
    static func classes(in source: String) -> [Int] {
        SwiftCode(source).skeletonLines(matching: classDeclaration).map { $0 + 1 }
    }

    private static func swiftFiles() throws -> [String] {
        try Repository.presentFiles().filter { $0.hasPrefix(folder) && $0.hasSuffix(".swift") }
    }

    // MARK: - Tests

    @Test("the check reads the UI tests of the new stack and finds their classes, so that a wrong folder or pattern does not pass it")
    func checkReadsTheUITests() throws {
        let files = try Self.swiftFiles()
        let classes = try files.reduce(0) { $0 + Self.classes(in: try Repository.text($1)).count }

        #expect(files.count >= 10, "Only \(files.count) Swift files under \(Self.folder)")
        #expect(files.contains(Self.baseClassFile))
        #expect(files.contains("PrestoCVNextUITests/EditorDetailsUITests.swift"))
        #expect(classes >= 10, "Only \(classes) classes under \(Self.folder)")
    }

    @Test("the base class is declared where the rule says, without inheriting itself")
    func baseClassIsThere() throws {
        let source = try Repository.text(Self.baseClassFile)
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false)
        let declared = Self.problems(in: source).map { String(lines[$0 - 1]) }

        #expect(declared.count == 1 && declared.allSatisfy { $0.contains("class \(Self.baseClass):") }, "\(declared)")
    }

    @Test("every class of the UI tests of the new stack inherits the class that fails a test on a runtime issue")
    func everyTestClassFailsOnARuntimeIssue() throws {
        var found: [String] = []
        for path in try Self.swiftFiles() where path != Self.baseClassFile {
            found += Self.problems(in: try Repository.text(path)).map { "\(path):\($0)" }
        }

        #expect(found.isEmpty, "Inherit RuntimeIssueFailingTestCase, or make a helper a struct, an enum or an actor: \(found)")
    }

    // MARK: - The check itself

    @Test("the check finds a class that does not name the base, however its declaration is written", arguments: [
        "final class ShellUITests: XCTestCase {",
        "class ShellUITests : XCTestCase {",
        "final class ShellUITests: XCTest.XCTestCase {",
        "@MainActor final class ShellUITests: XCTestCase, Sendable {",
        "final class ShellUITests: BaseUITests {",
        "final class ShellUITests<Screen>: XCTestCase where Screen: Sendable {",
        "final class ShellUITests:\n    XCTestCase\n{",
        "final class Helper {",
        "final class ShellUITests: RuntimeIssueFailingTestCaseOld {",
    ])
    func findsAClassWithoutTheBase(source: String) {
        #expect(Self.problems(in: source) == [1], "\(source)")
        #expect(Self.classes(in: source) == [1], "\(source)")
    }

    @Test("the check does not mind a class that inherits the base, a member of a class, a comment, a string or another type")
    func ignoresWhatIsNotAClassWithoutTheBase() {
        let source = """
        final class ShellUITests: RuntimeIssueFailingTestCase {}
        @MainActor final class EditorUITests: RuntimeIssueFailingTestCase, @unchecked Sendable {}
        final class PagedUITests<Page>: RuntimeIssueFailingTestCase where Page: Sendable {}
        final class SplitUITests:
            RuntimeIssueFailingTestCase
        {
            override class func setUp() {}
            class var screens: Int { 1 }
            override class var defaultTestSuite: XCTestSuite { super.defaultTestSuite }
        }
        // final class OldUITests: XCTestCase {}
        let note = "final class OldUITests: XCTestCase {"
        struct Screen {}
        let type: XCTestCase.Type = ShellUITests.self
        """

        #expect(Self.problems(in: source).isEmpty, "\(Self.problems(in: source))")
        #expect(Self.classes(in: source) == [1, 2, 3, 4], "\(Self.classes(in: source))")
    }
}
