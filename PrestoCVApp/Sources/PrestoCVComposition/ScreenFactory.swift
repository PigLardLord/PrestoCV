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
/// let go only when both have released it. The exporter, the export share's file port, the look options and the languages
/// are the composition's too: every look picker offers the same installed designs, every export sheet renders through the
/// one renderer, and every share writes its PDF under the one folder the launch cleared.
@MainActor
public final class ScreenFactory {
    private let browsing: BrowseCVsWorkflow
    private let editing: EditCVWorkflow
    /// What the list edits through: `editing`, or the wrapper the composition gives it.
    private let listEditing: any CVEditing
    private let importing: ImportCVWorkflow
    private let importFiles: any ImportFileReading
    private let exportFiles: any ExportFileSharing
    private let exporter: any CVExporting
    private let lookOptions: any LookOptionsProviding
    /// The languages a PDF can be written in
    private let languages: [ExportLanguage]
    /// Reads the language of the words of a CV that keeps none, for the export sheets (#407).
    private let languageDetector: any CVLanguageDetecting
    /// The language of the app: the PDF's in the shell's export sheets when a CV keeps no language and its words tell
    /// none.
    private let appLanguage: ExportLanguage
    private let clock: any TimeSource
    /// The clock the editors' autosave pause runs on.
    private let editorClock: any Clock<Duration>
    /// The time the system grants the shell to store its editors once the app leaves the foreground.
    private let backgroundTime: any BackgroundTime
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
    ///   - exportFiles: Writes and removes the PDFs the export sheets hand to a share.
    ///   - exporter: Renders a CV with the design it keeps, for the export sheets.
    ///   - lookOptions: The designs, palettes and fonts the look pickers offer.
    ///   - languages: The languages the export sheets offer.
    ///   - languageDetector: Reads the language of the words of a CV that keeps none, for the export sheets (#407).
    ///   - wrapListEditing: Gives the list's editing from the workflow: the composition gives it back as it is, and a UI test's
    ///     launch fixture wraps it.
    ///   - backgroundTime: The time the system grants the shell to store its editors once the app leaves the foreground.
    ///   - appLanguage: The language of the app: the PDF's in the shell's export sheets when a CV keeps no language and
    ///     its words tell none.
    init(
        repository: any CVRepository, samples: any SampleCVSource, ids: any IDGenerator, clock: any TimeSource,
        editorClock: any Clock<Duration>, importer: any CVTextImporting, importFiles: any ImportFileReading,
        exportFiles: any ExportFileSharing, exporter: any CVExporting, lookOptions: any LookOptionsProviding,
        languages: [ExportLanguage], languageDetector: any CVLanguageDetecting,
        wrapListEditing: (any CVEditing) -> any CVEditing, backgroundTime: any BackgroundTime,
        appLanguage: ExportLanguage
    ) {
        browsing = BrowseCVsWorkflow(repository: repository, samples: samples, ids: ids)
        editing = EditCVWorkflow(repository: repository, ids: ids)
        listEditing = wrapListEditing(editing)
        importing = ImportCVWorkflow(importer: importer, ids: ids)
        self.importFiles = importFiles
        self.exportFiles = exportFiles
        self.exporter = exporter
        self.lookOptions = lookOptions
        self.languages = languages
        self.languageDetector = languageDetector
        self.clock = clock
        self.editorClock = editorClock
        self.backgroundTime = backgroundTime
        self.appLanguage = appLanguage
    }

    /// The list of CVs.
    /// - Parameters:
    ///   - untitled: The view's words for a CV with no title (R13).
    ///   - numbered: How the view numbers a title that reads like another row's (R13).
    ///
    /// Before it reads the store, the list has every editor still alive store what it shows at its turn, once
    /// (`editorsStored`, through each editor's `saveWhatItShows()`). An edit made after an editor's turn, even while that
    /// editor's own write runs, is not waited for: the autosave stores it, and that write reloads the list (the shell's
    /// editors call the list's `load()` after each write they stored). The factory holds editors weakly, and the shell
    /// keeps an editor it lets go alive until its `saveNow()` ended, which stores every edit.
    public func makeCVList(
        untitled: String, numbered: @escaping @MainActor (String, Int) -> String
    ) -> CVListViewModel {
        let clock = clock
        return CVListViewModel(
            browsing: browsing, editing: listEditing, untitled: untitled, numbered: numbered, now: { clock.now() },
            editorsStored: { [weak self] in await self?.storeEditors() }
        )
    }

