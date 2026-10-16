import Testing
import Foundation
import SwiftUI
@testable import PrestoCV

/// A control drawn in the accent shows its press without losing contrast. The styles of the design system keep the
/// label and its fill opaque while pressed, and every button, navigation link, menu or link of the app drawn in the
/// accent, or in the system's tint, goes through one of them, unless the system draws it.
@Suite("Buttons in the accent - an opaque press through the design system")
@MainActor
struct ButtonPressTests {

    // MARK: - The rule

    /// The controls the rule reads: each draws its label as a button does, and the system tints it.
    static let controlNames = ["Button", "NavigationLink", "Menu", "Link"]

    /// The styles of the design system, none of which fades a pressed control: `PrimaryButtonStyle` (a fill of the
    /// accent), `AccentTextButtonStyle` (text in the accent) and `CardButtonStyle` (a card, whatever it draws).
    static let designSystemStyles = ["PrimaryButtonStyle", "AccentTextButtonStyle", "CardButtonStyle"]

    /// The styles that colour the label themselves: a colour the label sets would hide their pressed colour.
    static let colouringStyles = ["PrimaryButtonStyle", "AccentTextButtonStyle"]

    /// The calls whose controls the system draws, press included: the bars of a navigation stack and of the keyboard
    /// (Liquid Glass), alerts, confirmation dialogs (`anchoredConfirmationDialog` presents one), swipe actions, and
    /// the items of a context menu or of a menu.
    static let systemContainers: Set<String> = [
        "toolbar", "ToolbarItem", "ToolbarItemGroup", "alert", "confirmationDialog", "anchoredConfirmationDialog",
        "swipeActions", "contextMenu", "Menu",
    ]

    /// A navigation link in a list or a form is one of its rows: the system draws its label in the colour of text,
    /// not in the tint, and its press as the row's highlight. One drawn in the accent still needs a style.
    static let untintedRowContainers: Set<String> = ["List", "Form"]

    /// The controls the system draws and presses although the source does not place them in one of the system's
    /// containers: the file, a piece of the call that tells the control, and why the system owns it.
    static let systemOwned: [(path: String, call: String, reason: String)] = [
        ("PrestoCV/DesignSystem/Components/BarButton.swift", "BarButtonContent.resolve",
         "the button of a navigation bar, drawn by the bar on Liquid Glass; BarButton goes only in toolbars, as a test checks"),
        ("PrestoCV/Features/Export/Views/CVExportSheetView.swift", "shareLabel",
         "the share button while the PDF is not ready, an item of the export sheet's toolbar: ToolbarItem { shareButton }"),
        ("PrestoCV/Features/Onboarding/Views/ExampleSelectionView.swift", "row(for: sample)",
         "a row of a List: its label sets its own colours, primary and secondary, in row(for:), and the list draws the press as the row's highlight"),
    ]

    /// The colours that draw a control in the accent.
    static let accentTokens = ["Colors.accent", "Colors.onAccent", "primaryButton", "secondaryButton", "swipeActionTint", "accentColor", ".tint("]

    @Test("Every button, navigation link, menu or link drawn in the accent or in the system's tint uses a style of the design system, unless the system draws it")
    func accentControlsUseADesignSystemStyle() throws {
        let controls = try Self.controls()
        try #require(!controls.isEmpty, "The sources of the app are next to the tests")

        let offending = Self.unprotected(controls)
        let stale = Self.systemOwned.filter { entry in !controls.contains { $0.path == entry.path && $0.call.contains(entry.call) } }

        #expect(offending.isEmpty, "Draw these with a style of the design system:\n\(offending.map(Self.describe).joined(separator: "\n"))")
        #expect(stale.isEmpty, "These exceptions match no control: \(stale.map(\.path))")
    }

    @Test("A control whose style colours its label sets no colour of its own in the label, which would hide the pressed colour")
    func colouringStylesOwnTheLabelColour() throws {
        let offending = try Self.controls().filter { control in
            Self.colouringStyles.contains(Self.style(of: control) ?? "") && Self.setsAColour(control.call)
        }

        #expect(offending.isEmpty, "\(offending.map(Self.describe).joined(separator: "\n"))")
    }

