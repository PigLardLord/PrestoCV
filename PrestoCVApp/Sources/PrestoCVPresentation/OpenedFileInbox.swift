import Foundation
import PrestoCVWorkflowPorts

/// The PDFs opened in a window from another app, on their way to its shell (`ShellNavigationModel.receive(file:)`). A
/// file can arrive before the window's shell exists, while the store is still being opened: it waits, and the shell
/// gets it once it is ready. One file waits at most: a newer one takes its place and the older is let go, unless both
/// are the same file. When the store cannot be opened, the file waiting is let go; one that arrives while the failure
/// shows waits for a try that opens it, and is let go if that try fails too.
///
/// Each window has its own, as it has its own shell. The file a window is handed is a copy (ADR 0027), so letting it go
/// removes it.
@MainActor
public final class OpenedFileInbox {
    private let files: any ImportFileReading
    private var waiting: URL?
    private var shell: ShellNavigationModel?

    /// - Parameter files: Lets go the files that never reach a shell.
    public init(files: any ImportFileReading) {
        self.files = files
    }

    /// A file opened in the window: its shell imports it, or it waits for the shell.
    public func receive(_ url: URL) {
        if let shell {
            shell.receive(file: url)
            return
        }
        if let waiting, !Self.isSame(waiting, url) { letGo(waiting) }
        waiting = url
    }

    /// The window's shell is ready: the file waiting goes to it, and every file opened from now on.
    public func shellReady(_ shell: ShellNavigationModel) {
        self.shell = shell
        guard let waiting else { return }
        self.waiting = nil
        shell.receive(file: waiting)
    }

    /// The store could not be opened: the file waiting is let go.
    public func compositionFailed() {
        guard let waiting else { return }
        self.waiting = nil
        letGo(waiting)
    }

    private func letGo(_ url: URL) {
        files.release(files.receive(url))
    }

    private static func isSame(_ one: URL, _ other: URL) -> Bool {
        one.resolvingSymlinksInPath().standardizedFileURL == other.resolvingSymlinksInPath().standardizedFileURL
    }
}
