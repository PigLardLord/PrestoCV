internal import PrestoCVApplication
internal import PrestoCVDomain
import PrestoCVWorkflowPorts

extension EditorViewModel {

    /// Stores what is left at once, as when the editor is left or the app goes to the background. Returns once the store
    /// holds the form as it was when this was called, edits made meanwhile included, or once a write failed.
    public func saveNow() async {
        while let replacing { await replacing.value }
        guard let autosave else { return }
        do {
            try await autosave.flush()
        } catch {
            // A cancelled write is no failure: the content waits for the next write, and the status says so
            refreshSaveStatus()
        }
    }

    /// After a conflict: the form takes the stored CV, and the person's unstored text goes. In any other state it does
    /// nothing. It waits for the write the old autosave still runs before it reads the store, and the old autosave writes
    /// nothing once the stored CV is taken. If the person types while the store is read, the stored CV is not taken: the
    /// form keeps every character, the editor stays on its writer, and the conflict stays to be reloaded again or saved as
    /// a copy.
    public func reload() async {
        await replace { [self] in
            guard saveStatus == .conflict, let base, autosave?.isStored == true else { return }
            let typed = form
            do throws(EditFailure) {
                await writes.untilIdle()
                let stored = try await editing.load(base.id)
                // A write the old autosave started meanwhile ends first, so that none runs when the new writer is installed
                await writes.untilIdle()
                guard form == typed else { return }
                form = rowIDs.unique(EditorContent(stored, ids: &rowIDs))
                pendingRemoval = nil
                standOn(stored, unchangedFrom: stored, writer: editing.autosaveWriter(startingFrom: stored), isStored: true)
            } catch {
                failure = SaveStatus(error)
            }
        }
    }

    /// After a conflict or a deletion elsewhere: the form's text is stored as a new CV, and the editor goes on with it.
    public func saveAsCopy() async {
        await replace { [self] in
            guard let held else { return }
            let current = form.applied(to: held)
            do throws(EditFailure) {
                let copy = try await editing.duplicate(current, title: copyTitle(current.title))
                form.title = EditorContent(copy).title
                standOn(copy, unchangedFrom: copy, writer: editing.autosaveWriter(startingFrom: copy), isStored: true)
            } catch {
                failure = SaveStatus(error)
            }
        }
    }

    /// Runs `body`, which replaces the CV the form stands on or the look and the language it holds, after any replacement
    /// that runs. Edits made meanwhile stay in the form, and go to the autosave once it ends; `saveNow()` waits for it. A
    /// replacement that reads the store takes what it read only if the form is as it was when the replacement began.
    func replace(_ body: @escaping @MainActor () async -> Void) async {
        while let replacing { await replacing.value }
        let replacement = Task {
            await body()
            // Cleared before the task ends, so that whoever waits for it finds the way free
            replacing = nil
            passOnTheForm()
            refreshSaveStatus()
        }
        replacing = replacement
        refreshSaveStatus()
        await replacement.value
    }
}
