import PrestoCVPresentation
import SwiftUI

/// The alert that says why an import gave no draft, with one OK and nothing to cancel. The view words each reason the
/// import gives (R13).
struct ImportProblemAlert: ViewModifier {
    /// The problem to tell; none hides the alert.
    let problem: ImportProblem?
    /// What follows OK: the screen is ready for another try.
    let clear: () -> Void

    func body(content: Content) -> some View {
        content.alert(Text("import.error.title"), isPresented: shown, presenting: problem) { _ in
            // OK closes the alert, and the alert's closing clears the problem
            Button("import.error.ok") {}
        } message: { problem in
            Text(Self.message(problem))
        }
    }

    private var shown: Binding<Bool> {
        Binding(get: { problem != nil }, set: { shown in if !shown { clear() } })
    }

    private static func message(_ problem: ImportProblem) -> LocalizedStringResource {
        switch problem {
        case .empty: "import.error.empty"
        case .tooLarge: "import.error.tooLarge"
        case .tooManyPages: "import.error.tooManyPages"
        case .encrypted: "import.error.encrypted"
        case .unreadable: "import.error.unreadable"
        case .noText: "import.error.noText"
        case .fileNotRead: "import.error.fileNotRead"
        }
    }
}
