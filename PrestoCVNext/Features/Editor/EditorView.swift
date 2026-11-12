import PrestoCVPresentation
import SwiftUI

/// The open CV: one form in the order the PDF shows it, stored by itself as the person types, with the line that says
/// where the text stands. While the text cannot be stored as it is, a notice above the form says what to do and offers
/// the ways out (#402, decision 8). It waits while the CV is read, and says so when it cannot be, with a way to close
/// it. When the status changes, VoiceOver hears where the text stands and, while the person cannot leave, what to do and
/// the ways on (`SaveStatus.spoken(in:)`). A row the person adds comes into view, and its first field takes the focus.
struct EditorView: View {
    @Bindable var editor: EditorViewModel
    /// The CV's name as the list shows it, or "New CV" for a draft.
    let title: Text
    /// Closes the editor without storing its text.
    let discard: () -> Void
    @FocusState private var focus: EditorField?
    @FocusState private var rowFocus: RowFocus?
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
            .announce(editor.statusChange) { $0.spoken(in: locale) }
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
            .keyboardDoneBar("editor.done") {
                focus = nil
                rowFocus = nil
            }
            // A problem with a field's text is named once the person leaves it, never while they type
            .onChange(of: focus) { left, _ in
                if let left { editor.fieldWasLeft(left) }
            }
            // The row itself takes the focus once it is on screen (EditorRowView)
            .onChange(of: editor.addedRow) { _, added in
                if let added { withAnimation { proxy.scrollTo(added) } }
            }
        }
    }
}
