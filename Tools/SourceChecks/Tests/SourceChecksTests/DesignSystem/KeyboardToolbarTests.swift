import Testing
import Foundation

// MARK: - The bar above the keyboard

/// The new stack draws its own bar above the keyboard and never asks the system for one (#478). A toolbar item placed on the
/// keyboard (`ToolbarItemPlacement.keyboard`) makes SwiftUI log "Invalid frame dimension (negative or non-finite)." as soon as
/// the view that carries it appears, on iOS 26.5 and 27.0, with Apple's own example from the documentation of the placement as
/// well. The warning hides the ones that matter, and nothing in the app needs the system's bar: `KeyboardDoneBar` draws the same
/// button, and `aboveTheKeyboard(shown:content:)` puts it at the bottom of the view while a field has the focus.
///
/// The published app (`PrestoCV/`) keeps its keyboard bar: it gets fixes for published defects only (ADR 0022). The check reads
/// the code of the files, not their comments (`SwiftCode`).
@Suite("Keyboard toolbar - the new stack draws its own bar above the keyboard")
struct KeyboardToolbarTests {

    // MARK: - The rule

    private static let folder = "PrestoCVNext/"

    /// The ways to place a toolbar item on the keyboard: the placement written with its type, and `.keyboard` where a value
    /// goes (after a parenthesis, a comma, a colon, an equals sign, a bracket or a brace, after the `?` of a condition, or
    /// after `return`), so that a placement a condition chooses or a property returns is found as well. The keyboard's
    /// safe-area region (`ignoresSafeArea(.keyboard)`) and a property named keyboard (`input.keyboard`) are not placements.
    private static let keyboardPlacement = [
        #"\bToolbarItemPlacement\s*\.\s*keyboard\b"#,
        #"(?:(?<!ignoresSafeArea)\(|[,:=\[{]|\?\s|\breturn\b)\s*\.\s*keyboard\b"#,
    ].map { try! NSRegularExpression(pattern: $0) }

    /// The lines of `source` that place a toolbar item on the keyboard, counted from 1
    static func problems(in source: String) -> [Int] {
        let code = SwiftCode(source)
        return Set(keyboardPlacement.flatMap { code.lines(matching: $0) }).map { $0 + 1 }.sorted()
    }

    private static func swiftFiles() throws -> [String] {
        try Repository.presentFiles().filter { $0.hasPrefix(folder) && $0.hasSuffix(".swift") }
    }

    // MARK: - Tests

    @Test("the check reads the code of the new stack, so that a wrong folder does not pass it")
    func checkReadsTheNewStack() throws {
        let files = try Self.swiftFiles()

        #expect(files.count >= 40, "Only \(files.count) Swift files under \(Self.folder)")
        #expect(files.contains("PrestoCVNext/DesignSystem/KeyboardDoneBar.swift"))
        #expect(files.contains("PrestoCVNext/Platform/AboveTheKeyboard.swift"))
        #expect(files.contains("PrestoCVNext/Features/Editor/EditorView.swift"))
    }

    @Test("no code of the new stack places a toolbar item on the keyboard")
    func noKeyboardPlacement() throws {
        var found: [String] = []
        for path in try Self.swiftFiles() {
            found += Self.problems(in: try Repository.text(path)).map { "\(path):\($0)" }
        }

        #expect(found.isEmpty, "A toolbar item placed on the keyboard logs a frame warning; use KeyboardDoneBar with aboveTheKeyboard: \(found)")
    }

    // MARK: - The check itself

    @Test("the check finds an item or a group placed on the keyboard, with the type or without", arguments: [
        "ToolbarItemGroup(placement: .keyboard) {",
        "ToolbarItem(placement: .keyboard) {",
        "ToolbarItemGroup(placement: ToolbarItemPlacement.keyboard) {",
        "ToolbarItem(placement:.keyboard) {",
        "let placement: ToolbarItemPlacement = .keyboard",
        "items(at: ToolbarItemPlacement.keyboard)",
        "ToolbarItem(placement: compact ? .keyboard : .bottomBar) {",
        "ToolbarItem(placement: compact ? .bottomBar : .keyboard) {",
        "var placement: ToolbarItemPlacement { .keyboard }",
        "return .keyboard",
        "ToolbarItem(placement:\n    .keyboard) {",
    ])
    func findsAKeyboardPlacement(source: String) {
        #expect(Self.problems(in: source) == [1], "\(source)")
    }

    @Test("the check finds a placement whose call runs over several lines, on the line of the placement")
    func findsASplitCall() {
        let source = """
        .toolbar {
            ToolbarItemGroup(
                placement: .keyboard
            ) {
                Button("Done") {}
            }
        }
        """

        #expect(Self.problems(in: source) == [3])
    }

    @Test("the check does not mind a comment, the keyboard's safe area, a keyboard of a field or another placement")
    func ignoresWhatIsNotAKeyboardPlacement() {
        let source = """
        // ToolbarItemGroup(placement: .keyboard) logged a frame warning
        /* ToolbarItem(placement: .keyboard) */
        .ignoresSafeArea(.keyboard)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .keyboardType(input.keyboard)
        let type = field?.keyboard
        .keyboardShortcut(.defaultAction)
        ToolbarItem(placement: .bottomBar) {}
        .aboveTheKeyboard(shown: focus != nil) {
            KeyboardDoneBar("editor.done") {}
        }
        """

        #expect(Self.problems(in: source).isEmpty, "\(Self.problems(in: source))")
    }
}
