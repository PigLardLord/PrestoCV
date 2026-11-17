import DiagnosticLogging
import Foundation

// MARK: - What the share of an export logs (ADR 0030)

extension LogCategory {
    /// The share of an export's PDF: the file written for the share sheet, and its removal.
    public static let export = LogCategory("export")
}

/// Why the file of a share could not be written or removed. It names a kind of failure, never a path or a file name.
public enum ExportFileError: Error, Equatable, Sendable {
    /// The kind of failure the file system gave.
    public enum Reason: Equatable, Sendable {
        case noSpace, noPermission, readOnly, notFound, other
    }

    /// The name given is not one file name: empty, `.` or `..`, with a slash or a null character, or longer than a file
    /// system takes.
    case notAName
    /// The file system refused.
    case system(Reason)

    /// The failure of a file system call, by the kind of failure; one this type already is stays as it is.
    public init(_ error: any Error) {
        if let failure = error as? ExportFileError {
            self = failure
            return
        }
        guard let cocoa = error as? CocoaError else {
            self = .system(.other)
            return
        }
        switch cocoa.code {
        case .fileWriteOutOfSpace: self = .system(.noSpace)
        case .fileWriteNoPermission, .fileReadNoPermission: self = .system(.noPermission)
        case .fileWriteVolumeReadOnly: self = .system(.readOnly)
        case .fileNoSuchFile, .fileReadNoSuchFile: self = .system(.notFound)
        default: self = .system(.other)
        }
    }
}

extension ExportFileError: LoggableError {
    public var logCode: StaticString {
        switch self {
        case .notAName: "notAName"
        case .system(.noSpace): "noSpace"
        case .system(.noPermission): "noPermission"
        case .system(.readOnly): "readOnly"
        case .system(.notFound): "notFound"
        case .system(.other): "other"
        }
    }
}
