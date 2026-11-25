import Foundation
import CVRendering

/// #558: where one design's text landed in one document, as one platform and OS version printed it: the layout a later
/// print is compared with. It is written as JSON, one folder per platform and OS version, to be stored in the repository
/// (`checkoutFolder`), so a new recording is a reviewed change like code.
public struct LayoutReference: Sendable, Equatable {
    public enum Platform: String, Sendable, CaseIterable {
        case ios, macos
    }

    public var platform: Platform
    public var osVersion: OSVersion
    public var design: String
    public var document: LayoutDocument
    public var layout: PDFLayout

    public init(platform: Platform, osVersion: OSVersion, design: String, document: LayoutDocument, layout: PDFLayout) {
        self.platform = platform; self.osVersion = osVersion; self.design = design; self.document = document; self.layout = layout
    }

    /// The folder of the references of `platform` on `osVersion`, such as `ios-27.0`.
    public static func folder(_ platform: Platform, _ osVersion: OSVersion) -> String { "\(platform.rawValue)-\(osVersion)" }

    /// The file of `design` in `document`, inside its folder, such as `minimal-contract-fixture.json`.
    public static func file(design: String, document: LayoutDocument) -> String { "\(design)-\(document.rawValue).json" }

    /// The path of this reference inside the references' folder.
    public var path: String { "\(Self.folder(platform, osVersion))/\(Self.file(design: design, document: document))" }
}

/// A system version as a reference is filed under: its major and minor numbers, so a bug-fix release shares its
/// release's references.
public struct OSVersion: Sendable, Hashable, Comparable, CustomStringConvertible {
    public var major: Int, minor: Int

    public init(major: Int, minor: Int) { self.major = major; self.minor = minor }

    /// `27.2`, or nil when `text` is not two numbers joined by a dot.
    public init?(_ text: String) {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2, let major = Int(parts[0]), let minor = Int(parts[1]), major >= 0, minor >= 0 else { return nil }
        self.init(major: major, minor: minor)
    }

    public var description: String { "\(major).\(minor)" }

    public static func < (lhs: OSVersion, rhs: OSVersion) -> Bool { (lhs.major, lhs.minor) < (rhs.major, rhs.minor) }
}

// MARK: JSON

/// Why a reference's JSON could not be read.
public enum LayoutReferenceError: Error, Equatable {
    case unknownPlatform(String)
    case invalidOSVersion(String)
    case unknownDocument(String)
}

extension LayoutReference {
    /// The reference as JSON: its platform, OS version, design and document, then the pages and one line of text per
    /// line, every value in points rounded to 0.01. The text is the same on every platform, so a recording made on one
    /// Mac reads the same as one made on another, and a diff shows the lines that moved.
    public func json() -> String {
        var out = "{\n"
        out += "  \"platform\": \(Self.quoted(platform.rawValue)),\n"
        out += "  \"osVersion\": \(Self.quoted(osVersion.description)),\n"
        out += "  \"design\": \(Self.quoted(design)),\n"
        out += "  \"document\": \(Self.quoted(document.rawValue)),\n"
        out += "  \"pages\": [\n"
        out += layout.pages.map { page in
            "    {\"x\": \(Self.number(page.x)), \"y\": \(Self.number(page.y)), \"width\": \(Self.number(page.width)), "
                + "\"height\": \(Self.number(page.height))}"
        }.joined(separator: ",\n")
        out += layout.pages.isEmpty ? "  ],\n" : "\n  ],\n"
        out += "  \"lines\": [\n"
        out += layout.lines.map { line in
            "    {\"page\": \(line.pageIndex), \"text\": \(Self.quoted(line.text)), \"x\": \(Self.number(line.box.x)), "
                + "\"y\": \(Self.number(line.box.y)), \"width\": \(Self.number(line.box.width)), "
                + "\"height\": \(Self.number(line.box.height)), \"glyphHeight\": \(line.glyphHeight.map(Self.number) ?? "null")}"
        }.joined(separator: ",\n")
        out += layout.lines.isEmpty ? "  ]\n}\n" : "\n  ]\n}\n"
        return out
    }

