import Foundation
import Testing

// MARK: - Release Hygiene Tests

/// What the Release build must not carry: output meant for a developer, and a privacy manifest that says less (or more)
/// than the code does. That the bundle carries no data nobody reads is checked by the app tests, on the bundle itself.
@Suite("Release Hygiene Tests")
struct ReleaseHygieneTests {

    // MARK: Source tree

    private static let root = Repository.root

    /// An app target of the project, with its privacy manifest and the products it links directly.
    struct App {
        let name: String
        let folder: String
        let manifest: String
        /// The package products the project links into the target: the start of the walk through the manifests, kept
        /// equal to the project by `scansCoverTheLinkedProducts`.
        let linkedProducts: [String]
    }

    /// The released app, which does not link the new app's targets.
    static let legacy = App(
        name: "PrestoCV", folder: "PrestoCV", manifest: "PrestoCV/PrivacyInfo.xcprivacy",
        linkedProducts: [
            "PrestoCVCore", "CVPDFExporter", "CVGeneratorAI", "PrestoCVDomain", "PrestoCVApplication", "PrestoCVImporting",
            "PrestoCVImportingPDFKit", "DiagnosticLogging", "DiagnosticLoggingOSLog", "DiagnosticTrace", "DiagnosticTraceFiles",
            "DiagnosticTraceDistribution",
        ]
    )

    /// The second app, which becomes the shipped one at the switch (docs/architecture/modules.md).
    static let next = App(
        name: "PrestoCVNext", folder: "PrestoCVNext", manifest: "PrestoCVNext/PrivacyInfo.xcprivacy",
        linkedProducts: ["PrestoCVComposition", "PrestoCVPresentation"]
    )

    static let apps = [legacy, next]

    private static func projectText() -> String {
        do {
            return try String(contentsOf: root.appendingPathComponent("PrestoCV.xcodeproj/project.xcproj"), encoding: .utf8)
        } catch {
            preconditionFailure("The project file cannot be read: \(error)")
        }
    }