    @Test("BarButton goes only in toolbars, where the system draws it")
    func barButtonsAreInToolbars() throws {
        let uses = try RepositorySources.swiftFiles(in: "PrestoCV").flatMap { ButtonScan(path: $0.path, text: $0.text).uses(of: "BarButton") }
        try #require(!uses.isEmpty, "The app has bar buttons")

        let outside = uses.filter { $0.enclosing.allSatisfy { !["toolbar", "ToolbarItem", "ToolbarItemGroup"].contains($0) } }
        #expect(outside.isEmpty, "\(outside.map(Self.describe).joined(separator: "\n"))")
    }

    // MARK: - The rule on small sources

    /// A small source, and whether the rule rejects a control in it.
    struct Fixture: CustomTestStringConvertible, Sendable {
        let name: String
        let source: String
        let rejected: Bool
        var testDescription: String { name }
    }

    static let fixtures = [
        Fixture(name: "a Button in the accent", source: """
            struct Screen: View {
                var body: some View {
                    Button("Add") { add() }
                        .foregroundColor(DesignTokens.Colors.accent)
                }
            }
            """, rejected: true),
        Fixture(name: "a Button in the system's tint", source: """
            VStack {
                Button(action: add) { Label("Add", systemImage: "plus") }
            }
            """, rejected: true),
        Fixture(name: "a NavigationLink in the system's tint", source: """
            VStack {
                NavigationLink(value: Route.settings) { Text("Settings") }
            }
            """, rejected: true),
        Fixture(name: "a Menu in the accent", source: """
            Menu {
                Button("Rename") { rename() }
            } label: {
                Label("More", systemImage: "ellipsis").foregroundStyle(DesignTokens.Colors.accent)
            }
            """, rejected: true),
        Fixture(name: "a Link in the system's tint", source: """
            Link("Privacy policy", destination: policyURL)
            """, rejected: true),
        Fixture(name: "a Button built in a helper function", source: """
            struct Screen: View {
                var body: some View { addButton() }

                private func addButton() -> some View {
                    Button(action: add) {
                        Text("Add").foregroundColor(DesignTokens.Colors.accent)
                    }
                }
            }
            """, rejected: true),
        Fixture(name: "a Button with a role", source: """
            Button(role: .destructive) { delete() } label: {
                Text("Delete").foregroundColor(DesignTokens.Colors.accent)
            }
            """, rejected: true),
        Fixture(name: "an accent NavigationLink row of a List", source: """
            List {
                NavigationLink(value: Route.settings) {
                    Text("Settings").foregroundColor(DesignTokens.Colors.accent)
                }
            }
            """, rejected: true),
        Fixture(name: "a Button with a style of the design system", source: """
            Button(action: add) { Label("Add", systemImage: "plus") }
                .buttonStyle(AccentTextButtonStyle())
            """, rejected: false),
        Fixture(name: "a NavigationLink with a style of the design system", source: """
            NavigationLink(value: Route.settings) { Text("Settings") }
                .buttonStyle(PrimaryButtonStyle(isDisabled: false))
            """, rejected: false),
        Fixture(name: "a Menu with a style of the design system, and its items", source: """
            Menu {
                Button("Rename") { rename() }
            } label: {
                Text("More")
            }
            .buttonStyle(AccentTextButtonStyle())
            """, rejected: false),
        Fixture(name: "a Button in a toolbar", source: """
            content.toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add") { add() }.foregroundColor(DesignTokens.Colors.accent)
                }
            }
            """, rejected: false),
        Fixture(name: "a Menu in a toolbar", source: """
            content.toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu("More") { Button("Rename") { rename() } }
                }
            }
            """, rejected: false),
        Fixture(name: "a Button in an alert", source: """
            content.alert("Saved", isPresented: $isShowingAlert, actions: {
                Button("OK", role: .cancel) { }
            }, message: {
                Text("Your CV is saved.")
            })
            """, rejected: false),
        Fixture(name: "a NavigationLink row of a List in the colour of text", source: """
            List {
                NavigationLink(value: Route.settings) { Text("Settings") }
            }
            """, rejected: false),
        Fixture(name: "a Button that is only words in a comment or a string", source: """
            // Button("Add") { }.foregroundColor(DesignTokens.Colors.accent)
            Text("Button(Add) { } NavigationLink { } Menu { } Link(")
            """, rejected: false),
    ]

