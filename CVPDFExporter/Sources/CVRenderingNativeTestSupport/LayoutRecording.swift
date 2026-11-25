#if canImport(WebKit) && canImport(PDFKit)   // Apple platforms only (R11)
import Foundation
import CVRenderingTestSupport

/// #558: where the native layout tests write the layouts they record. A developer sets `RECORD_LAYOUTS` to an absolute
/// folder; on the iOS simulator, through the test runner's environment (`TEST_RUNNER_RECORD_LAYOUTS` for `xcodebuild`).
/// The layout tests run only when it is set: comparing a print with a stored reference waits for #558's tolerance.
public enum LayoutRecording {
    /// The folder `RECORD_LAYOUTS` names, or nil when it is not set.
    public static var folder: URL? {
        guard let path = ProcessInfo.processInfo.environment[LayoutReference.recordingVariable], !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    /// Writes `reference` at its path inside `folder`, making its platform's folder when needed.
    public static func write(_ reference: LayoutReference, into folder: URL) throws {
        let file = folder.appendingPathComponent(reference.path)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(reference.json().utf8).write(to: file, options: .atomic)
    }
}

extension LayoutReference.Platform {
    /// The platform these tests run on.
    public static var running: Self {
        #if os(iOS)
        .ios
        #else
        .macos
        #endif
    }
}

extension OSVersion {
    /// The version of the system these tests run on: on a simulator, its runtime's iOS version.
    public static var running: OSVersion {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return OSVersion(major: version.majorVersion, minor: version.minorVersion)
    }
}
#endif
