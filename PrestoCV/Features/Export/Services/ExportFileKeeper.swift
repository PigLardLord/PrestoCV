import Foundation

/// Removes the temp PDFs of an export sheet, and never one that a share sheet may still be reading: a file that is let go
/// while a share is open on it stays until that share ends.
///
/// The share sheet says when it is done with the file, not the export sheet, and it can outlive the export sheet and its
/// view model. The view model and every share hold the keeper, so whoever lets go last removes what is left.
@MainActor
final class ExportFileKeeper {
    private let service: any CVExportServiceProtocol
    /// How many shares are open on each file
    private var openShares: [URL: Int] = [:]
    /// The files that were let go while a share was open on them: they go when the last of those shares ends
    private var waiting: Set<URL> = []

    init(service: any CVExportServiceProtocol) {
        self.service = service
    }

    /// A share sheet is open, or about to open, on `url`
    func shareBegan(on url: URL) {
        openShares[url, default: 0] += 1
    }

    /// A share sheet that was open on `url` has closed
    /// - Returns: The task that removes the file when it was only waiting for this share, for a caller that wants to
    ///   wait for it
    @discardableResult
    func shareEnded(on url: URL) -> Task<Void, Never> {
        guard let count = openShares[url] else { return Task {} }
        guard count == 1 else {
            openShares[url] = count - 1
            return Task {}
        }
        openShares[url] = nil
        return waiting.remove(url) == nil ? Task {} : removal(of: url)
    }

    /// The file is not needed any more: it is removed now, or when the share that is open on it ends
    /// - Returns: The task that removes the file, for a caller that wants to wait for it
    @discardableResult
    func letGo(of url: URL) -> Task<Void, Never> {
        guard openShares[url] == nil else {
            waiting.insert(url)
            return Task {}
        }
        return removal(of: url)
    }

    /// The service, not the caller, removes the file: the sheet and its view model may be gone before the task runs
    private func removal(of url: URL) -> Task<Void, Never> {
        let service = service
        return Task {
            await service.cleanupTempFile(at: url)
        }
    }
}
