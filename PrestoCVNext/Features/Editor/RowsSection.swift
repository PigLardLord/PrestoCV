import PrestoCVPresentation
import SwiftUI

/// Where the person types in a row: the row, by its id, and the field; in a period, the year of its start or of its end.
struct RowFocus: Hashable {
    let row: RowID
    let field: EditorField
    var isEnd = false
}

/// A section of rows: its rows, each in a `ForEach` over its id, and the button that adds one at the end. The editor adds
/// and removes the rows; the section only shows them.
struct RowsSection<Row: Identifiable, Fields: View>: View where Row.ID == RowID {
    let editor: EditorViewModel
    let section: EditorSection
    let rows: [Row]
    /// What the row is called where the person must tell it from the others.
    let name: (Row) -> RowName
    /// The field that takes the focus when the row is added.
    let first: EditorField
    let focus: FocusState<RowFocus?>.Binding
    @ViewBuilder let fields: (Row, RowFields) -> Fields

    var body: some View {
        Section {
            ForEach(rows) { row in
                EditorRowView(
                    editor: editor, section: section, id: row.id, name: words(of: name(row)), first: first, focus: focus
                ) {
                    fields(row, RowFields(row: row.id, focus: focus))
                }
            }
            Button {
                editor.addRow(to: section)
            } label: {
                Label(section.words.add, systemImage: "plus")
            }
            .frame(minHeight: TapTarget.minimumHeight)
            .accessibilityIdentifier("editor.add.\(section)")
        } header: {
            Text(section.words.title)
        }
    }

    /// The row's name as the person reads it: its text, or what a row of its section with none is called (R13).
    private func words(of name: RowName) -> String {
        switch name {
        case .text(let text): text
        case .placeholder(let section): String(localized: section.words.unnamed)
        }
    }
}

/// One row, its fields together. Delete is in its context menu, behind a swipe and among the actions of VoiceOver,
/// named after the row; a row with something in it goes only once the person confirms. The row just added takes the
/// focus in its first field.
struct EditorRowView<Fields: View>: View {
    let editor: EditorViewModel
    let section: EditorSection
    let id: RowID
    let name: String
    let first: EditorField
    let focus: FocusState<RowFocus?>.Binding
    @ViewBuilder let fields: Fields

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) { fields }
            .padding(.vertical, Spacing.small)
            .contextMenu {
                Button("editor.row.delete.named \(name)", systemImage: "trash", role: .destructive, action: remove)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                // No destructive role: it would take the row off the screen before the person confirms
                Button("editor.row.delete", systemImage: "trash", action: remove)
                    .tint(.red)
            }
            // The row is not an accessibility element of its own, so SwiftUI gives this action to each field and menu of
            // the row, where VoiceOver lands. A containing element (`.accessibilityElement(children: .contain)`) would keep
            // the action on the row and take it off the fields.
            .accessibilityAction(named: Text("editor.row.delete.named \(name)"), remove)
            .confirmationDialog(Text("editor.row.delete.title \(name)"), isPresented: asksToRemove, titleVisibility: .visible) {
                Button("editor.row.delete", role: .destructive) { editor.confirmRemoval() }
                Button("editor.cancel", role: .cancel) { editor.cancelRemoval() }
            } message: {
                Text("editor.row.delete.message")
            }
            .task(id: editor.addedRow) {
                guard editor.addedRow == id else { return }
                focus.wrappedValue = RowFocus(row: id, field: first)
                editor.rowWasShown()
            }
    }

    private func remove() {
        editor.removeRow(in: section, id: id)
    }

    /// Whether the editor waits for the person to confirm the removal of this row.
    private var asksToRemove: Binding<Bool> {
        Binding {
            editor.pendingRemoval?.row == id
        } set: { shown in
            if !shown { editor.cancelRemoval() }
        }
    }
}

/// The fields of one row, each bound to it by the row's id and focused as the pair of the row and the field. Its
/// accessibility identifier is the field's name. It builds views, so it lives on the main actor as they do.
@MainActor
struct RowFields {
    let row: RowID
    let focus: FocusState<RowFocus?>.Binding

    /// `note` is what the person should know about the text, once the editor names a problem with it.
    func line(
        _ label: LocalizedStringResource, _ text: Binding<String>, _ field: EditorField, note: LocalizedStringResource? = nil
    ) -> some View {
        LabeledField(label, text: text, focus: focus, as: RowFocus(row: row, field: field), note: note)
            .fieldInput(field.input)
            .accessibilityIdentifier("editor.field.\(field)")
    }

    func paragraph(_ label: LocalizedStringResource, _ text: Binding<String>, _ field: EditorField) -> some View {
        ParagraphField(label, text: text, focus: focus, as: RowFocus(row: row, field: field))
            .fieldInput(field.input)
            .accessibilityIdentifier("editor.field.\(field)")
    }
}

private extension EditorSection {
    /// The words of the section: its title, its add button, and what a row with no name is called (R13).
    var words: (title: LocalizedStringResource, add: LocalizedStringResource, unnamed: LocalizedStringResource) {
        switch self {
        case .experiences: ("editor.section.experience", "editor.add.experience", "editor.unnamed.experience")
        case .education: ("editor.section.education", "editor.add.education", "editor.unnamed.education")
        case .skills: ("editor.section.skills", "editor.add.skill", "editor.unnamed.skill")
        case .languages: ("editor.section.languages", "editor.add.language", "editor.unnamed.language")
        case .certifications: ("editor.section.certifications", "editor.add.certification", "editor.unnamed.certification")
        case .profiles: ("editor.section.profiles", "editor.add.profile", "editor.unnamed.profile")
        case .interests: ("editor.section.interests", "editor.add.interest", "editor.unnamed.interest")
        }
    }
}
