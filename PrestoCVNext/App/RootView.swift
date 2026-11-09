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

/// The view models of the shell, made once. A state object takes its initial value as an autoclosure that SwiftUI runs
/// only when it keeps no object yet, so a pass over the body neither makes the models again nor reads the strings again.
@MainActor
private final class ShellModels: ObservableObject {
    let shell: ShellNavigationModel
    let list: CVListViewModel
    let firstRun: FirstRunViewModel

    init(screens: ScreenFactory) {
        shell = screens.makeShell()
        firstRun = screens.makeFirstRun()
        list = screens.makeCVList(
            untitled: String(localized: "shell.untitled"),
            // The order and the punctuation of a title and its number are the translation's
            numbered: { title, number in String(localized: "shell.numbered \(title) \(number)") }
        )
    }
}

/// The shell over the view models the composition's factory makes, once for as long as the shell is on screen (R4).
private struct ReadyShell: View {
    @StateObject private var models: ShellModels

    init(screens: ScreenFactory) {
        _models = StateObject(wrappedValue: ShellModels(screens: screens))
    }

    var body: some View {
        ShellView(shell: models.shell, list: models.list, firstRun: models.firstRun)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("root.ready")
    }
}
