import Foundation
import PrestoCVCore

/// A row of the editor as the user sees it.
protocol EditorRow {
    /// True when the user has put nothing in the row, so deleting it loses nothing.
    var isBlank: Bool { get }
    /// What the row is called in its delete button and in the confirmation to delete it.
    var displayName: String { get }
    /// What tells this row from every other, whatever is typed in it: the row is the same row after its text was
    /// edited, and a row that took its place is another row, even with the same text.
    var identity: AnyHashable { get }
}

extension EditorRow where Self: Identifiable, Self.ID: Hashable {
    var identity: AnyHashable { AnyHashable(id) }
}

extension EditorRow {
    /// What the delete action of the row says to VoiceOver, so that it names the item it deletes: "Delete Swift".
    var deleteActionLabel: String {
        "accessibility.delete_row".localizedWithArgs(displayName)
    }
}

private extension String {
    var isBlankText: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// The first of the texts that holds something, or the placeholder of the field the user would fill in first.
private func firstFilled(of texts: [String], orPlaceholder placeholderKey: String) -> String {
    texts.first { !$0.isBlankText } ?? placeholderKey.localized
}

extension Skill: EditorRow {
    var isBlank: Bool { name.isBlankText && level == Skill().level }
    var displayName: String { firstFilled(of: [name], orPlaceholder: "field.skill") }
}

extension Experience: EditorRow {
    var isBlank: Bool { [title, company, location, period, description].allSatisfy(\.isBlankText) }
    var displayName: String { firstFilled(of: [title, company], orPlaceholder: "field.job_title") }
}

extension Education: EditorRow {
    var isBlank: Bool { [degree, school, period, description].allSatisfy(\.isBlankText) }
    var displayName: String { firstFilled(of: [degree, school], orPlaceholder: "field.degree") }
}

extension Language: EditorRow {
    var isBlank: Bool { name.isBlankText && level == Language().level }
    var displayName: String { firstFilled(of: [name], orPlaceholder: "field.language") }
}

extension Certification: EditorRow {
    var isBlank: Bool { [name, issuer, url, description].allSatisfy(\.isBlankText) && year == Certification().year }
    var displayName: String { firstFilled(of: [name, issuer], orPlaceholder: "field.certification_name") }
}

extension Social: EditorRow {
    var isBlank: Bool { [platform, url].allSatisfy(\.isBlankText) }
    var displayName: String { firstFilled(of: [platform, url], orPlaceholder: "field.platform") }
}

/// An interest is a plain string in the CV; this gives it the shape of the other rows.
struct InterestEntry: EditorRow {
    let text: String

    var isBlank: Bool { text.isBlankText }
    var displayName: String { firstFilled(of: [text], orPlaceholder: "field.interest") }
    /// A plain string has nothing but its text to tell it from another interest.
    var identity: AnyHashable { text }
}
