import Foundation

/// Where the new app keeps its files, decided here and nowhere else (R4, ADR 0008). The root is a folder of its own,
/// `PrestoCVNext`, under Application Support: never the legacy `PrestoCV/CVs`, whose flat `cv_<uuid>.json` files the
/// one-time importer reads (ADR 0022) and which the new store must not mix with.
struct AppPaths: Equatable, Sendable {
    enum Failure: Error, Equatable, Sendable { case storeUnavailable }

    /// The folder of everything the app keeps
    let root: URL
    /// The folder of what may be lost with the app: the copies of a trace made to share
    let temporary: URL

    /// The CVs, one file each
    var store: URL { root.appendingPathComponent("Store", isDirectory: true) }
    /// The runs of the trace, made by its store on the first run the gate lets through
    var trace: URL { root.appendingPathComponent("Diagnostics", isDirectory: true) }
    /// The copies of a run made to share
    var traceShare: URL { temporary.appendingPathComponent("DiagnosticsShare", isDirectory: true) }

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
}
