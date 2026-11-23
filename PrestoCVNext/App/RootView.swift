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
            #if DEBUG
            // A Debug build launched for the UI tests shares through a stand-in they can read
            ReadyShell(screens: composition.screens, settings: composition.settings)
                .environment(\.sharesWithStandIn, composition.sharesWithStandIn)
            #else
            ReadyShell(screens: composition.screens, settings: composition.settings)
            #endif
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
    let report: LegacyImportReportViewModel
    let settings: SettingsViewModel
    let licences: LicencesViewModel
    let diagnostics: DiagnosticsViewModel

    init(screens: ScreenFactory, settings factory: SettingsFactory) {
        settings = factory.makeSettings()
        licences = factory.makeLicences()
        diagnostics = factory.makeDiagnostics()
        firstRun = screens.makeFirstRun()
        let untitled = String(localized: "shell.untitled")
        // The order and the punctuation of a title and its number are the translation's
        let numbered: @MainActor (String, Int) -> String = { title, number in
            String(localized: "shell.numbered \(title) \(number)")
        }
        list = screens.makeCVList(untitled: untitled, numbered: numbered)
        // The report names the CVs as the list does
        report = screens.makeLegacyImportReport(untitled: untitled, numbered: numbered)
        // A copy is named as the list names one, in the language the app shows; a PDF's file in the language of its
        // document (R13)
        shell = screens.makeShell(
            list: list, firstRun: firstRun, copyTitle: { title in String(localized: "list.copy.title \(title)") },
            fileNamePattern: { language in ExportTitlePattern.pattern(in: language) }
        )
    }
}

/// The shell over the view models the composition's factory makes, once for as long as the shell is on screen (R4).
private struct ReadyShell: View {
    @StateObject private var models: ShellModels

    init(screens: ScreenFactory, settings: SettingsFactory) {
        _models = StateObject(wrappedValue: ShellModels(screens: screens, settings: settings))
    }

    var body: some View {
        ShellView(
            shell: models.shell, list: models.list, firstRun: models.firstRun, report: models.report,
            settings: models.settings, licences: models.licences, diagnostics: models.diagnostics
        )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("root.ready")
    }
}