    @Test("The rule rejects an unprotected control in the accent or the tint, and passes a styled one or one the system draws",
          arguments: fixtures)
    func ruleOnSmallSources(fixture: Fixture) {
        let controls = Self.controls(in: ButtonScan(path: "Fixture.swift", text: fixture.source))

        #expect(!Self.unprotected(controls).isEmpty == fixture.rejected,
                "\(fixture.name): \(controls.map { "\($0.name) in [\($0.enclosing.joined(separator: ", "))]" })")
    }

    @Test("The scanner sees a control wherever the source builds it, and not in a comment or a string", arguments: fixtures)
    func scannerSeesTheControls(fixture: Fixture) {
        let controls = Self.controls(in: ButtonScan(path: "Fixture.swift", text: fixture.source))

        if fixture.name.contains("comment") {
            #expect(controls.isEmpty, "\(controls.map(Self.describe))")
        } else {
            #expect(!controls.isEmpty, "the scanner sees no control in \(fixture.name)")
        }
    }

    // MARK: - The add button

    @Test("An add button draws its title with AccentTextButtonStyle, readable at rest and pressed on a form row, a card and a screen",
          arguments: [false, true])
    func addButtonIsReadable(isPressed: Bool) throws {
        let addButtons = try Self.controls().filter { $0.enclosing.contains("AddButton") }
        try #require(addButtons.count == 1, "AddButton draws one button")
        let addButton = try #require(addButtons.first)
        #expect(Self.style(of: addButton) == "AccentTextButtonStyle", "\(Self.describe(addButton))")
        #expect(!Self.setsAColour(addButton.call), "AddButton sets a colour of its own: \(Self.describe(addButton))")

        let title = AccentTextButtonStyle.foregroundColor(isPressed: isPressed)
        for appearance in AccentColorTests.Appearance.allCases {
            for background in AccentColorTests.textBackgrounds {
                let pair = AccentColorTests.ContrastPair(name: "", foreground: title, background: background.color)
                let ratio = appearance.contrast(of: pair)

                #expect(ratio >= 4.5, "an add button, pressed \(isPressed), on \(background.name) in the \(appearance.rawValue) appearance reaches \(ratio):1")
            }
        }
    }

    // MARK: - Reading a control

    /// The controls of the app's sources.
    static func controls() throws -> [ButtonScan.Use] {
        try RepositorySources.swiftFiles(in: "PrestoCV").flatMap { controls(in: ButtonScan(path: $0.path, text: $0.text)) }
    }

    static func controls(in scan: ButtonScan) -> [ButtonScan.Use] {
        controlNames.flatMap { scan.uses(of: $0) }
    }

    /// The controls drawn in the accent or in the tint with no style of the design system, outside what the system draws.
    static func unprotected(_ controls: [ButtonScan.Use]) -> [ButtonScan.Use] {
        controls.filter { control in
            (isInAccent(control) || isInTint(control)) && style(of: control) == nil && !isSystemOwned(control)
        }
    }

    /// The style of the design system that draws the control, if one does.
    static func style(of control: ButtonScan.Use) -> String? {
        designSystemStyles.first { control.modifiers.contains(".buttonStyle(\($0)(") }
    }

    static func isInAccent(_ control: ButtonScan.Use) -> Bool {
        accentTokens.contains { (control.call + control.modifiers).contains($0) }
    }

    /// Whether the label takes the system's tint: the system's styles, all but the plain one, tint a label that sets no
    /// colour of its own; a navigation link that is a row of a list or a form takes the colour of text.
    static func isInTint(_ control: ButtonScan.Use) -> Bool {
        let plain = control.modifiers.contains(".buttonStyle(.plain)") || control.modifiers.contains(".buttonStyle(PlainButtonStyle())")
        let row = control.name == "NavigationLink" && !untintedRowContainers.isDisjoint(with: control.enclosing)
        return !plain && !row && style(of: control) == nil && !setsAColour(control.call + control.modifiers)
    }

    static func setsAColour(_ code: String) -> Bool {
        code.contains("foregroundColor(") || code.contains("foregroundStyle(")
    }

    static func isSystemOwned(_ control: ButtonScan.Use) -> Bool {
        !systemContainers.isDisjoint(with: control.enclosing)
            || systemOwned.contains { control.path == $0.path && control.call.contains($0.call) }
    }

    static func describe(_ control: ButtonScan.Use) -> String {
        "\(control.path):\(control.line): \(control.call.prefix { $0 != "\n" })"
    }
}

