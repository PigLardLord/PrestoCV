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

    @Test("The identity of a row, by which the form scrolls to it, is the last modifier after the swipe actions")
    func rowIdentityComesAfterTheSwipeActions() throws {
        let source = try componentSource("EditableItemsList.swift")

        let swipe = try #require(source.range(of: ".swipeActions("))
        let identity = try #require(source.range(of: ".id(newRowFocus?.identity(ofRow:"))
        // Inside the swipe actions the id is not that of the row the list scrolls to: a row added low on the screen then
        // stops under the Done button, as seen on iOS 27.0
        #expect(swipe.lowerBound < identity.lowerBound, "A row with swipe actions gets its id from the modifier outside them")
    }

    @Test("The list no longer deletes through onDelete, which cannot name the row")
    func listDoesNotUseOnDelete() throws {
        let source = try componentSource("EditableItemsList.swift")

        #expect(!source.contains(".onDelete("))
    }

    @Test("The anchor of the confirmation is described as the row that was swiped, not as a button")
    func anchorIsDescribedAsTheSwipedRow() throws {
        let url = Repository.root
            .appendingPathComponent("PrestoCV")
            .appendingPathComponent("DesignSystem")
            .appendingPathComponent("Components")
            .appendingPathComponent("AnchoredConfirmationDialog.swift")
        let source = try String(contentsOf: url, encoding: .utf8)

        // The delete button is a swipe action now; nothing in the rows is a trash button any more
        #expect(!source.contains("trash button"), "The comment of RowDeletionAnchor still names the button the rows used to have")
        let anchor = try #require(source.range(of: "final class RowDeletionAnchor"))
        let comment = String(source[..<anchor.lowerBound].suffix(300))
        #expect(comment.contains("swipe"), "The anchor is the row whose delete button was swiped open")
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
