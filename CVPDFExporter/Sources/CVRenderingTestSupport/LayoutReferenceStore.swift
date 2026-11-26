import Foundation
import CVRendering

/// #558: the layout references stored in the repository, one folder per kind of device and OS version
/// (`iphone-27.0`, `ipad-27.0`, `mac-27.2`), and the comparison of a print with the reference it belongs to.
///
/// How to record references (they are reviewed and committed like code, and a new system version that moves text
/// fails the checks until they are recorded again):
/// - on a Mac: `RECORD_LAYOUTS=<absolute path of CVPDFExporter/Tests/LayoutReferences>
///   swift test --package-path CVPDFExporter --filter CVRenderingMacOSTests`;
/// - on the iPhone or iPad simulator: `TEST_RUNNER_RECORD_LAYOUTS=<the same path> xcodebuild test
///   -scheme CVPDFExporter-Package -destination 'platform=iOS Simulator,name=<device>' -only-testing:CVRenderingIOSTests`,
///   once on an iPhone and once on an iPad (the folders are told apart by the device).
/// With the variable set the layout tests write the references instead of comparing. The tests read the stored references
/// as a resource of their own bundle (`LayoutReferenceStore(folder:)` with the bundle's `LayoutReferences` folder, R16), so
/// a recording must be committed and the tests built again before they compare with it.
public struct LayoutReferenceStore: Sendable {
    public let folder: URL

    public init(folder: URL) { self.folder = folder }

    /// The references a test target copies into its bundle (`.copy("../LayoutReferences")`), inside the bundle's
    /// resource folder `resources` (R16).
    public init(resources: URL) {
        self.init(folder: resources.appendingPathComponent("LayoutReferences", isDirectory: true))
    }

    /// The names inside the folder, none when it does not exist. A folder that exists and cannot be read throws (R7): an
    /// empty answer would skip every comparison as if nothing were recorded.
    public func names() throws -> [String] {
        do {
            return try FileManager.default.contentsOfDirectory(atPath: folder.path)
        } catch let error as CocoaError where Self.isMissing(error) {
            return []
        }
    }

    /// Whether any kind of device has a recorded version.
    public func hasReferences() throws -> Bool {
        let names = try names()
        return DeviceKind.allCases.contains { LayoutReference.newestVersion($0, among: names) != nil }
    }

    /// Whether `error` says the file or folder does not exist, the one failure that means "not recorded".
    static func isMissing(_ error: CocoaError) -> Bool {
        error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile
    }

    /// Every reference in the `kind` folder of `version`, by design then document.
    public func references(_ kind: DeviceKind, _ version: OSVersion) throws -> [LayoutReference] {
        let directory = folder.appendingPathComponent(LayoutReference.folder(kind, version), isDirectory: true)
        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasSuffix(".json") }
            .sorted()
        return try files.map { try LayoutReference(json: try Data(contentsOf: directory.appendingPathComponent($0))) }
    }

    /// What a print's layout is, against the reference recorded for its kind and system version.
    public enum Verdict: Sendable, Equatable {
        /// No line moved by more than the tolerance.
        case matches
        /// There is nothing to compare with: the message says why and how to record it.
        case noReference(String)
        /// The reference of `kind` at `version` (the closest version at or below the running one) differs, by
        /// `differences`.
        case differs(kind: DeviceKind, version: OSVersion, path: String, differences: [LayoutDifference])
    }

    /// Compares `found` with the reference of its kind at its own system version, or at the closest lower version when
    /// that has none; the verdict names the reference's kind and version. Only a reference that does not exist is
    /// `.noReference`: one that cannot be read or decoded throws (R7), because it is recorded and broken.
    public func verdict(of found: LayoutReference, tolerance: Double = LayoutComparison.tolerance) throws -> Verdict {
        let names = try names()
        guard let version = LayoutReference.closestVersion(found.kind, atOrBelow: found.osVersion, among: names) else {
            return .noReference(LayoutReference.noReference(found.kind, atOrBelow: found.osVersion))
        }
        let file = LayoutReference.file(design: found.design, document: found.document)
        let path = "\(LayoutReference.folder(found.kind, version))/\(file)"
        let data: Data
        do {
            data = try Data(contentsOf: folder.appendingPathComponent(path))
        } catch let error as CocoaError where Self.isMissing(error) {
            return .noReference(LayoutReference.noReference(path: path, kind: found.kind, running: found.osVersion))
        }
        let reference = try LayoutReference(json: data)
        let differences = LayoutComparison.differences(found.layout, from: reference.layout, tolerance: tolerance)
        guard !differences.isEmpty else { return .matches }
        return .differs(kind: found.kind, version: version, path: path, differences: differences)
    }
}

