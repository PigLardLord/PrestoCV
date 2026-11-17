import PrestoCVPresentation
import SwiftUI

/// The page of one row on a narrow screen: where the text stands, the row's fields in groups, and the button that deletes
/// it. A row with something in it goes only once the person confirms, in a question that comes from that button. The
/// row just added takes the focus in its first field. The editor opens and closes the page; the page shows the row.
struct EntryPage: View {
    @Bindable var editor: EditorViewModel
    let entry: EditorEntry
    @FocusState private var focus: RowFocus?

    var body: some View {
        Form {
            // In the form, not in the bar: a bar does not grow with the text size, and a long status would be cut there
            Section {
                SaveStatusLine(status: editor.saveStatus)
            }
            fields
            Section {
                Button(role: .destructive) {
                    editor.removeRow(in: entry.section, id: entry.row)
                } label: {
                    Text(entry.section.entryWords.delete)
                }
                .frame(minHeight: TapTarget.minimumHeight)
                .accessibilityIdentifier("editor.entry.delete")
                // On the button, not on the form: on an iPhone the question is a popover from the view that holds it
                .confirmationDialog(
                    Text("editor.row.delete.title \(removalName)"), isPresented: asksToRemove, titleVisibility: .visible
                ) {
                    Button("editor.row.delete", role: .destructive) { editor.confirmRemoval() }
                    Button("editor.cancel", role: .cancel) { editor.cancelRemoval() }
                } message: {
                    Text("editor.row.delete.message")
                }
            }
        }
        .formStyle(.grouped)
        .readableScrollContent()
        .navigationTitle(Text(entry.section.entryWords.title))
        .inlineNavigationTitle()
        .accessibilityIdentifier("editor.entry.page")
        .aboveTheKeyboard(shown: focus != nil) {
            KeyboardDoneBar("editor.done") { focus = nil }
        }
        // A problem with a field's text is named once the person leaves it, as in the form
        .onChange(of: focus) { left, _ in
            if let left { editor.fieldWasLeft(left.field, row: left.row) }
        }
        .task(id: editor.addedRow) {
            guard editor.addedRow == entry.row else { return }
            focus = RowFocus(row: entry.row, field: entry.section.firstField)
            editor.rowWasShown()
        }
    }

    /// The row's fields, while the row is in its section: once it goes, the editor closes the page.
    @ViewBuilder
    private var fields: some View {
        let rowFields = RowFields(row: entry.row, focus: $focus)
        switch entry.section {
        case .experiences:
            if let row = editor.content.experiences[row: entry.row] {
                JobFields(editor: editor, row: row, fields: rowFields, onPage: true)
            }
        case .education:
            if let row = editor.content.education[row: entry.row] {
                DegreeFields(editor: editor, row: row, fields: rowFields, onPage: true)
            }
        case .languages:
            if let row = editor.content.languages[row: entry.row] {
                LanguageFields(editor: editor, row: row, fields: rowFields, onPage: true)
            }
        case .certifications:
            if let row = editor.content.certifications[row: entry.row] {
                CertificationFields(editor: editor, row: row, fields: rowFields, onPage: true)
            }
        case .profiles:
            if let row = editor.content.profiles[row: entry.row] {
                ProfileFields(editor: editor, row: row, fields: rowFields, onPage: true)
            }
        case .skills, .interests:
            // Their rows stay in the form: the editor opens no page for them
            EmptyView()
        }
    }

    /// The name of the row the editor asks about, in the question.
    private var removalName: String {
        (editor.pendingRemoval?.name ?? .placeholder(entry.section)).words
    }

    /// Whether the editor waits for the person to confirm the removal of this row here, on its page.
    private var asksToRemove: Binding<Bool> {
        Binding {
            editor.asksToRemove(row: entry.row, onItsPage: true)
        } set: { shown in
            if !shown { editor.cancelRemoval() }
        }
    }
}

private extension EditorSection {
    /// The words of a row's page: its title and its delete button (R13). A skill and an interest have no page.
    var entryWords: (title: LocalizedStringResource, delete: LocalizedStringResource) {
        switch self {
        case .experiences: ("editor.entry.title.experience", "editor.entry.delete.experience")
        case .education: ("editor.entry.title.education", "editor.entry.delete.education")
        case .languages: ("editor.entry.title.language", "editor.entry.delete.language")
        case .certifications: ("editor.entry.title.certification", "editor.entry.delete.certification")
        case .profiles: ("editor.entry.title.profile", "editor.entry.delete.profile")
        case .skills: ("editor.section.skills", "editor.row.delete")
        case .interests: ("editor.section.interests", "editor.row.delete")
        }
    }
}
