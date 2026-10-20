import Foundation
import PrestoCVImporting

/// Reads a file the person chose in Files, or opened in the app from the share sheet, within a size checked before it
/// is read (R8). The system lets the app read that file only, while it reads it. Nothing of it is kept: the copy the
/// system leaves in the app's Inbox for "Open in PrestoCV" is deleted once read.
struct ChosenFileReader: Sendable {
    let maximumBytes: Int
    /// Where the system copies a file opened in the app: the Inbox of the app's documents.
    let inbox: URL

    func read(_ url: URL) async throws -> Data {
        let isScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isScoped { url.stopAccessingSecurityScopedResource() }
            if url.standardizedFileURL.path.hasPrefix(inbox.standardizedFileURL.path + "/") { removeCopy(at: url) }
        }
        if let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > maximumBytes {
            throw ImportError.tooLarge
        }
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard data.count <= maximumBytes else { throw ImportError.tooLarge }
        return data
    }

    private func removeCopy(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            // The copy stays in the Inbox, which only this app reads; the next copy of the same name replaces it
        }
    }
}
