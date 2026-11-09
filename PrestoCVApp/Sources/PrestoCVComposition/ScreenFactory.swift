import Foundation
import PrestoCVApplication
import PrestoCVDomain
import PrestoCVIntegration
import PrestoCVPresentation
import PrestoCVWorkflowPorts

/// Makes the view models of the screens over the composition's one repository, clock and id source (R4, R5). A view is
/// given its view model by this factory and never builds one. The methods do no I/O: each view model loads in its own
/// `load()`.
///
/// The workflows are stateless, so the factory makes one of each and every view model shares them. The file port of the
/// import is one too, shared by every import screen: it counts the files it received, so a file handed to two screens is
/// let go only when both have released it. The exporter, the look options and the languages are the composition's too:
/// every look picker offers the same installed designs, and every export sheet renders through the one renderer.
@MainActor
public final class ScreenFactory {
    private let browsing: BrowseCVsWorkflow
    private let editing: EditCVWorkflow
    private let importing: ImportCVWorkflow
    private let importFiles: any ImportFileReading
    private let exporter: any CVExporting
    private let lookOptions: any LookOptionsProviding
    /// The languages a PDF can be written in
    private let languages: [ExportLanguage]
    private let clock: any TimeSource
    /// The clock the editors' autosave pause runs on.
    private let editorClock: any Clock<Duration>
    /// The editors made and not yet released. The factory never keeps one alive.
    private var editors: [WeakEditor] = []
    /// How many editors the factory has made: each one is known by its number, which is never reused.
    private var made = 0

    /// - Parameters:
    ///   - clock: The time of day, for the list's dates.
    ///   - editorClock: The clock the editors' autosave pause runs on: the composition gives the real one, a test one it
    ///     moves by hand.
    ///   - importer: Reads a text or a PDF for the import.
    ///   - importFiles: Reads and lets go the files handed to the import screens.
    ///   - exporter: Renders a CV with the design it keeps, for the export sheets.
    ///   - lookOptions: The designs, palettes and fonts the look pickers offer.
    ///   - languages: The languages the export sheets offer.
    init(
        repository: any CVRepository, samples: any SampleCVSource, ids: any IDGenerator, clock: any TimeSource,
        editorClock: any Clock<Duration>, importer: any CVTextImporting, importFiles: any ImportFileReading,
        exporter: any CVExporting, lookOptions: any LookOptionsProviding, languages: [ExportLanguage]
    ) {
        browsing = BrowseCVsWorkflow(repository: repository, samples: samples, ids: ids)
        editing = EditCVWorkflow(repository: repository, ids: ids)
        importing = ImportCVWorkflow(importer: importer, ids: ids)
        self.importFiles = importFiles
        self.exporter = exporter
        self.lookOptions = lookOptions
        self.languages = languages
        self.clock = clock
        self.editorClock = editorClock
    }

    /// The list of CVs.
    /// - Parameters:
    ///   - untitled: The view's words for a CV with no title (R13).
    ///   - numbered: How the view numbers a title that reads like another row's (R13).
    ///
    /// Before it reads the store, the list has every editor still alive store what it shows at its turn, once
    /// (`editorsStored`, through each editor's `saveWhatItShows()`). An edit made after an editor's turn, even while that
    /// editor's own write runs, is not waited for: the autosave stores it, and the list shows it on its next load (step
    /// 5-11a reloads the list after each store, issue #402). The factory holds editors weakly, so whoever lets an editor go
    /// waits for its `saveNow()` first, which stores every edit (the shell's navigation, step 5-11a).
    public func makeCVList(
        untitled: String, numbered: @escaping @MainActor (String, Int) -> String
    ) -> CVListViewModel {
        let clock = clock
        return CVListViewModel(
            browsing: browsing, editing: editing, untitled: untitled, numbered: numbered, now: { clock.now() },
            editorsStored: { [weak self] in await self?.storeEditors() }
        )
    }

    /// The navigation of the shell: which CV is open, and which column a compact screen shows.
    public func makeShell() -> ShellNavigationModel {
        ShellNavigationModel()
    }

