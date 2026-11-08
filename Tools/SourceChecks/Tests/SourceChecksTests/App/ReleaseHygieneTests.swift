import Foundation
import Testing

// MARK: - Release Hygiene Tests

/// What the Release build must not carry: output meant for a developer, and a privacy manifest that says less (or more)
/// than the code does. That the bundle carries no data nobody reads is checked by the app tests, on the bundle itself.
@Suite("Release Hygiene Tests")
struct ReleaseHygieneTests {

    // MARK: Source tree

    private static let root = Repository.root

    /// The package products the app links, with the sources of each: their code ships in the app.
    static let linkedProducts = [
        "PrestoCVCore": "PrestoCVCore/Sources/PrestoCVCore",
        "CVPDFExporter": "CVPDFExporter/Sources/CVPDFExporter",
        "CVGeneratorAI": "CVGeneratorAI/Sources/CVGeneratorAI",
        "PrestoCVDomain": "PrestoCVCore/Sources/PrestoCVDomain",
        "PrestoCVApplication": "PrestoCVCore/Sources/PrestoCVApplication",
        "PrestoCVImporting": "PrestoCVCore/Sources/PrestoCVImporting",
        "PrestoCVImportingPDFKit": "PrestoCVCore/Sources/PrestoCVImportingPDFKit",
        "DiagnosticLogging": "DiagnosticLogging/Sources/DiagnosticLogging",
        "DiagnosticLoggingOSLog": "DiagnosticLogging/Sources/DiagnosticLoggingOSLog",
        "DiagnosticTrace": "DiagnosticTrace/Sources/DiagnosticTrace",
        "DiagnosticTraceFiles": "DiagnosticTrace/Sources/DiagnosticTraceFiles",
        "DiagnosticTraceDistribution": "DiagnosticTrace/Sources/DiagnosticTraceDistribution",
        "PrestoCVComposition": "PrestoCVApp/Sources/PrestoCVComposition",
        "PrestoCVPresentation": "PrestoCVApp/Sources/PrestoCVPresentation",
    ]

    /// The sources whose code ships with the app: the shipped target, the second one that becomes it at the switch
    /// (docs/architecture/modules.md), and the products they link.
    static let shippedFolders = ["PrestoCV", "PrestoCVNext"] + linkedProducts.values.sorted()

    private struct Line {
        let file: String
        let number: Int
        let code: String
        /// Whether the line is only compiled into a Debug build
        let isDebugOnly: Bool
    }

