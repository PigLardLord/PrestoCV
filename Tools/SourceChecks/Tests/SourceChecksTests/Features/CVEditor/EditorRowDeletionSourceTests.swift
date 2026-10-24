import Testing
import Foundation

// MARK: - How the rows of the editor are deleted

/// A row is deleted by one deliberate gesture, the swipe, and never by a control inside the row: a tap beside the stars
/// or the language picker must not reach a delete button. These checks pin the source that makes that so.
@Suite("Editor rows - one deliberate way to delete")
struct EditorRowDeletionSourceTests {

    // MARK: - Helpers

    private func componentSource(_ file: String) throws -> String {
        let url = Repository.root
            .appendingPathComponent("PrestoCV")
            .appendingPathComponent("Features")
            .appendingPathComponent("CVEditor")
            .appendingPathComponent("Views")
            .appendingPathComponent("Components")
            .appendingPathComponent(file)
        return try String(contentsOf: url, encoding: .utf8)
    }

    // MARK: - The swipe

    @Test("The list swipes open a delete button that names the row, with role none and the error tint")
    func swipeActionNamesTheRow() throws {
        let source = try componentSource("EditableItemsList.swift")

        #expect(source.contains(".swipeActions(edge: .trailing, allowsFullSwipe: false)"), "A swipe opens the row; a long swipe must not delete it")
        #expect(source.contains("Button(role: .none"), "role .destructive makes the confirmation dialog flicker, as on the list of CVs")
        #expect(!source.contains("role: .destructive"))
        #expect(source.contains(".tint(DesignTokens.Colors.error)"))
        #expect(source.contains(".accessibilityLabel(deleteLabel("), "VoiceOver hears which item the button deletes")
    }

    @Test("The list no longer deletes through onDelete, which cannot name the row")
    func listDoesNotUseOnDelete() throws {
        let source = try componentSource("EditableItemsList.swift")

        #expect(!source.contains(".onDelete("))
    }

    // MARK: - No delete control inside a row

    @Test("No row of the editor holds a delete button or a trash icon")
    func rowsHaveNoTrash() throws {
        let source = try componentSource("CVRowComponents.swift")

        #expect(!source.contains("DeleteButton"))
        #expect(!source.contains("\"trash\""))
        #expect(!source.contains("onDelete"), "The rows do not delete themselves: the list does")
    }

    @Test("Every section of the editor says how a row is named when it is deleted")
    func sectionsNameTheirRows() throws {
        let sections = try ["ExperienceSection.swift", "DetailsSection.swift"].map(componentSource)

        let namedLists = sections.map { $0.components(separatedBy: "deleteLabel:").count - 1 }.reduce(0, +)
        let lists = sections.map { $0.components(separatedBy: "CVEditableSection(").count - 1 }.reduce(0, +)
        #expect(lists == 7, "The editor lists seven kinds of row")
        #expect(namedLists == lists, "Each list must pass the label of its delete button")
    }
}
