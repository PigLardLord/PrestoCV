import Foundation

/// The copies the system makes of the files opened in the app ("Open in PrestoCV"). The app declares that it never opens
/// a file in place, so the system copies each file into the app's own container, into a folder of its own choosing that
/// differs between versions of iOS. Nothing of an opened file is kept: its copy is deleted once the import is done with it.
struct OpenedFileCopies: Sendable {
    /// The app's own container. Any file inside it is such a copy; a file chosen in Files lies outside it.
    let container: URL
    /// How a copy is deleted.
    let removeFile: @Sendable (URL) throws -> Void

    /// Deletes the copy, wherever the system put it in the container; a file outside it is the person's, and stays.
    func release(_ url: URL) {
        guard isInContainer(url) else { return }
        do {
            try removeFile(url)
        } catch {
            // The copy stays in the container, which only this app reads; the next copy of the same name replaces it
        }
    }

    /// Whether the file is inside the container, however the path to it is written: through a symbolic link, as `/var`
    /// is `/private/var` on a device, or with `..`.
    private func isInContainer(_ url: URL) -> Bool {
        guard url.isFileURL else { return false }
        let root = container.resolvedFileURL.pathComponents
        let path = url.resolvedFileURL.pathComponents
        return path.count > root.count && path.starts(with: root)
    }
}