    /// The reference that `json()` wrote.
    public init(json data: Data) throws {
        let stored = try JSONDecoder().decode(Stored.self, from: data)
        guard let platform = Platform(rawValue: stored.platform) else { throw LayoutReferenceError.unknownPlatform(stored.platform) }
        guard let version = OSVersion(stored.osVersion) else { throw LayoutReferenceError.invalidOSVersion(stored.osVersion) }
        guard let document = LayoutDocument(rawValue: stored.document) else { throw LayoutReferenceError.unknownDocument(stored.document) }
        let layout = PDFLayout(
            pages: stored.pages.map { PDFBox(x: $0.x, y: $0.y, width: $0.width, height: $0.height) },
            lines: stored.lines.map { PDFTextLine(pageIndex: $0.page, text: $0.text, box: PDFBox(x: $0.x, y: $0.y, width: $0.width, height: $0.height),
                                                  glyphHeight: $0.glyphHeight) })
        self.init(platform: platform, osVersion: version, design: stored.design, document: document, layout: layout)
    }

    /// The JSON's own shape, read with `JSONDecoder`.
    private struct Stored: Decodable {
        struct Page: Decodable { var x: Double, y: Double, width: Double, height: Double }
        struct Line: Decodable { var page: Int, text: String, x: Double, y: Double, width: Double, height: Double, glyphHeight: Double? }
        var platform: String, osVersion: String, design: String, document: String, pages: [Page], lines: [Line]
    }

    /// `value` rounded to 0.01 and written with two decimals, from whole hundredths, so no platform's formatting of a
    /// `Double` reaches the file.
    static func number(_ value: Double) -> String {
        let hundredths = Int((value * 100).rounded())
        let magnitude = hundredths.magnitude
        let cents = magnitude % 100
        return "\(hundredths < 0 ? "-" : "")\(magnitude / 100).\(cents < 10 ? "0" : "")\(cents)"
    }

    /// `text` as a JSON string: quotes, backslashes and control characters escaped, everything else as it is.
    static func quoted(_ text: String) -> String {
        var out = "\""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\t": out += "\\t"
            case "\r": out += "\\r"
            case _ where scalar.value < 0x20:
                let hex = String(scalar.value, radix: 16, uppercase: true)
                out += "\\u" + String(repeating: "0", count: 4 - hex.count) + hex
            default: out.unicodeScalars.append(scalar)
            }
        }
        return out + "\""
    }
}

// MARK: Which references a run reads

extension LayoutReference {
    /// The variable that makes the layout tests record instead of compare: the absolute path of `checkoutFolder`.
    public static let recordingVariable = "RECORD_LAYOUTS"
    /// The folder of the references in the repository, which the comparing checks of #558 will read.
    public static let checkoutFolder = "CVPDFExporter/Tests/LayoutReferences"

    /// The versions of `platform` that `folders` hold references of, oldest first; other names are ignored.
    public static func versions(_ platform: Platform, among folders: [String]) -> [OSVersion] {
        let prefix = "\(platform.rawValue)-"
        return folders.compactMap { $0.hasPrefix(prefix) ? OSVersion(String($0.dropFirst(prefix.count))) : nil }.sorted()
    }

    /// The version whose references a run of `platform` on `running` reads: its own, or the closest earlier one, since
    /// a version that prints like the one before it needs no folder of its own. Nil when every version is newer.
    public static func closestVersion(_ platform: Platform, atOrBelow running: OSVersion, among folders: [String]) -> OSVersion? {
        versions(platform, among: folders).last { $0 <= running }
    }

    /// The newest version of `platform` that `folders` hold references of.
    public static func newestVersion(_ platform: Platform, among folders: [String]) -> OSVersion? {
        versions(platform, among: folders).last
    }

    /// Why a run of `platform` on `running` has no reference folder to read, and how to record one.
    public static func noReference(_ platform: Platform, atOrBelow running: OSVersion) -> String {
        "no layout reference for \(platform.rawValue) \(running) or an earlier version: " + howToRecord(platform, running)
    }

    /// Why a run of `platform` on `running` has no reference at `path`, and how to record one.
    public static func noReference(path: String, platform: Platform, running: OSVersion) -> String {
        "no layout reference \(path): " + howToRecord(platform, running)
    }

    private static func howToRecord(_ platform: Platform, _ running: OSVersion) -> String {
        "record it by running the layout tests with \(recordingVariable) set to the absolute path of \(checkoutFolder) "
            + "(on the iOS simulator, TEST_RUNNER_\(recordingVariable) for xcodebuild), then review and commit the folder "
            + folder(platform, running)
    }
}
