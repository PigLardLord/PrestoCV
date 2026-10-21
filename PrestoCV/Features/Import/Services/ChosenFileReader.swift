import Foundation
import PrestoCVImporting

/// Reads a file the person chose in Files, or opened in the app from the share sheet, within a size checked before it
/// is read (R8). The system lets the app read that file only, while it reads it. Nothing of it is kept: the copy the
/// system makes for "Open in PrestoCV" is deleted once the import is done with it.
struct ChosenFileReader: ImportFileReading {
    let maximumBytes: Int
    let copies: OpenedFileCopies

    func read(_ url: URL) async throws -> Data {
        let isScoped = url.startAccessingSecurityScopedResource()
        defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
        if let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > maximumBytes {
            throw ImportError.tooLarge
        }
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard data.count <= maximumBytes else { throw ImportError.tooLarge }
        return data
    }

    /// Deletes the copy of a file opened in the app; a file chosen in Files is the person's, and stays.
    func release(_ url: URL) {
        copies.release(url)
    }
}
