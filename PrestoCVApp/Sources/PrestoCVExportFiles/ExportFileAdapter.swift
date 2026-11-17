import DiagnosticLogging
import Foundation
import PrestoCVWorkflowPorts
import Synchronization

/// The adapter of `ExportFileSharing` (step 5-12b).
///
/// - Each share's file is written in a folder of its own, `<root>/<UUID>/<file name>`, with an atomic write: the share
///   sheet never reads half a file, and two shares of one PDF never read or remove each other's file.
/// - `remove` deletes that folder with the file in it. The folder of an unknown or already removed file is not looked
///   for: a second remove does nothing.
/// - Making the adapter removes whatever is left under `root`: the folders of shares an earlier launch could not remove,
///   or did not live to remove. The composition makes it once, at launch, and no write can start before it is made, so
///   nothing of this launch is there yet.
/// - `root` lies in the system's temporary folder, which no backup reads, so no file of a share is ever backed up.
/// - On iOS the file, which holds the person's whole CV, is written with complete protection unless open: once the
///   device locks, no one can open it, while a service of the share sheet that has it open already (AirDrop, Mail) can
///   finish reading it. A Mac does not apply the protection, and a locked keybag would refuse the write there, as for
///   the trace store, so a Mac writes it with none.
/// - The log names a kind of failure only: never the file's name, which holds the person's name, nor its path.
public final class ExportFileAdapter: ExportFileSharing {
    private struct State {
        var nextID = 1
        var folders: [Int: URL] = [:]
    }

    /// The longest file name, in UTF-8 bytes, that a file system takes for one path component.
    private static let maximumNameBytes = 255

    /// Atomic, and on iOS with complete protection unless open (see the notes above).
    static var writingOptions: Data.WritingOptions {
        #if os(iOS)
        [.atomic, .completeFileProtectionUnlessOpen]
        #else
        [.atomic]
        #endif
    }

    private let root: URL
    private let logger: any DiagnosticLogger
    private let state = Mutex(State())

    /// Removes what an earlier launch left under `root`.
    ///
    /// - Parameter root: the folder that holds the folders of the shares; the adapter makes it, and nothing else may
    ///   write there, as making the adapter removes all it holds.
    public init(root: URL, logger: any DiagnosticLogger) {
        self.root = root
        self.logger = logger
        removeLeftovers()
    }

    public func write(_ pdf: Data, named fileName: String) async throws -> SharedFile {
        guard Self.isOneName(fileName) else {
            logger.error(.export, "export.share.notWritten", .error(ExportFileError.notAName))
            throw ExportFileError.notAName
        }
        let id = state.withLock { state -> Int in
            defer { state.nextID += 1 }
            return state.nextID
        }
        let folder = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        var made = false
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            made = true
            let url = folder.appendingPathComponent(fileName, isDirectory: false)
            try pdf.write(to: url, options: Self.writingOptions)
            state.withLock { $0.folders[id] = folder }
            return SharedFile(id: id, url: url)
        } catch {
            let failure = ExportFileError(error)
            logger.error(.export, "export.share.notWritten", .error(failure))
            // A folder that was never made is not looked for: under a root that is not a folder, the search fails too
            if made { delete(folder, of: "share") }
            throw failure
        }
    }

    public func remove(_ file: SharedFile) {
        guard let folder = state.withLock({ $0.folders.removeValue(forKey: file.id) }) else { return }
        delete(folder, of: "share")
    }

    // MARK: - Removing

    /// Every folder and file under `root`: none belongs to this launch, as no write has started. A missing `root` holds
    /// nothing.
    private func removeLeftovers() {
        let leftovers: [URL]
        do {
            leftovers = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        } catch {
            let failure = ExportFileError(error)
            if failure != .system(.notFound) {
                logger.error(.export, "export.share.notRemoved", .token("of", "leftover"), .error(failure))
            }
            return
        }
        for leftover in leftovers {
            delete(leftover, of: "leftover")
        }
    }

    /// Deletes a folder or file; one already gone counts as deleted.
    private func delete(_ url: URL, of kind: StaticString) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            let failure = ExportFileError(error)
            guard failure != .system(.notFound) else { return }
            logger.error(.export, "export.share.notRemoved", .token("of", kind), .error(failure))
        }
    }

    // MARK: - Names

    /// One file name, never a path: not empty, not `.` or `..`, without a slash or a null character, and short enough
    /// for one path component. `PDFFileName` keeps the names it makes far shorter.
    private static func isOneName(_ name: String) -> Bool {
        !name.isEmpty && name != "." && name != ".." && !name.contains("/") && !name.contains("\0")
            && name.utf8.count <= maximumNameBytes
    }
}
