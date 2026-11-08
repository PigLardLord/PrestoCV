import Foundation
import PrestoCVApplication
import PrestoCVDomain
import PrestoCVIntegration
import PrestoCVPresentation

/// Makes the view models of the screens over the composition's one repository, clock and id source (R4, R5). A view is
/// given its view model by this factory and never builds one. The methods do no I/O: each view model loads in its own
/// `load()`.
///
/// The two workflows are stateless, so the factory makes one of each and every view model shares them.
@MainActor
public final class ScreenFactory {
    private let browsing: BrowseCVsWorkflow
    private let editing: EditCVWorkflow
    private let clock: any TimeSource
    /// The editors made and not yet released. The factory never keeps one alive.
    private var editors: [WeakEditor] = []
    /// How many editors the factory has made: each one is known by its number, which is never reused.
    private var made = 0

    init(repository: any CVRepository, samples: any SampleCVSource, ids: any IDGenerator, clock: any TimeSource) {
        browsing = BrowseCVsWorkflow(repository: repository, samples: samples, ids: ids)
        editing = EditCVWorkflow(repository: repository, ids: ids)
        self.clock = clock
    }

    /// The list of CVs.
    /// - Parameters:
    ///   - untitled: The view's words for a CV with no title (R13).
    ///   - numbered: How the view numbers a title that reads like another row's (R13).
    ///
    /// Before it reads the store, the list waits for every editor still alive (`editorsStored`) to store what it shows.
    /// The factory holds editors weakly, so whoever lets an editor go waits for its `saveNow()` first (the shell's
    /// navigation, step 5-11a).
    public func makeCVList(
        untitled: String, numbered: @escaping @MainActor (String, Int) -> String
    ) -> CVListViewModel {
        let clock = clock
        return CVListViewModel(
            browsing: browsing, editing: editing, untitled: untitled, numbered: numbered, now: { clock.now() },
            editorsStored: { [weak self] in await self?.storeEditors() }
        )
    }

    /// The first run.
    public func makeFirstRun() -> FirstRunViewModel {
        FirstRunViewModel(browsing: browsing, editing: editing)
    }

    /// An editor, stored by the autosave a pause after the last change (one second, as in version 1).
    /// - Parameters:
    ///   - start: What the editor opens.
    ///   - copyTitle: The title of a copy of a CV with the given title, in the person's words (R13).
    public func makeEditor(start: EditorStart, copyTitle: @escaping @MainActor (String) -> String) -> EditorViewModel {
        let editor = EditorViewModel(
            start: start, editing: editing, clock: ContinuousClock(), pause: Autosave<CV>.pause, copyTitle: copyTitle
        )
        made += 1
        editors = editors.filter { $0.editor != nil } + [WeakEditor(editor, number: made)]
        return editor
    }

    /// Returns once every editor that is still alive has stored what it shows, so that the list reads the store after them.
    /// An editor made while an earlier one is storing is stored as well. An editor already released is not waited for:
    /// whoever lets an editor go waits for its `saveNow()` first (the shell's navigation, step 5-11a).
    ///
    /// The editors already stored are told apart by their numbers, not by the identity of the object: an editor made
    /// after a stored one was freed may take its address, and would then be skipped.
    private func storeEditors() async {
        var stored = Set<Int>()
        while let next = editors.first(where: { $0.editor != nil && !stored.contains($0.number) }),
              let editor = next.editor {
            stored.insert(next.number)
            await editor.saveNow()
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
