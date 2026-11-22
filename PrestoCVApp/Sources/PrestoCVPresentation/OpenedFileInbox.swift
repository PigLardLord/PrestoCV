import Foundation
import PrestoCVWorkflowPorts

/// The PDFs opened in a window from another app, on their way to its shell (`ShellNavigationModel.receive(file:)`). A
/// file can arrive before the window's shell exists, while the store is still being opened: it waits, held by the file
/// adapter from its arrival, and the shell gets it once it is ready. The inbox lets it go only after the shell's
/// import, or the shell's question, holds it. One file waits at most: a newer one takes its place and the older is let
/// go, unless both are the same file. When the store cannot be opened, the file waiting is let go; one that arrives
/// while the failure shows waits for a try that opens it, and is let go if that try fails too. When the inbox itself
/// goes, the file waiting is let go.
///
/// Each window has its own, as it has its own shell. The file a window is handed is a copy (ADR 0027), so letting it go
/// removes it. A copy no window was left to let go (the app ended while it waited) goes at a later import that reads a
/// file (`ImportFileAdapter`).
@MainActor
public final class OpenedFileInbox {
    private let files: any ImportFileReading
    private var waiting: ReceivedFile?
    private var shell: ShellNavigationModel?

    /// - Parameter files: Holds the files waiting for a shell, and lets go those that never reach one.
    public init(files: any ImportFileReading) {
        self.files = files
    }

    isolated deinit {
        if let waiting { files.release(waiting) }
    }

    /// A file opened in the window: its shell imports it, or it waits for the shell.
    public func receive(_ url: URL) {
        if let shell {
            shell.receive(file: url)
            return
        }
        if let waiting, url.namesTheSameFile(as: waiting.url) { return }
        let older = waiting
        waiting = files.receive(url)
        if let older { files.release(older) }
    }

    /// The window's shell is ready: the file waiting goes to it, and every file opened from now on. The shell's import,
    /// or its question, holds the file before the inbox lets it go.
    public func shellReady(_ shell: ShellNavigationModel) {
        self.shell = shell
        guard let waiting else { return }
        self.waiting = nil
        shell.receive(file: waiting.url)
        files.release(waiting)
    }

    /// The store could not be opened: the file waiting is let go.
    public func compositionFailed() {
        guard let waiting else { return }
        self.waiting = nil
        files.release(waiting)
    }
}