extension LayoutReferenceStore.Verdict: CustomStringConvertible {
    /// The verdict as a failing test shows it: the reference's kind and version, then every difference.
    public var description: String {
        switch self {
        case .matches: "matches its layout reference"
        case .noReference(let message): message
        case .differs(let kind, let version, let path, let differences):
            "differs from the layout reference of \(kind.rawValue) \(version) (\(path)); if the text moved on purpose or a "
                + "system update moved it, record the layouts again and review them:\n"
                + differences.map { "  " + $0.description }.joined(separator: "\n")
        }
    }
}

/// #558: an iPhone, an iPad and a Mac print the same document with the same pages, lines and order, and no line further
/// apart than `tolerance`.
public enum LayoutParity {
    /// How far apart two kinds of device may place the same line, in points: the largest difference measured between
    /// iPhone, iPad and Mac was 2.4.
    public static let tolerance = 2.5

    /// The kinds that are compared with each other, every pair once.
    static let pairs: [(DeviceKind, DeviceKind)] = [(.iphone, .ipad), (.iphone, .mac), (.ipad, .mac)]

    /// What differs between the three kinds' `references` (the newest recorded of each): a kind with none, a document one
    /// has and another lacks, the page count, lines missing or extra or on another page, and positions beyond `tolerance`.
    /// Empty when nothing is recorded at all: there is nothing to compare yet.
    public static func differences(
        _ references: [DeviceKind: [LayoutReference]], tolerance: Double = tolerance
    ) -> [String] {
        guard references.values.contains(where: { !$0.isEmpty }) else { return [] }
        var out: [String] = []
        for kind in DeviceKind.allCases where (references[kind] ?? []).isEmpty {
            out.append("no layout reference of \(kind.rawValue) to compare with the others: "
                + "record it as LayoutReferenceStore describes")
        }
        for (first, second) in pairs {
            let ofFirst = references[first] ?? [], ofSecond = references[second] ?? []
            guard !ofFirst.isEmpty, !ofSecond.isEmpty else { continue }
            for reference in ofFirst {
                let name = "\(reference.design) \(reference.document.rawValue)"
                guard let other = ofSecond.first(where: { reference.isSamePrint(as: $0) }) else {
                    out.append("\(name) has a layout of \(first.rawValue) and none of \(second.rawValue)")
                    continue
                }
                let label = "\(first.rawValue) \(reference.osVersion) against \(second.rawValue) \(other.osVersion), \(name)"
                for difference in LayoutComparison.differences(other.layout, from: reference.layout, tolerance: tolerance) {
                    out.append("\(label): \(difference)")
                }
            }
            for other in ofSecond where !ofFirst.contains(where: { other.isSamePrint(as: $0) }) {
                let name = "\(other.design) \(other.document.rawValue)"
                out.append("\(name) has a layout of \(second.rawValue) and none of \(first.rawValue)")
            }
        }
        return out
    }

    /// The newest references of each kind in `store`.
    public static func newest(in store: LayoutReferenceStore) throws -> [DeviceKind: [LayoutReference]] {
        var references: [DeviceKind: [LayoutReference]] = [:]
        let names = try store.names()
        for kind in DeviceKind.allCases {
            if let version = LayoutReference.newestVersion(kind, among: names) {
                references[kind] = try store.references(kind, version)
            }
        }
        return references
    }
}

extension LayoutReference {
    /// Whether `other` records the same design and document, whatever the kind of device or system version.
    func isSamePrint(as other: LayoutReference) -> Bool {
        design == other.design && document == other.document
    }
}
