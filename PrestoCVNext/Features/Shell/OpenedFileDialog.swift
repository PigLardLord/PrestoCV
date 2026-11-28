import PrestoCVPresentation
import SwiftUI

/// The question the shell asks about a PDF opened in the app while the open CV's text cannot be stored as it is
/// (`ShellNavigationModel.question`): discard the edits the store does not have and import the PDF, or keep editing,
/// and the PDF is let go. It says why the text cannot be stored, in the words of the status line. The view forwards the
/// answer and decides nothing (R5); closing the question without an answer, as a tap beside it does on an iPhone, keeps
/// editing.
struct OpenedFileDialog: ViewModifier {
    let shell: ShellNavigationModel
    @Environment(\.locale) private var locale

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                Text("import.opened.title"), isPresented: isAsked, titleVisibility: .visible, presenting: shell.question
            ) { _ in
                Button("import.opened.discard", role: .destructive) { shell.discardAndImport() }
                    .accessibilityIdentifier("import.opened.discard")
                Button("import.opened.keepEditing") { shell.keepEditing() }
                    .accessibilityIdentifier("import.opened.keepEditing")
            } message: { question in
                Text(message(of: question))
            }
    }

    /// Whether the question shows. Closed without an answer, it keeps editing; an answer reaches the shell first, and
    /// the close that follows it then finds no question.
    private var isAsked: Binding<Bool> {
        Binding {
            shell.question != nil
        } set: { shown in
            if !shown { shell.keepEditing() }
        }
    }

    /// Why the text cannot be stored, in the status line's words in `locale`, and what importing does.
    private func message(of question: OpenedFileQuestion) -> LocalizedStringResource {
        switch question {
        case .keepEditingOrDiscard(let status):
            var words = status.words
            words.locale = locale
            let reason = String(localized: words)
            return "import.opened.message \(reason)"
        }
    }
}
