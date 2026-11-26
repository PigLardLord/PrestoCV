#if canImport(WebKit) && canImport(PDFKit)   // Apple platforms only (R11)
import Foundation
import CVRenderingTestSupport

/// #558: where the native layout tests write the layouts they record. A developer sets `RECORD_LAYOUTS` to an absolute
/// folder; on the iOS simulator, through the test runner's environment (`TEST_RUNNER_RECORD_LAYOUTS` for `xcodebuild`).
/// With it set the layout tests write the references instead of comparing them: `LayoutReferenceStore` has the commands.
public enum LayoutRecording {
    /// The folder `RECORD_LAYOUTS` names, or nil when it is not set.
    public static var folder: URL? {
        guard let path = ProcessInfo.processInfo.environment[LayoutReference.recordingVariable], !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    /// Writes `reference` at its path inside `folder`, making its kind's folder when needed.
    public static func write(_ reference: LayoutReference, into folder: URL) throws {
        let file = folder.appendingPathComponent(reference.path)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(reference.json().utf8).write(to: file, options: .atomic)
    }
}

extension DeviceKind {
    /// The kind of device these tests run on: a Mac, or an iPad or an iPhone (the simulator's model, or a device's).
    public static var running: DeviceKind {
        #if os(iOS)
        let model = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? machine
        return model.hasPrefix("iPad") ? .ipad : .iphone
        #else
        return .mac
        #endif
    }

    #if os(iOS)
    private static var machine: String {
        var name = utsname()
        _ = uname(&name)
        return withUnsafeBytes(of: &name.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
    }
    #endif
}

extension OSVersion {
    /// The version of the system these tests run on: on a simulator, its runtime's iOS version.
    public static var running: OSVersion {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return OSVersion(major: version.majorVersion, minor: version.minorVersion)
    }
}
#endif
