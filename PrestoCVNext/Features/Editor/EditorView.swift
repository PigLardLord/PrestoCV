import PrestoCVPresentation
import SwiftUI

/// The open CV: one form in the order the PDF shows it, stored by itself as the person types, with the line that says
/// where the text stands. It waits while the CV is read, and says so when it cannot be. VoiceOver is told when the
/// status changes.
struct EditorView: View {
    @Bindable var editor: EditorViewModel
    /// The CV's name as the list shows it, or "New CV" for a draft.
    let title: Text
    @FocusState private var focus: EditorField?

    var body: some View {
        content
            .navigationTitle(title)
            .inlineNavigationTitle()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("shell.detail.opened")
            .task { await editor.load() }
            .announce(editor.statusChange) { $0.words }
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
        Form {
            Section {
                title
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("shell.detail.title")
                SaveStatusLine(status: editor.saveStatus)
            }
            DetailsSection(editor: editor, focus: $focus)
        }
        .formStyle(.grouped)
        .readableScrollContent()
        .keyboardDoneBar("editor.done") { focus = nil }
        // A problem with a field's text is named once the person leaves it, never while they type
        .onChange(of: focus) { left, _ in
            if let left { editor.fieldWasLeft(left) }
        }
    }
}