// MARK: - Helpers

/// The uses of a view in a Swift source, read from the source: each call with its trailing closures, its modifiers and
/// the calls it sits in. Comments and the text of string literals are blanked first, so that neither can unbalance a
/// bracket.
struct ButtonScan {
    struct Use {
        /// The view called, such as `Button`
        let name: String
        let path: String
        let line: Int
        /// The call with its trailing closures, which hold the label
        let call: String
        /// The modifiers chained after the call
        let modifiers: String
        /// The names of the calls and arguments around the use, innermost first: `ToolbarItem`, `toolbar`, ...
        let enclosing: [String]
    }

    let path: String
    private let code: [Character]

    init(path: String, text: String) {
        self.path = path
        self.code = Self.blank(Array(text))
    }

    /// Every call of the view `name`, as `name(...)` or `name { ... }`.
    func uses(of name: String) -> [Use] {
        let target = Array(name)
        var result: [Use] = []
        var index = 0
        while index + target.count <= code.count {
            defer { index += 1 }
            guard Array(code[index..<index + target.count]) == target,
                  index == 0 || !(Self.isIdentifier(code[index - 1]) || code[index - 1] == "."),
                  index + target.count == code.count || !Self.isIdentifier(code[index + target.count]) else { continue }
            let open = skipBlanks(from: index + target.count, acrossLines: false)
            guard open < code.count, code[open] == "(" || code[open] == "{" else { continue }

            var end = closing(open) + 1
            while true {
                let next = skipBlanks(from: end, acrossLines: true)
                if next < code.count, code[next] == "{" {
                    end = closing(next) + 1
                } else if let closure = labelledClosure(at: next) {
                    end = closing(closure) + 1
                } else {
                    break
                }
            }
            let callEnd = end
            while true {
                let dot = skipBlanks(from: end, acrossLines: true)
                guard dot + 1 < code.count, code[dot] == ".", Self.isIdentifier(code[dot + 1]) else { break }
                end = dot + 1
                while end < code.count, Self.isIdentifier(code[end]) { end += 1 }
                let arguments = skipBlanks(from: end, acrossLines: false)
                if arguments < code.count, code[arguments] == "(" { end = closing(arguments) + 1 }
                while true {
                    let closure = skipBlanks(from: end, acrossLines: false)
                    guard closure < code.count, code[closure] == "{" else { break }
                    end = closing(closure) + 1
                }
            }
            result.append(Use(
                name: name,
                path: path,
                line: code[..<index].filter { $0 == "\n" }.count + 1,
                call: String(code[index..<callEnd]),
                modifiers: String(code[callEnd..<end]),
                enclosing: enclosing(index)
            ))
        }
        return result
    }

    // MARK: Brackets

    private func skipBlanks(from start: Int, acrossLines: Bool) -> Int {
        var index = start
        while index < code.count, code[index] == " " || code[index] == "\t" || (acrossLines && code[index] == "\n") { index += 1 }
        return index
    }

    /// The bracket that closes the one at `open`.
    private func closing(_ open: Int) -> Int {
        var depth = 0
        for index in open..<code.count {
            switch code[index] {
            case "(", "{", "[": depth += 1
            case ")", "}", "]":
                depth -= 1
                if depth == 0 { return index }
            default: break
            }
        }
        return code.count - 1
    }

    /// The bracket that opens the one at `close`.
    private func opening(_ close: Int) -> Int {
        var depth = 0
        for index in stride(from: close, through: 0, by: -1) {
            switch code[index] {
            case ")", "}", "]": depth += 1
            case "(", "{", "[":
                depth -= 1
                if depth == 0 { return index }
            default: break
            }
        }
        return 0
    }

    /// The opening brace of a labelled trailing closure starting at `start`, such as `label: {`.
    private func labelledClosure(at start: Int) -> Int? {
        var index = start
        while index < code.count, Self.isIdentifier(code[index]) { index += 1 }
        guard index > start else { return nil }
        index = skipBlanks(from: index, acrossLines: false)
        guard index < code.count, code[index] == ":" else { return nil }
        index = skipBlanks(from: index + 1, acrossLines: false)
        return index < code.count && code[index] == "{" ? index : nil
    }

