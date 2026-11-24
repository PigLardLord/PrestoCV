import DiagnosticLogging
import Foundation
import PrestoCVWorkflowPorts

extension LogCategory {
    /// What the launch does about the files the released app left: their removal.
    public static let legacy = LogCategory("legacy")
}

/// Where the released app kept the files that hold nothing the person wrote, derived from Application Support by one rule.
/// The CVs, their `Quarantine` and the unsaved edits live beside them and are never named here.
public struct LegacyLeftoverPaths: Sendable, Equatable {
    /// The released app's design files: a folder
    public let templates: URL
    /// The cache of those designs: a folder directly under Application Support
    public let templateCache: URL
    /// The released app's export settings: a file
    public let exportPreferences: URL

    public init(applicationSupport: URL) {
        let app = applicationSupport.appendingPathComponent("PrestoCV", isDirectory: true)
        templates = app.appendingPathComponent("Templates", isDirectory: true)
        templateCache = applicationSupport.appendingPathComponent("TemplateCache", isDirectory: true)
        exportPreferences = app.appendingPathComponent("export-preferences.json", isDirectory: false)
    }
}

/// The kind of failure a removal gave, by a code; never a path.
struct LegacyLeftoverError: Error, Equatable, LoggableError {
    let logCode: StaticString

    init(_ error: any Error) {
        guard let cocoa = error as? CocoaError else {
            logCode = "other"
            return
        }
        switch cocoa.code {
        case .fileWriteNoPermission, .fileReadNoPermission: logCode = "noPermission"
        case .fileWriteVolumeReadOnly: logCode = "readOnly"
        case .fileNoSuchFile, .fileReadNoSuchFile: logCode = "notFound"
        default: logCode = "other"
        }
    }

    var isNotFound: Bool { logCode.description == "notFound" }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.logCode.description == rhs.logCode.description }
}

/// The adapter of `LegacyLeftoversCleaning`.
///
/// - It removes exactly three paths, the ones in `LegacyLeftoverPaths`, and nothing else: never a path it lists or derives.
/// - A path that is a link is removed as the link, never its target.
/// - A path that is not there counts as removed, so it runs again at each launch with no mark of its own.
/// - A removal that fails is logged by its kind (`templates`, `templateCache`, `exportPreferences`) and a code, never a
///   path, and the others still go.
public struct LegacyLeftoversAdapter: LegacyLeftoversCleaning {
    private let paths: LegacyLeftoverPaths
    private let logger: any DiagnosticLogger

    public init(paths: LegacyLeftoverPaths, logger: any DiagnosticLogger) {
        self.paths = paths
        self.logger = logger
    }

    @concurrent
    public func clean() async {
        delete(paths.templates, of: "templates")
        delete(paths.templateCache, of: "templateCache")
        delete(paths.exportPreferences, of: "exportPreferences")
    }

    /// Deletes a folder, a file or a link; one already gone counts as deleted.
    private func delete(_ url: URL, of kind: StaticString) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            let failure = LegacyLeftoverError(error)
            guard !failure.isNotFound else { return }
            logger.error(.legacy, "legacy.leftovers.notRemoved", .token("of", kind), .error(failure))
        }
    }
}