    /// The code lines of the shipped sources, without comments and without the previews at the end of a file.
    private static func shippedLines() -> [Line] {
        var lines: [Line] = []
        for folder in shippedFolders {
            let url = root.appendingPathComponent(folder)
            guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil) else { continue }
            for case let file as URL in enumerator where file.pathExtension == "swift" {
                guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
                let path = String(file.path.dropFirst(root.path.count + 1))
                var conditions: [Bool] = []
                for (index, raw) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                    let trimmed = raw.trimmingCharacters(in: .whitespaces)
                    if trimmed.contains("PreviewProvider") || trimmed.hasPrefix("#Preview") { break }
                    if trimmed.hasPrefix("#if") {
                        conditions.append(trimmed == "#if DEBUG")
                    } else if trimmed.hasPrefix("#else") || trimmed.hasPrefix("#elseif") {
                        if !conditions.isEmpty { conditions[conditions.count - 1] = false }
                    } else if trimmed.hasPrefix("#endif") {
                        if !conditions.isEmpty { conditions.removeLast() }
                    }
                    let code = raw.components(separatedBy: "//").first ?? ""
                    lines.append(Line(file: path, number: index + 1, code: code, isDebugOnly: conditions.contains(true)))
                }
            }
        }
        return lines
    }

    @Test("The scans read the sources of every package product the app links")
    func scansCoverTheLinkedProducts() throws {
        let project = try String(
            contentsOf: Self.root.appendingPathComponent("PrestoCV.xcodeproj/project.xcproj"), encoding: .utf8
        )
        let member = try NSRegularExpression(pattern: #""product-name": "([^"]+)""#)
        let linked = member.matches(in: project, range: NSRange(project.startIndex..., in: project)).compactMap { match in
            Range(match.range(at: 1), in: project).map { String(project[$0]) }
        }

        #expect(Set(linked) == Set(Self.linkedProducts.keys), "Add the sources of a newly linked product to the scans")
    }

    // MARK: Debug output

    @Test("No code that Release builds run writes to the console with print, debugPrint, NSLog or dump")
    func releaseCodeDoesNotPrint() throws {
        let console = try NSRegularExpression(pattern: #"(?<![\w.])(print|debugPrint|NSLog|dump)\("#)

        let offenders = Self.shippedLines().filter { line in
            !line.isDebugOnly && console.firstMatch(in: line.code, range: NSRange(line.code.startIndex..., in: line.code)) != nil
        }

        #expect(offenders.isEmpty, "Console output outside #if DEBUG: \(offenders.map { "\($0.file):\($0.number)" })")
    }

    // MARK: Test hooks

    @Test("The launch argument that hands CV files to the app is read only by Debug builds")
    func theSeedOfTheUITestsIsReadOnlyInDebugBuilds() {
        let reads = Self.shippedLines().filter { $0.code.contains("PrestoCVUITestsSeed") || $0.code.contains("seedFiles(") }

        let offenders = reads.filter { !$0.isDebugOnly }

        #expect(!reads.isEmpty, "The scan no longer finds the code that reads the seed: update it with the code")
        #expect(offenders.isEmpty, "The seed of the UI tests outside #if DEBUG: \(offenders.map { "\($0.file):\($0.number)" })")
    }

    /// A Release build asks the store how it was installed, and nothing else turns its trace on (ADR 0032).
    @Test("The launch argument that gives the store's answer to the trace is read only by Debug builds")
    func theDistributionOfTheTraceIsGivenOnlyToDebugBuilds() {
        let reads = Self.shippedLines().filter {
            $0.code.contains("diagnosticsDistribution") || $0.code.contains("DiagnosticsDistributionOverride")
        }

        let offenders = reads.filter { !$0.isDebugOnly }

        #expect(!reads.isEmpty, "The scan no longer finds the code that reads the answer: update it with the code")
        #expect(offenders.isEmpty, "The answer of the UI tests outside #if DEBUG: \(offenders.map { "\($0.file):\($0.number)" })")
    }

    // MARK: Privacy manifest

    /// The categories of required-reason APIs (Apple's list), each with a pattern for the calls and keys that use them.
    private static let requiredReasonAPIs: [String: String] = [
        "NSPrivacyAccessedAPICategoryFileTimestamp":
            #"\b(creationDate|modificationDate|fileCreationDate|fileModificationDate|NSFileCreationDate|NSFileModificationDate)\b"#
            + #"|\b(creationDateKey|contentModificationDateKey|contentAccessDateKey)\b"#
            + #"|\b(stat|fstat|fstatat|lstat|getattrlist|fgetattrlist|getattrlistat|getattrlistbulk)\("#,
        "NSPrivacyAccessedAPICategorySystemBootTime": #"\b(systemUptime|mach_absolute_time)\b"#,
        "NSPrivacyAccessedAPICategoryDiskSpace":
            #"\b(volumeAvailableCapacity\w*|volumeTotalCapacityKey|systemFreeSize|systemSize)\b"#
            + #"|\b(statfs|statvfs|fstatfs|fstatvfs)\("#,
        "NSPrivacyAccessedAPICategoryUserDefaults": #"\b(UserDefaults|AppStorage)\b"#,
        "NSPrivacyAccessedAPICategoryActiveKeyboards": #"\bactiveInputModes\b"#,
    ]

    private func declaredCategories() throws -> Set<String> {
        let manifest = Self.root.appendingPathComponent("PrestoCV/PrivacyInfo.xcprivacy")
        let plist = try #require(PropertyListSerialization.propertyList(from: Data(contentsOf: manifest), format: nil) as? [String: Any])
        let types = try #require(plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        return Set(types.compactMap { $0["NSPrivacyAccessedAPIType"] as? String })
    }

    @Test("The privacy manifest declares the required-reason APIs the code uses, and no others")
    func privacyManifestMatchesTheCode() throws {
        let lines = Self.shippedLines()
        var used: Set<String> = []
        for (category, pattern) in Self.requiredReasonAPIs {
            let api = try NSRegularExpression(pattern: pattern)
            if lines.contains(where: { api.firstMatch(in: $0.code, range: NSRange($0.code.startIndex..., in: $0.code)) != nil }) {
                used.insert(category)
            }
        }

        let declared = try declaredCategories()

        #expect(declared == used, "Declared \(declared.sorted()), used by the code \(used.sorted())")
    }
}
