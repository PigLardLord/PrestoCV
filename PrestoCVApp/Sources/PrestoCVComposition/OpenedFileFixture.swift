#if DEBUG
import Foundation
import PrestoCVPresentation

/// A PDF of the bundle a window is handed each time it becomes active, as if another app opened it there, so that a UI
/// test opens a file in the app with no other app (`-PrestoCVNextOpenedFile`). Only a Debug build has the type
/// (`ReleaseHygieneTests`). The file is the bundle's own, in no folder of copies, so letting it go leaves it in place.
public struct OpenedFileFixture: Sendable {
    let file: URL

    /// The window became active, or stopped being active: an active one is handed the file.
    @MainActor
    public func sceneChanged(isActive: Bool, inbox: OpenedFileInbox) {
        guard isActive else { return }
        inbox.receive(file)
    }
}
#endif
