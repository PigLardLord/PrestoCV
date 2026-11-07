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

    /// After a conflict: the form takes the stored CV, and the person's unstored text goes.
    public func reload() async {
        await replace { [self] in
            guard let base, autosave?.isStored == true else { return }
            do throws(EditFailure) {
                let stored = try await editing.load(base.id)
                form = EditorContent(stored)
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
    /// that runs. Edits made meanwhile stay in the form, and go to the autosave once it ends; `saveNow()` waits for it.
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