    /// The manifests of the local packages the project names.
    static let manifests: PackageManifests = {
        let project = projectText()
        let expression = try! NSRegularExpression(pattern: #""kind": "local",\s*"path": "(\w+)""#)
        let packages = expression.matches(in: project, range: NSRange(project.startIndex..., in: project)).compactMap { match in
            Range(match.range(at: 1), in: project).map { String(project[$0]) }
        }
        do {
            return try PackageManifests(packages: packages) { package in
                try String(contentsOf: root.appendingPathComponent("\(package)/Package.swift"), encoding: .utf8)
            }
        } catch {
            preconditionFailure("A package manifest cannot be read: \(error)")
        }
    }()

    /// The package products the project links into a target, by the target's name.
    static func productsLinked(byTarget target: String) -> [String] {
        let project = projectText()
        guard let start = project.range(of: "\"name\": \"\(target)\"") else { return [] }
        let end = project.range(of: "\"name\": \"", range: start.upperBound..<project.endIndex)?.lowerBound ?? project.endIndex
        let block = String(project[start.lowerBound..<end])
        let member = try! NSRegularExpression(pattern: #""product-name": "([^"]+)""#)
        return member.matches(in: block, range: NSRange(block.startIndex..., in: block)).compactMap { match in
            Range(match.range(at: 1), in: block).map { String(block[$0]) }
        }
    }

    /// The targets a Release build of the app compiles in: the products it links, and every target they depend on, in
    /// this package and in the sibling packages, however far down. A linked product no package declares is unresolved.
    static func reached(by app: App) -> (targets: [PackageManifests.Target], unresolved: [PackageManifests.ProductReference]) {
        var undeclared: [PackageManifests.ProductReference] = []
        let start = app.linkedProducts.flatMap { name in
            let owners = manifests.products.compactMap { package, products in
                products[name] == nil ? nil : PackageManifests.ProductReference(name: name, package: package)
            }
            if owners.isEmpty { undeclared.append(PackageManifests.ProductReference(name: name, package: "(none)")) }
            return owners
        }
        let walk = manifests.reached(from: start)
        return (walk.targets, undeclared + walk.unresolved)
    }

    /// The sources whose code ships with the app: its own folder and those of every target it compiles in.
    static func shippedFolders(of app: App) -> [String] {
        [app.folder] + reached(by: app).targets.map(\.folder)
    }

    /// The folders of both apps: what any Release build of the repository carries.
    static let shippedFolders = Array(Set(apps.flatMap(shippedFolders(of:)))).sorted()

    struct Line {
        let file: String
        let number: Int
        let code: String
        /// Whether the line is only compiled into a Debug build
        let isDebugOnly: Bool
    }

    /// The code lines of the shipped sources, without comments and without the previews at the end of a file.
    static func shippedLines(in folders: [String] = shippedFolders) -> [Line] {
        var lines: [Line] = []
        for folder in folders {
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

    @Test("The scans start from the package products each app target links, as the project says")
    func scansCoverTheLinkedProducts() {
        for app in Self.apps {
            let linked = Self.productsLinked(byTarget: app.name)
            #expect(Set(linked) == Set(app.linkedProducts), "\(app.name): add a newly linked product to its start set")
        }
    }

    @Test("Every manifest is read whole, every target an app compiles in has code, and every product resolves")
    func everyTargetReachedHasSources() {
        #expect(Self.manifests.unreadable.isEmpty, "The manifest reader does not follow \(Self.manifests.unreadable)")
        for app in Self.apps {
            let (targets, unresolved) = Self.reached(by: app)
            #expect(unresolved.isEmpty, "\(app.name): no manifest declares \(unresolved)")
            #expect(targets.count >= app.linkedProducts.count, "\(app.name): the walk reached only \(targets.map(\.name))")
            for target in targets {
                let folder = Self.root.appendingPathComponent(target.folder)
                let files = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil)?
                    .compactMap { ($0 as? URL)?.pathExtension == "swift" ? $0 : nil } ?? []
                #expect(!files.isEmpty, "\(app.name): the scan reads no code at \(target.folder) (target \(target.name))")
            }
        }
    }

    @Test("The walk reaches the targets the linked products take in, however far down")
    func theWalkReachesTheTargetsBelow() {
        let names = Set(Self.reached(by: Self.next).targets.map(\.name))
        let legacy = Set(Self.reached(by: Self.legacy).targets.map(\.name))

        #expect(names.isSuperset(of: [
            "PrestoCVComposition", "PrestoCVWorkflowPorts", "PrestoCVIntegration", "PrestoCVImportFiles", "CVDocumentModel",
            "CVDesignCatalog", "CVRendering", "CVDrafting", "PrestoCVPersistence", "DiagnosticTraceFiles",
        ]), "Reached by the new app: \(names.sorted())")
        #expect(legacy.isDisjoint(with: ["PrestoCVImportFiles", "PrestoCVWorkflowPorts"]), "The released app does not link these")
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

    /// A UI test cancels a read that never ends by itself; no Release build may hold the person's import.
    @Test("The fixture that holds the import's reads is read only by Debug builds")
    func theFixtureThatHoldsTheImportIsReadOnlyInDebugBuilds() {
        let names = ["holdImportArgument", "holdsImport", "HeldImport", "fixtures.importing"]
        let reads = Self.shippedLines().filter { line in names.contains { line.code.contains($0) } }

        let offenders = reads.filter { !$0.isDebugOnly }

        #expect(!reads.isEmpty, "The scan no longer finds the code that reads the fixture: update it with the code")
        #expect(offenders.isEmpty, "The fixture that holds the import outside #if DEBUG: \(offenders.map { "\($0.file):\($0.number)" })")
    }

    /// A UI test opens a PDF in the second app as another app would; no Release build may open a file the person did
    /// not. The released app has its own "Open in", whose names this scan would find, so it reads the second app only.
    @Test("The fixture that opens a file in the app is read only by Debug builds")
    func theFixtureThatOpensAFileIsReadOnlyInDebugBuilds() {
        let names = ["openedFile", "OpenedFileFixture"]
        let reads = Self.shippedLines(in: Self.shippedFolders(of: Self.next)).filter { line in
            names.contains { line.code.contains($0) }
        }

        let offenders = reads.filter { !$0.isDebugOnly }

        #expect(!reads.isEmpty, "The scan no longer finds the code that reads the fixture: update it with the code")
        #expect(offenders.isEmpty, "The fixture that opens a file outside #if DEBUG: \(offenders.map { "\($0.file):\($0.number)" })")
    }

    /// UI tests that are not about the designs accept the bundled designs without rendering them; no Release build may
    /// install a design that no render checked.
    @Test("The fixture that accepts the bundled designs without rendering them is read only by Debug builds")
    func theFixtureThatAcceptsTheDesignsIsReadOnlyInDebugBuilds() {
        let names = ["readyDesignsArgument", "acceptsBundledDesigns", "AcceptedDesigns", "fixtures.designGate"]
        let reads = Self.shippedLines().filter { line in names.contains { line.code.contains($0) } }

        let offenders = reads.filter { !$0.isDebugOnly }

        #expect(!reads.isEmpty, "The scan no longer finds the code that reads the fixture: update it with the code")
        #expect(offenders.isEmpty, "The fixture that accepts the designs outside #if DEBUG: \(offenders.map { "\($0.file):\($0.number)" })")
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

    /// A UI test lets another window change or delete the open CV, to see the editor's conflict and deletion; no Release
    /// build may be able to.
    @Test("The fixture of the other window is read only by Debug builds")
    func theFixtureOfTheOtherWindowIsReadOnlyInDebugBuilds() {
        let names = ["otherWindowArgument", "OtherWindowStore", "fixtures.store", ".otherWindow"]
        let reads = Self.shippedLines().filter { line in names.contains { line.code.contains($0) } }

        let offenders = reads.filter { !$0.isDebugOnly }

        #expect(!reads.isEmpty, "The scan no longer finds the code that reads the fixture: update it with the code")
        #expect(offenders.isEmpty, "The fixture of the other window outside #if DEBUG: \(offenders.map { "\($0.file):\($0.number)" })")
    }

    /// A UI test makes the first writes of a CV fail, to see the editor's failed save; no Release build may be able to.
    @Test("The fixture that fails the first writes is read only by Debug builds")
    func theFixtureThatFailsWritesIsReadOnlyInDebugBuilds() {
        let names = ["failWritesArgument", "writesToFail", "FailingWritesStore"]
        let reads = Self.shippedLines().filter { line in names.contains { line.code.contains($0) } }

        let offenders = reads.filter { !$0.isDebugOnly }

        #expect(!reads.isEmpty, "The scan no longer finds the code that reads the fixture: update it with the code")
        #expect(offenders.isEmpty, "The fixture that fails writes outside #if DEBUG: \(offenders.map { "\($0.file):\($0.number)" })")
    }

    /// A UI test makes the autosave wait a long time, to leave an editor before it stores; no Release build may be able to.
    @Test("The fixture that sets the autosave pause is read only by Debug builds")
    func theFixtureThatSetsTheAutosavePauseIsReadOnlyInDebugBuilds() {
        let names = ["autosavePauseArgument", "autosavePauseSeconds", "fixtures.autosavePause"]
        let reads = Self.shippedLines().filter { line in names.contains { line.code.contains($0) } }

        let offenders = reads.filter { !$0.isDebugOnly }

        #expect(!reads.isEmpty, "The scan no longer finds the code that reads the fixture: update it with the code")
        #expect(offenders.isEmpty, "The fixture that sets the autosave pause outside #if DEBUG: \(offenders.map { "\($0.file):\($0.number)" })")
    }

    /// A UI test stores two invented runs of the diagnostics before the trace chain starts; no Release build may be able to.
    @Test("The fixture of the invented trace runs is read only by Debug builds")
    func theFixtureOfTheInventedTraceRunsIsReadOnlyInDebugBuilds() {
        let names = ["traceRunsArgument", "storesTraceRuns", "InventedTraceRuns", "seedTrace"]
        let reads = Self.shippedLines().filter { line in names.contains { line.code.contains($0) } }

        let offenders = reads.filter { !$0.isDebugOnly }

        #expect(!reads.isEmpty, "The scan no longer finds the code that reads the fixture: update it with the code")
        #expect(offenders.isEmpty, "The fixture of the invented trace runs outside #if DEBUG: \(offenders.map { "\($0.file):\($0.number)" })")
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

    private func declaredCategories(in manifest: String) throws -> Set<String> {
        let url = Self.root.appendingPathComponent(manifest)
        let plist = try #require(PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any])
        let types = try #require(plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        return Set(types.compactMap { $0["NSPrivacyAccessedAPIType"] as? String })
    }

    private func declaredWithoutReasons(in manifest: String) throws -> [String] {
        let url = Self.root.appendingPathComponent(manifest)
        let plist = try #require(PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any])
        let types = try #require(plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        return types.filter { ($0["NSPrivacyAccessedAPITypeReasons"] as? [String] ?? []).isEmpty }
            .compactMap { $0["NSPrivacyAccessedAPIType"] as? String }
    }

    @Test("Each app's privacy manifest declares the required-reason APIs its code uses, and no others")
    func privacyManifestMatchesTheCode() throws {
        for app in Self.apps {
            let lines = Self.shippedLines(in: Self.shippedFolders(of: app))
            var used: Set<String> = []
            for (category, pattern) in Self.requiredReasonAPIs {
                let api = try NSRegularExpression(pattern: pattern)
                if lines.contains(where: { api.firstMatch(in: $0.code, range: NSRange($0.code.startIndex..., in: $0.code)) != nil }) {
                    used.insert(category)
                }
            }

            let declared = try declaredCategories(in: app.manifest)

            let withoutReason = try declaredWithoutReasons(in: app.manifest)
            #expect(withoutReason.isEmpty, "\(app.name): no reason declared for \(withoutReason)")
            #expect(declared == used, "\(app.name): declared \(declared.sorted()), used by the code \(used.sorted())")
        }
    }
}
