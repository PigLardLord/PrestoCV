import PrestoCVComposition
import PrestoCVPresentation
import SwiftUI

/// The first screen: it shows what the holder's composition has reached. While the composition is launching it shows the
/// loading state, when it failed the error screen with a retry, and when it is ready the shell. The identifiers name the
/// states for the UI tests.
struct RootView: View {
    /// The app's one composition holder, made once for the whole process
    let holder: CompositionHolder

    var body: some View {
        content
            .task { holder.start() }
    }

    @ViewBuilder
    private var content: some View {
        switch holder.phase {
        case .launching:
            LoadingView("root.loading")
                .accessibilityIdentifier("root.loading")
        case .ready(let composition):
            ReadyShell(screens: composition.screens)
        case .failed(let failure):
            CompositionFailedView(failure: failure, retry: holder.retry)
        }
    }
}

/// The shell over the view models the composition's factory makes, once for as long as the shell is on screen (R4).
private struct ReadyShell: View {
    @State private var shell: ShellNavigationModel
    @State private var list: CVListViewModel

    init(screens: ScreenFactory) {
        _shell = State(initialValue: screens.makeShell())
        _list = State(initialValue: screens.makeCVList(
            untitled: String(localized: "shell.untitled"), numbered: { title, number in "\(title) (\(number))" }
        ))
    }

    var body: some View {
        ShellView(shell: shell, list: list)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("root.ready")
    }
}