    /// The names of the brackets that enclose `start`, innermost first.
    private func enclosing(_ start: Int) -> [String] {
        var names: [String] = []
        var depth = 0
        for index in stride(from: start - 1, through: 0, by: -1) {
            switch code[index] {
            case ")", "}", "]": depth += 1
            case "(", "{", "[":
                if depth > 0 { depth -= 1 } else { names.append(name(of: index)) }
            default: break
            }
        }
        return names
    }

    /// The call, the argument or the type a bracket belongs to: `toolbar` for `.toolbar {`, `alert` for
    /// `.alert(...) {`, `actions` for `actions: {`, `AddButton` for `struct AddButton: View {`.
    private func name(of open: Int) -> String {
        let lineStart = code[..<open].lastIndex(of: "\n").map { $0 + 1 } ?? 0
        let words = String(code[lineStart..<open]).split(whereSeparator: { " :<(,".contains($0) })
        if let keyword = words.firstIndex(where: { ["struct", "class", "enum", "extension", "actor"].contains($0) }),
           keyword + 1 < words.count {
            return String(words[keyword + 1])
        }
        func back(_ from: Int) -> Int {
            var index = from
            while index >= 0, code[index] == " " || code[index] == "\t" || code[index] == "\n" { index -= 1 }
            return index
        }
        var end = back(open - 1)
        if code[open] == "{", end >= 0, code[end] == ")" { end = back(opening(end) - 1) }
        if end >= 0, code[end] == ":" { end = back(end - 1) }
        var start = end
        while start >= 0, Self.isIdentifier(code[start]) { start -= 1 }
        return end > start ? String(code[(start + 1)...end]) : ""
    }

    private static func isIdentifier(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_"
    }

    // MARK: Blanking

    /// The source with its comments and the text of its string literals turned into spaces. Line breaks stay, and so
    /// does the code of an interpolation.
    private static func blank(_ source: [Character]) -> [Character] {
        var blanked = source
        /// The open string literals, innermost last: how each ends, and the depth of the brackets of the
        /// interpolation being read in it, or nil while reading its text
        var literals: [(end: [Character], interpolation: Int?)] = []
        func starts(_ prefix: String, at index: Int) -> Bool {
            let characters = Array(prefix)
            return index + characters.count <= source.count && Array(source[index..<index + characters.count]) == characters
        }
        func clear(_ range: Range<Int>) {
            for index in range where index < source.count && source[index] != "\n" { blanked[index] = " " }
        }
        var index = 0
        while index < source.count {
            if let literal = literals.last, literal.interpolation == nil {
                if source[index] == "\\" && index + 1 < source.count && source[index + 1] == "(" {
                    clear(index..<index + 2)
                    literals[literals.count - 1].interpolation = 1
                    index += 2
                } else if source[index] == "\\" && literal.end.last != "#" {
                    clear(index..<index + 2)
                    index += 2
                } else if starts(String(literal.end), at: index) {
                    literals.removeLast()
                    index += literal.end.count
                } else {
                    clear(index..<index + 1)
                    index += 1
                }
                continue
            }
            if starts("//", at: index) {
                let lineEnd = source[index...].firstIndex(of: "\n") ?? source.count
                clear(index..<lineEnd)
                index = lineEnd
            } else if starts("/*", at: index) {
                var end = index + 2
                while end < source.count && !starts("*/", at: end) { end += 1 }
                clear(index..<min(end + 2, source.count))
                index = end + 2
            } else if starts("#\"", at: index) {
                literals.append((end: Array("\"#"), interpolation: nil))
                index += 2
            } else if starts("\"\"\"", at: index) {
                literals.append((end: Array("\"\"\""), interpolation: nil))
                index += 3
            } else if source[index] == "\"" {
                literals.append((end: ["\""], interpolation: nil))
                index += 1
            } else {
                if let depth = literals.last?.interpolation {
                    if source[index] == "(" {
                        literals[literals.count - 1].interpolation = depth + 1
                    } else if source[index] == ")" {
                        if depth == 1 {
                            clear(index..<index + 1)
                            literals[literals.count - 1].interpolation = nil
                        } else {
                            literals[literals.count - 1].interpolation = depth - 1
                        }
                    }
                }
                index += 1
            }
        }
        return blanked
    }
}
