import PrestoCVPresentation
import SwiftUI

/// The open CV: one form in the order the PDF shows it, stored by itself as the person types, with the line that says
/// where the text stands. While the text cannot be stored as it is, a notice above the form says what to do and offers
/// the ways out (#402, decision 8). It waits while the CV is read, and says so when it cannot be, with a way to close
/// it. VoiceOver is told of each change in one announcement, queued after what it is saying: where the status settled
/// and, while the person cannot leave, what to do and the ways on (`SaveStatus.spoken(in:)`), then the problems met that
/// the status does not name. A row the person adds comes into view, and its first field takes the focus; while the focus
/// stays in it, it stays in view when the keyboard rises. On a narrow screen a job, a study, a language, a certification
/// and a profile open on a page of their own.
struct EditorView: View {
    @Bindable var editor: EditorViewModel
    /// The CV's name as the list shows it, or "New CV" for a draft.
    let title: Text
    /// Closes the editor without storing its text.
    let discard: () -> Void
    @FocusState private var focus: EditorField?
    @FocusState private var rowFocus: RowFocus?
    /// The row just added, while the focus is in it: the only row the form brings back into view when its room shrinks.
    @State private var newRow: RowID?
    /// The editor's height, for the notice's cap where the form is short of room.
    @State private var height: Double = 0
    @Environment(\.locale) private var locale

    var body: some View {
        content
            .navigationTitle(title)
            .inlineNavigationTitle()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("shell.detail.opened")
            .task { await editor.load() }
            // A narrow screen opens a job, a study and the like on a page of its own
            .onNarrowScreen { editor.layoutChanged(isNarrow: $0) }
            .announce(editor.announcement, sentences: { $0.sentences(in: locale) }) { editor.announcementWasTold($0) }
    }

    @ViewBuilder
    private var content: some View {
        switch editor.opening {
        case .opening:
            LoadingView("editor.opening")
        case .missing:
            EmptyStateView(
                symbol: "doc.questionmark",
                title: "editor.missing.title",
                message: "editor.missing.message",
                actions: [close]
            )
        case .failed:
            EmptyStateView(
                symbol: "exclamationmark.triangle",
                title: "editor.failed.title",
                message: "editor.failed.message",
                actions: [tryAgain, close]
            )
        case .open:
            VStack(spacing: 0) {
                StatusNotice(editor: editor, editorHeight: height, discard: discard)
                form
            }
            .onGeometryChange(for: Double.self) { Double($0.size.height) } action: { height = $0 }
        }
    }

    private var close: NoticeAction {
        NoticeAction("editor.action.close", actionIdentifier: "editor.close", perform: discard)
    }

    private var tryAgain: NoticeAction {
        NoticeAction("editor.action.retry", actionIdentifier: "editor.retryOpening") {
            Task { await editor.load() }
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
            .editRowsButton(canReorder: editor.reordersRows)
            .keyboardDoneBar("editor.done") {
                focus = nil
                rowFocus = nil
            }
            // A problem with a field's text is named once the person leaves it, never while they type
            .onChange(of: focus) { left, _ in
                if let left { editor.fieldWasLeft(left) }
            }
            // The same for a row's field; a period is left from either of its years
            .onChange(of: rowFocus) { left, now in
                if let left { editor.fieldWasLeft(left.field, row: left.row) }
                if now?.row != newRow { newRow = nil }
            }
            // The row itself takes the focus once it is on screen (EditorRowView)
            .onChange(of: editor.addedRow) { _, added in
                if let added {
                    newRow = added
                    withAnimation { proxy.scrollTo(added) }
                }
            }
            // The keyboard takes its room only after the focus lands in a new row, so a new row near the bottom (a new
            // skill goes last) would stay under it: once the room left for the form shrinks, that row comes into view.
            // A row the person taps is the system's to keep in view; a row taller than the room left would be scrolled
            // to its top, away from the field being typed in
            .onGeometryChange(for: CGFloat.self) { $0.size.height - $0.safeAreaInsets.bottom } action: { old, new in
                if new < old, let row = newRow, rowFocus?.row == row { withAnimation { proxy.scrollTo(row) } }
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
