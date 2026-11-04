import Foundation

/// The saves of the editors that were left. An editor stores what it shows as it is left, and that save can still be
/// running when the list reads the store again or the same CV is opened: both wait here first, so that they read what the
/// editor stored and not what it replaced.
@MainActor
final class LeftEditorSaves {
    private var saves: [Int: Task<Void, Never>] = [:]
    private var begun = 0

    nonisolated init() {}

    /// Starts the save of an editor that was left.
    func begin(_ save: @escaping @MainActor () async -> Void) {
        begun += 1
        let number = begun
        saves[number] = Task { [self] in
            await save()
            saves[number] = nil
        }
    }

    /// Returns once every save begun so far has ended, whether it stored the edits or not.
    func allEnded() async {
        for save in Array(saves.values) {
            await save.value
        }
    }
}