    /// The first run and the ways to start another CV. It does not offer the import while the app has no import screen
    /// (step 5-13 adds the screen and the choice), so that no choice leads nowhere.
    public func makeFirstRun() -> FirstRunViewModel {
        FirstRunViewModel(browsing: browsing, editing: editing, offersImport: false)
    }

    /// The import of a CV the person already has: a text, a pasted PDF or a PDF file.
    public func makeImport() -> ImportViewModel {
        ImportViewModel(importer: importing, files: importFiles)
    }

    /// An editor, stored by the autosave a pause after the last change (one second, as in version 1).
    /// - Parameters:
    ///   - start: What the editor opens.
    ///   - copyTitle: The title of a copy of a CV with the given title, in the person's words (R13).
    public func makeEditor(start: EditorStart, copyTitle: @escaping @MainActor (String) -> String) -> EditorViewModel {
        let editor = EditorViewModel(
            start: start, editing: editing, clock: editorClock, pause: Autosave<CV>.pause, copyTitle: copyTitle
        )
        made += 1
        editors = editors.filter { $0.editor != nil } + [WeakEditor(editor, number: made)]
        return editor
    }

    /// The look picker of a CV, over the installed designs.
    public func makeLook(for reference: CVReference) -> LookViewModel {
        LookViewModel(reference: reference, editing: editing, options: lookOptions)
    }

    /// The pause of the export sheet after the last change, as in version 1: several quick changes make one export.
    static let exportPause = Duration.milliseconds(250)

    /// The export sheet of a CV open in an editor, or nil while the editor has not loaded it. Each export reads the CV as
    /// the editor shows it then, so the sheet holds the editor while the sheet lives; the editor never holds the sheet.
    /// - Parameters:
    ///   - appLanguage: The language of the app, offered first when the CV holds none.
    ///   - fileNamePattern: The pattern of the PDF's title in a language, with "%@" where the name goes (R13).
    ///   - onLanguageChosen: Takes a language chosen in the sheet to the CV; nil is automatic.
    public func makeExportSheet(
        for editor: EditorViewModel, appLanguage: ExportLanguage,
        fileNamePattern: @escaping @Sendable (ExportLanguage) -> String,
        onLanguageChosen: @escaping @MainActor (ExportLanguage?) -> Void
    ) -> ExportSheetViewModel? {
        guard let loaded = editor.exportSnapshot() else { return nil }
        return ExportSheetViewModel(
            exporter: exporter,
            snapshot: { editor.exportSnapshot() ?? loaded },
            offeredLanguages: languages, appLanguage: appLanguage, fileNamePattern: fileNamePattern,
            onLanguageChosen: onLanguageChosen, clock: editorClock, pause: Self.exportPause
        )
    }

    /// Stores every editor that is still alive once, in turn, so that the list reads the store after them. Each editor
    /// stores what it shows at its turn and waits for two writes at most (`saveWhatItShows()`, not the draining
    /// `saveNow()`), so an edit made while those writes run does not hold the list, nor does a `saveNow()` of that editor
    /// that runs meanwhile; an editor made while an earlier one is storing gets a turn as well. An editor already stored
    /// is not visited again, so an edit made after its turn is left to its autosave and to the list's next load: going
    /// round again while the person types would never end. An editor already released is not waited for: whoever lets an
    /// editor go waits for its `saveNow()` first (the shell's navigation, step 5-11a).
    ///
    /// The editors already stored are told apart by their numbers, not by the identity of the object: an editor made
    /// after a stored one was freed may take its address, and would then be skipped.
    private func storeEditors() async {
        var stored = Set<Int>()
        while let next = editors.first(where: { $0.editor != nil && !stored.contains($0.number) }),
              let editor = next.editor {
            stored.insert(next.number)
            await editor.saveWhatItShows()
        }
    }
}

private struct WeakEditor {
    weak var editor: EditorViewModel?
    let number: Int

    init(_ editor: EditorViewModel, number: Int) {
        self.editor = editor
        self.number = number
    }
}
