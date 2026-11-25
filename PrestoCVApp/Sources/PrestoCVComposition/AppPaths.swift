import Foundation

/// Where the new app keeps its files, decided here and nowhere else (R4, ADR 0008). The root is a folder of its own,
/// `PrestoCVNext`, under Application Support: never the legacy `PrestoCV/CVs`, whose flat `cv_<uuid>.json` files the
/// one-time importer reads (ADR 0022) and which the new store must not mix with.
struct AppPaths: Equatable, Sendable {
    enum Failure: Error, Equatable, Sendable { case storeUnavailable }

    /// The folder of everything the app keeps
    let root: URL
    /// The folder of what may be lost with the app: the copies of a trace and the PDFs of an export made to share
    let temporary: URL

    /// The CVs, one file each
    var store: URL { root.appendingPathComponent("Store", isDirectory: true) }
    /// The installed designs: their store makes its own folders inside, on the launch's first sync
    var designs: URL { root.appendingPathComponent("Designs", isDirectory: true) }
    /// The mark that the person asked not to see the report of the released app's import again (`LegacyReportMarker`)
    var legacyReportOff: URL { root.appendingPathComponent("LegacyReportOff", isDirectory: false) }
    /// The runs of the trace, made by its store on the first run the gate lets through
    var trace: URL { root.appendingPathComponent("Diagnostics", isDirectory: true) }
    /// The copies of a run made to share
    var traceShare: URL { temporary.appendingPathComponent("DiagnosticsShare", isDirectory: true) }
    /// The PDFs written for an export's share, each in a folder of its own; the next launch removes what is left
    var exportShare: URL { temporary.appendingPathComponent("ExportShare", isDirectory: true) }

    /// Makes the root and the store; making them again changes nothing.
    func create() throws(Failure) {
        do {
            try FileManager.default.createDirectory(at: store, withIntermediateDirectories: true)
        } catch {
            throw .storeUnavailable
        }
    }

    /// The paths of this device: the one place that asks the system for a folder.
    static func onDevice() -> AppPaths {
        AppPaths(
            root: URL.applicationSupportDirectory.appendingPathComponent("PrestoCVNext", isDirectory: true),
            temporary: FileManager.default.temporaryDirectory
        )
    }

    /// The store of the released app, which the launch imports from. It lies in the app's own container, so an app with
    /// another container, such as PrestoCVNext, finds none there and imports nothing.
    static func legacyStoreOnDevice() -> URL {
        URL.applicationSupportDirectory.appendingPathComponent("PrestoCV", isDirectory: true)
            .appendingPathComponent("CVs", isDirectory: true)
    }

    /// The folders where the system puts the copy of a file opened in the app: `<bundle id>-Inbox` in the temporary folder
    /// (iOS 26 and later), and `Inbox` in Documents (older systems). The import deletes a copy only when it lies directly in
    /// one of them. With no bundle id there is no temporary inbox to name, so only the one in Documents is given.
    static func importCopies(temporary: URL, documents: URL, bundleID: String?) -> [URL] {
        let older = documents.appendingPathComponent("Inbox", isDirectory: true)
        guard let bundleID, !bundleID.isEmpty else { return [older] }
        return [temporary.appendingPathComponent("\(bundleID)-Inbox", isDirectory: true), older]
    }

    /// The copy folders of this device. On macOS a file opened in the app is opened where it is, with no copy, so there is
    /// no copy folder: a person's own `~/Documents/Inbox` is never emptied.
    static func importCopiesOnDevice() -> [URL] {
        #if os(iOS)
        importCopies(
            temporary: FileManager.default.temporaryDirectory, documents: URL.documentsDirectory,
            bundleID: Bundle.main.bundleIdentifier
        )
        #else
        []
        #endif
    }
}
