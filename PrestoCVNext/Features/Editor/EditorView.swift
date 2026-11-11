import PrestoCVPresentation
import SwiftUI

/// The open CV: one form in the order the PDF shows it, stored by itself as the person types, with the line that says
/// where the text stands. It waits while the CV is read, and says so when it cannot be. VoiceOver is told of each change
/// in one announcement, queued after what it is saying: where the status settled, then the problems met that it does not
/// name. A row the person adds comes into view, and its first field takes the focus; the row with the focus stays in view
/// when the keyboard rises. On a narrow screen a job, a study, a language, a certification and a profile open on a page
/// of their own.
struct EditorView: View {
    @Bindable var editor: EditorViewModel
    /// The CV's name as the list shows it, or "New CV" for a draft.
    let title: Text
    @FocusState private var focus: EditorField?
    @FocusState private var rowFocus: RowFocus?

    var body: some View {
        content
            .navigationTitle(title)
            .inlineNavigationTitle()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("shell.detail.opened")
            .task { await editor.load() }
            // A narrow screen opens a job, a study and the like on a page of its own
            .onNarrowScreen { editor.layoutChanged(isNarrow: $0) }
            .announce(editor.announcement, sentences: \.sentences) { editor.announcementWasTold($0) }
    }

    @ViewBuilder
    private var content: some View {
        switch editor.opening {
        case .opening:
            LoadingView("editor.opening")
        case .missing:
            EmptyStateView(symbol: "doc.questionmark", title: "editor.missing.title", message: "editor.missing.message")
        case .failed:
            EmptyStateView(symbol: "exclamationmark.triangle", title: "editor.failed.title", message: "editor.failed.message")
        case .open:
            form
        }
    }

    private var form: some View {
        ScrollViewReader { proxy in
            Form {
                Section {
                    title
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("shell.detail.title")
                    SaveStatusLine(status: editor.saveStatus)
                }
                DetailsSection(editor: editor, focus: $focus)
                ExperienceSection(editor: editor, focus: $rowFocus)
                EducationSection(editor: editor, focus: $rowFocus)
                SkillsSection(editor: editor, focus: $rowFocus)
                LanguagesSection(editor: editor, focus: $rowFocus)
                CertificationsSection(editor: editor, focus: $rowFocus)
                ProfilesSection(editor: editor, focus: $rowFocus)
                InterestsSection(editor: editor, focus: $rowFocus)
            }
            .formStyle(.grouped)
            .readableScrollContent()
            .editRowsButton()
            .keyboardDoneBar("editor.done") {
                focus = nil
                rowFocus = nil
            }
            // A problem with a field's text is named once the person leaves it, never while they type
            .onChange(of: focus) { left, _ in
                if let left { editor.fieldWasLeft(left) }
            }
            // The same for a row's field; a period is left from either of its years
            .onChange(of: rowFocus) { left, _ in
                if let left { editor.fieldWasLeft(left.field, row: left.row) }
            }
            // The row itself takes the focus once it is on screen (EditorRowView)
            .onChange(of: editor.addedRow) { _, added in
                if let added { withAnimation { proxy.scrollTo(added) } }
            }
            // The keyboard takes its room only after the focus lands, so a row near the bottom (a new skill goes last)
            // would stay under it: once the room left for the form shrinks, the row with the focus comes into view
            .onGeometryChange(for: CGFloat.self) { $0.size.height - $0.safeAreaInsets.bottom } action: { old, new in
                if new < old, let row = rowFocus?.row { withAnimation { proxy.scrollTo(row) } }
            }
            .navigationDestination(item: openedEntry) { entry in
                EntryPage(editor: editor, entry: entry)
            }
        }
    }

    /// The row whose page is open; going back to the form closes it.
    private var openedEntry: Binding<EditorEntry?> {
        Binding {
            editor.openedEntry
        } set: { entry in
            if entry == nil { editor.closeEntry() }
        }
    }
}
