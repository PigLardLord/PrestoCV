import DiagnosticLogging
import Foundation
import PrestoCVImporting
import PrestoCVIntegration

/// The file system of the import on a device: Foundation's, plus the security-scoped access the system gives to a
/// file the person chose in Files, and the file's device and file number, which tell two names of one file apart better
/// than a path does. Only the composition makes it (R4).
struct DeviceImportFiles: ImportFileSystem {
    private let logger: any DiagnosticLogger

    init(logger: any DiagnosticLogger) {
        self.logger = logger
    }

    /// Symbolic links resolved (`/var` is `/private/var` on a device), then `.` and `..` removed.
    func resolve(_ url: URL) -> URL { url.resolvingSymlinksInPath().standardizedFileURL }

    /// The device and the file's number on it, as the file system keeps them: one for every name of a file, a hard link
    /// included, and the same at each reading. The resolved path where the system gives none.
    func identity(ofResolved url: URL) -> String {
        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        } catch {
            logger.notice(.importing, "import.file.identityFromPath", .error(error))
            return url.path
        }
        guard let device = attributes[.systemNumber] as? NSNumber, let file = attributes[.systemFileNumber] as? NSNumber else {
            logger.notice(.importing, "import.file.identityFromPath", .token("reason", "noFileNumber"))
            return url.path
        }
        return "\(device.uint64Value)/\(file.uint64Value)"
    }

    func startAccess(_ url: URL) -> Bool { url.startAccessingSecurityScopedResource() }

    func stopAccess(_ url: URL) { url.stopAccessingSecurityScopedResource() }

    func size(of url: URL) throws -> Int {
        guard let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize else { throw CocoaError(.fileReadUnknown) }
        return size
    }

    /// Read into memory, never mapped: a file changed or cut while mapped can crash the app.
    func read(_ url: URL) throws -> Data { try Data(contentsOf: url) }

    func remove(_ url: URL) throws { try FileManager.default.removeItem(at: url) }
}
