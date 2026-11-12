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

    /// The targets that ship only as a dependency of a linked product and that the scans read: the composition's, which
    /// the second app target takes in through `PrestoCVComposition`. The project file does not name them, so
    /// `scansCoverTheLinkedProducts` cannot see them; `scansCoverTheComposition` reads them from the package's manifest.
    static let transitiveProducts = [
        "PrestoCVExportFiles": "PrestoCVApp/Sources/PrestoCVExportFiles",
        "PrestoCVApplicationNaturalLanguage": "PrestoCVCore/Sources/PrestoCVApplicationNaturalLanguage",
    ]

    /// The composition's other targets, which the scans do not read yet (#430): they are scanned when the scans follow
    /// the package manifests and each app has its own privacy manifest. This list may only shrink.
    static let notYetScanned: Set<String> = [
        "CVBundledDesigns", "CVDesignCatalog", "CVDesignCatalogFileStore", "CVDocumentModel", "CVRendering",
        "CVRenderingIOS", "CVRenderingWebKitSupport", "PrestoCVImportFiles", "PrestoCVIntegration", "PrestoCVPersistence",
        "PrestoCVWorkflowPorts",
    ]

    /// The sources whose code ships with the app: the shipped target, the second one that becomes it at the switch
    /// (docs/architecture/modules.md), the products they link, and those products' targets in `transitiveProducts`.
    static let shippedFolders = ["PrestoCV", "PrestoCVNext"]
        + linkedProducts.merging(transitiveProducts) { linked, _ in linked }.values.sorted()

    struct Line {
        let file: String
        let number: Int
        let code: String
        /// Whether the line is only compiled into a Debug build
        let isDebugOnly: Bool
    }

    /// The code lines of the shipped sources, without comments and without the previews at the end of a file.
    static func shippedLines() -> [Line] {
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

    @Test("The scans read the sources of every target and product the composition takes in")
    func scansCoverTheComposition() throws {
        let manifest = try String(
            contentsOf: Self.root.appendingPathComponent("PrestoCVApp/Package.swift"), encoding: .utf8
        )
        let start = try #require(manifest.range(of: #".target(name: "PrestoCVComposition", dependencies: ["#))
        let end = try #require(manifest.range(of: "]))", range: start.upperBound..<manifest.endIndex))
        let block = String(manifest[start.upperBound..<end.lowerBound])
        let name = try NSRegularExpression(pattern: #"(?:^|[\s,\[])"([A-Za-z]+)"|\.product\(name: "([A-Za-z]+)""#)
        let taken = name.matches(in: block, range: NSRange(block.startIndex..., in: block)).compactMap { match in
            (Range(match.range(at: 1), in: block) ?? Range(match.range(at: 2), in: block)).map { String(block[$0]) }
        }
        let scanned = Set(Self.linkedProducts.keys).union(Self.transitiveProducts.keys)
        let unread = Set(taken).subtracting(scanned).subtracting(Self.notYetScanned)

        #expect(taken.count > 20, "The scan no longer reads the composition's dependencies: update it with the manifest")
        #expect(unread.isEmpty, "Add the sources of \(unread.sorted()) to the scans")
        #expect(Self.notYetScanned.isDisjoint(with: scanned), "A target the scans read is still listed as not scanned")
        #expect(Self.notYetScanned.subtracting(taken).isEmpty, "Take \(Self.notYetScanned.subtracting(taken).sorted()) off the list")
    }

    @Test("Every folder the scans read is there")
    func scannedFoldersExist() {
        let missing = Self.shippedFolders.filter { folder in
            var isFolder: ObjCBool = false
            return !FileManager.default.fileExists(atPath: Self.root.appendingPathComponent(folder).path, isDirectory: &isFolder)
                || !isFolder.boolValue
        }

        #expect(missing.isEmpty, "The scans read no folder at \(missing)")
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

    /// The new app's fixtures (storage, seed, answer of the store) are launch arguments of the UI tests.
    @Test("The launch arguments of the new app's fixtures are read only by Debug builds")
    func theFixturesOfTheNewAppAreReadOnlyInDebugBuilds() {
        let reads = Self.shippedLines().filter { $0.code.contains("\"-PrestoCVNext") }

        let offenders = reads.filter { !$0.isDebugOnly }

        #expect(!reads.isEmpty, "The scan no longer finds the code that reads the fixtures: update it with the code")
        #expect(offenders.isEmpty, "The fixtures of the new app outside #if DEBUG: \(offenders.map { "\($0.file):\($0.number)" })")
    }

    /// A UI test takes the examples away to see the first run without them; a Release build always reads the bundle's.
    @Test("The fixture that takes the examples away is read only by Debug builds")
    func theFixtureWithoutExamplesIsReadOnlyInDebugBuilds() {
        let reads = Self.shippedLines().filter { $0.code.contains("withoutSamples") || $0.code.contains("samples(bundled:") }

        let offenders = reads.filter { !$0.isDebugOnly }

        #expect(!reads.isEmpty, "The scan no longer finds the code that reads the fixture: update it with the code")
        #expect(offenders.isEmpty, "The fixture without examples outside #if DEBUG: \(offenders.map { "\($0.file):\($0.number)" })")
    }

    /// A UI test makes two renames fail together to see two row notices at once; no Release build may be able to.
    @Test("The fixture that fails the list's renames two at a time is read only by Debug builds")
    func theFixtureThatFailsRenamesIsReadOnlyInDebugBuilds() {
        let names = ["failRenamesInPairsArgument", "failsRenamesInPairs", "PairedRenameFailures", "fixtures.listEditing"]
        let reads = Self.shippedLines().filter { line in names.contains { line.code.contains($0) } }

        let offenders = reads.filter { !$0.isDebugOnly }

        #expect(!reads.isEmpty, "The scan no longer finds the code that reads the fixture: update it with the code")
        #expect(offenders.isEmpty, "The fixture that fails renames outside #if DEBUG: \(offenders.map { "\($0.file):\($0.number)" })")
    }

    /// A UI test reads a share through a stand-in, as the system's share sheet runs in another process. A Release build
    /// carries the composition's flag, always false, and has no code that sets it, passes it on or shows the stand-in.
    @Test("The stand-in of the share sheet is set, passed on and shown only by Debug builds")
    func theShareStandInIsReachedOnlyInDebugBuilds() {
        let names = [
            "shareStandInArgument", "fixtures.sharesWithStandIn", "composition.sharesWithStandIn", "\\.sharesWithStandIn",
            "ShareStandIn",
        ]
        let reads = Self.shippedLines().filter { line in names.contains { line.code.contains($0) } }

        let offenders = reads.filter { !$0.isDebugOnly }

        #expect(!reads.isEmpty, "The scan no longer finds the code that reaches the stand-in: update it with the code")
        #expect(offenders.isEmpty, "The stand-in of the share sheet outside #if DEBUG: \(offenders.map { "\($0.file):\($0.number)" })")
    }

    /// The composition's flag reaches a Release build, which must only declare it, set it to false and hand it on as it
    /// is: a Release line that sets it from anything else would let a Release build reach the stand-in.
    @Test("A Release build sets the stand-in's flag only to false, and hands it on unchanged")
    func aReleaseBuildSetsTheStandInFlagOnlyToFalse() throws {
        let allowed = try NSRegularExpression(
            pattern: #"^(?:(?:public |@Entry )?(?:let|var) )?sharesWithStandIn(?:: Bool)?"#
                + #"(?:\s*[=:]\s*(?:false|(?:inputs\.)?sharesWithStandIn))?,?$"#
        )
        let release = Self.shippedLines().filter { !$0.isDebugOnly && $0.code.contains("sharesWithStandIn") }
        let code = release.map { $0.code.trimmingCharacters(in: .whitespaces) }

        let offenders = release.filter { line in
            let code = line.code.trimmingCharacters(in: .whitespaces)
            return allowed.firstMatch(in: code, range: NSRange(code.startIndex..., in: code)) == nil
        }

        #expect(code.contains("sharesWithStandIn = false"), "The scan no longer finds where a Release build sets the flag")
        #expect(offenders.isEmpty, "The stand-in's flag set in a Release build: \(offenders.map { "\($0.file):\($0.number)" })")
    }

    /// Where the new app keeps its data is decided in one place, so a second folder cannot appear unnoticed.
    @Test("Only AppPaths asks the system for a folder in the composition")
    func onlyAppPathsAsksForFolders() throws {
        let ask = try NSRegularExpression(pattern: #"applicationSupportDirectory|temporaryDirectory|NSHomeDirectory|urls\(for:|documentDirectory"#)
        let lines = Self.shippedLines().filter { $0.file.hasPrefix("PrestoCVApp/Sources/PrestoCVComposition/") }

        let asking = Set(lines.filter { ask.firstMatch(in: $0.code, range: NSRange($0.code.startIndex..., in: $0.code)) != nil }.map(\.file))

        #expect(asking == ["PrestoCVApp/Sources/PrestoCVComposition/AppPaths.swift"], "Asking for a folder in \(asking.sorted())")
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
