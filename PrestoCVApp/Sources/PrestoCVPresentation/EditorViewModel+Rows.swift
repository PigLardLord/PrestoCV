import Foundation

/// The row of a section the person asked to remove, found by its id, which waits for the confirmation.
public struct RowRemoval: Hashable, Sendable {
    public let section: EditorSection
    public let row: RowID
    /// What the confirmation calls the row.
    public let name: RowName
}

/// What a row is called where the person must tell it from the others: the confirmation of its removal and its delete
/// action.
public enum RowName: Hashable, Sendable {
    /// The first text of the fields that name the row, without the spaces around it.
    case text(String)
    /// None of those fields has text: the view words a name for a row of the section.
    case placeholder(EditorSection)

    /// The first of `texts` that has more than spaces, else the placeholder of `section`.
    init(first texts: [String], or section: EditorSection) {
        if let text = texts.first(where: { !$0.isBlank }) {
            self = .text(text.trimmingCharacters(in: .whitespacesAndNewlines))
        } else {
            self = .placeholder(section)
        }
    }
}

extension EditorViewModel {

    /// Adds an empty row at the end of the section, as the row to show (`addedRow`). It is an edit like typing: the
    /// autosave stores the CV with it.
    public func addRow(to section: EditorSection) {
        var changed = form
        let id = rowIDs.make()
        changed.addRow(to: section, id: id)
        edit(changed)
        addedRow = id
    }

    /// The view has focused the added row and scrolled it into view: no row waits to be shown.
    public func rowWasShown() {
        addedRow = nil
    }

    /// Asks to remove the row of the section with `id`. A row with nothing in it goes at once; any other waits for
    /// `confirmRemoval()`, and `cancelRemoval()` keeps it. A row that is not there asks for nothing.
    public func removeRow(in section: EditorSection, id: RowID) {
        guard let name = form.rowName(in: section, id: id) else { return }
        let request = RowRemoval(section: section, row: id, name: name)
        if form.rowIsBlank(in: section, id: id) {
            pendingRemoval = nil
            remove(request)
        } else {
            pendingRemoval = request
        }
    }

    /// Removes the row last asked for, if it is still in its section. Without a request, or if the row went meanwhile
    /// (another form took its place, or the view replaced the rows), it does nothing.
    public func confirmRemoval() {
        guard let request = pendingRemoval else { return }
        pendingRemoval = nil
        remove(request)
    }

    /// Keeps the row last asked for.
    public func cancelRemoval() {
        pendingRemoval = nil
    }

    private func remove(_ request: RowRemoval) {
        guard form.hasRow(in: request.section, id: request.row) else { return }
        var changed = form
        changed.removeRow(in: request.section, id: request.row)
        edit(changed)
    }
}

// MARK: - Names

// A row is named by its one-line fields that say what it is, never by a description or a date.

extension ExperienceRow {
    /// The role, else the company.
    public var rowName: RowName { RowName(first: [role, company], or: .experiences) }
}

extension EducationRow {
    /// The degree, else the school.
    public var rowName: RowName { RowName(first: [degree, school], or: .education) }
}

extension SkillRow {
    public var rowName: RowName { RowName(first: [name], or: .skills) }
}

extension LanguageRow {
    public var rowName: RowName { RowName(first: [language], or: .languages) }
}

extension CertificationRow {
    /// The certification's name, else who issued it.
    public var rowName: RowName { RowName(first: [name, issuer], or: .certifications) }
}

extension ProfileRow {
    /// The platform, else the link.
    public var rowName: RowName { RowName(first: [platform, link], or: .profiles) }
}

extension InterestRow {
    public var rowName: RowName { RowName(first: [text], or: .interests) }
}