    /// The navigation of the shell: which CV is open, its editor, and which column a compact screen shows. Each editor it
    /// opens reloads `list` and `firstRun` after each write the store took, so that the list shows the CV as stored and
    /// the first CV stored ends a first run: leaving it shows the list, not the welcome. The shell keeps neither alive.
    /// Its export sheet exports the CV as the open editor shows it, and takes to that editor's CV, which stores it, a
    /// language or a look chosen in the sheet, or the language the words of a CV that keeps none were found written in
    /// (#407).
    /// - Parameters:
    ///   - copyTitle: The title of a copy of a CV with the given title, in the person's words (R13).
    ///   - fileNamePattern: The pattern of the PDF's title in a language, with "%@" where the name goes (R13).
    public func makeShell(
        list: CVListViewModel, firstRun: FirstRunViewModel, copyTitle: @escaping @MainActor (String) -> String,
        fileNamePattern: @escaping @Sendable (ExportLanguage) -> String
    ) -> ShellNavigationModel {
        ShellNavigationModel(makeEditor: { [weak list, weak firstRun] start in
            self.makeEditor(start: start, copyTitle: copyTitle, storeChanged: {
                Task {
                    await list?.load()
                    await firstRun?.load()
                }
            })
        }, makeExportSheet: { editor in
            self.makeExportSheet(
                for: editor, appLanguage: self.appLanguage, fileNamePattern: fileNamePattern,
                // Each task holds the editor until its change is queued, and takes its place in the editor's line as
                // it starts: tasks made one after the other on the main actor start in that order (SE-0431), so a pick
                // and a language found reach the CV in the order the sheet sent them
                onLanguageChosen: { [weak editor] language in
                    guard let editor else { return }
                    Task { await editor.setDocumentLanguage(language.tag) }
                },
                onLanguageFound: { [weak editor] language in
                    // Kept only if the CV still keeps none once the changes asked for before it have run (#407)
                    guard let editor else { return }
                    Task { await editor.keepFoundLanguage(language.tag) }
                },
                onLookChosen: { [weak editor] look, parts in
                    guard let editor else { return }
                    Task { await editor.changeLook(to: look, parts: parts) }
                }
            )
        }, backgroundTime: backgroundTime)
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
    ///   - storeChanged: Called when the store changed (a write the store took, or another save or a deletion the editor
    ///     found), so that the list reads the CVs again.
    public func makeEditor(
        start: EditorStart, copyTitle: @escaping @MainActor (String) -> String, storeChanged: @escaping @MainActor () -> Void
    ) -> EditorViewModel {
        let editor = EditorViewModel(
            start: start, editing: editing, clock: editorClock, pause: Autosave<CV>.pause, copyTitle: copyTitle,
            storeChanged: storeChanged
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
    ///   - appLanguage: The language of the app: the PDF's when the CV keeps no language and its words tell none.
    ///   - fileNamePattern: The pattern of the PDF's title in a language, with "%@" where the name goes (R13).
    ///   - onLanguageChosen: Takes a language chosen in the sheet to the CV.
    ///   - onLanguageFound: Keeps in a CV that keeps no language the one its words were found written in, once; never
    ///     over a language the CV keeps by then (#407).
    ///   - onLookChosen: Takes to the CV the parts of a look chosen in the sheet, over the installed designs (#407).
    public func makeExportSheet(
        for editor: EditorViewModel, appLanguage: ExportLanguage,
        fileNamePattern: @escaping @Sendable (ExportLanguage) -> String,
        onLanguageChosen: @escaping @MainActor (ExportLanguage) -> Void,
        onLanguageFound: @escaping @MainActor (ExportLanguage) -> Void,
        onLookChosen: @escaping @MainActor (EditorLook, Set<LookPart>) -> Void
    ) -> ExportSheetViewModel? {
        guard let loaded = editor.exportSnapshot() else { return nil }
        return ExportSheetViewModel(
            exporter: exporter, files: exportFiles,
            snapshot: { editor.exportSnapshot() ?? loaded },
            offeredLanguages: languages, appLanguage: appLanguage, fileNamePattern: fileNamePattern,
            onLanguageChosen: onLanguageChosen, languageDetector: languageDetector, onLanguageFound: onLanguageFound,
            lookOptions: lookOptions, look: editor.look, onLookChosen: onLookChosen,
            clock: editorClock, pause: Self.exportPause
        )
    }

    /// Stores every editor that is still alive once, in turn, so that the list reads the store after them. Each editor
    /// stores what it shows at its turn and waits for two writes at most (`saveWhatItShows()`, not the draining
    /// `saveNow()`), so an edit made while those writes run does not hold the list, nor does a `saveNow()` of that editor
    /// that runs meanwhile; an editor made while an earlier one is storing gets a turn as well. An editor already stored
    /// is not visited again, so an edit made after its turn is left to its autosave, whose write reloads the list
    /// (`storeChanged`): going round again while the person types would never end. An editor already released is not waited
    /// for: the shell keeps an editor it lets go alive until its `saveNow()` ended, and that stores every edit.
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
