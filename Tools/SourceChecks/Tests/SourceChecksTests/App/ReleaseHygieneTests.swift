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

    /// The shipped app: the target keeps the released app's name, bundle id, `Info.plist`, icon and privacy manifest, and
    /// compiles the new app's sources (docs/architecture/modules.md).
    static let shipped = App(
        name: "PrestoCV", folder: "PrestoCVNext", manifest: "PrestoCV/PrivacyInfo.xcprivacy",
        linkedProducts: ["PrestoCVComposition", "PrestoCVPresentation"]
    )

    static let apps = [shipped]

    /// The products of the legacy targets (ADR 0012), which no app target links since the repoint.
    static let legacyProducts: Set<String> = ["PrestoCVCore", "CVPDFExporter", "CVGeneratorAI"]

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

    /// The package products the project links into any target.
    static func productsLinkedByAnyTarget() -> [String] {
        let project = projectText()
        let member = try! NSRegularExpression(pattern: #""product-name": "([^"]+)""#)
        return member.matches(in: project, range: NSRange(project.startIndex..., in: project)).compactMap { match in
            Range(match.range(at: 1), in: project).map { String(project[$0]) }
        }
    }

    /// The folders whose sources the project compiles into a target: its folder entries with that target as a member.
    static func folders(compiledBy target: String) -> [String] {
        let project = projectText()
        let entry = try! NSRegularExpression(pattern: #""kind": "folder",\s*"path": "([^"]+)",\s*"target-membership": \[([^\]]*)\]"#)
        return entry.matches(in: project, range: NSRange(project.startIndex..., in: project)).compactMap { match in
            guard let path = Range(match.range(at: 1), in: project), let members = Range(match.range(at: 2), in: project) else {
                return nil
            }
            let targets = project[members].split(separator: ",").map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\" \n")) }
            return targets.contains(target) ? String(project[path]) : nil
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

    /// The folders of every app target: what any Release build of the repository carries.
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

    @Test("The shipped target compiles the new app's folder, links no legacy product, and no second app target is left")
    func theShippedTargetIsTheNewApp() {
        let folders = Self.folders(compiledBy: Self.shipped.name)
        let legacy = Self.legacyProducts.intersection(Self.productsLinkedByAnyTarget())

        #expect(folders == [Self.shipped.folder], "The shipped target compiles \(folders)")
        #expect(legacy.isEmpty, "The project links the legacy products \(legacy.sorted())")
        #expect(!Self.projectText().contains(#""name": "PrestoCVNext","#), "The second app target is still in the project")
    }

    /// What `PrestoCV/` keeps for the shipped target: the released app's `Info.plist`, icon, asset catalog, privacy
    /// manifest and sample CVs (docs/architecture/modules.md). Everything else in it was the legacy app.
    static let keptInTargetFolder: [String] = [
        "PrestoCV/Info.plist", "PrestoCV/PrivacyInfo.xcprivacy", "PrestoCV/PrestoCV.icon/", "PrestoCV/Assets.xcassets/",
        "PrestoCV/Resources/Samples/",
    ]

    @Test("The legacy app's code and tests are gone: PrestoCV/ keeps only what the shipped target uses")
    func theLegacyAppIsGone() throws {
        let tracked = try Repository.trackedFiles()
        let legacyCode = tracked.filter { path in
            path.hasPrefix("PrestoCVTests/") || path.hasPrefix("PrestoCVUITests/")
                || (path.hasPrefix("PrestoCV/") && !Self.keptInTargetFolder.contains { path == $0 || ($0.hasSuffix("/") && path.hasPrefix($0)) })
        }

        #expect(legacyCode.isEmpty, "Legacy files are still tracked: \(legacyCode.prefix(10)) and \(max(0, legacyCode.count - 10)) more")
    }

    @Test("The walk reaches the targets the linked products take in, however far down, and no legacy target")
    func theWalkReachesTheTargetsBelow() {
        let names = Set(Self.reached(by: Self.shipped).targets.map(\.name))

        #expect(names.isSuperset(of: [
            "PrestoCVComposition", "PrestoCVWorkflowPorts", "PrestoCVIntegration", "PrestoCVImportFiles", "CVDocumentModel",
            "CVDesignCatalog", "CVRendering", "CVDrafting", "PrestoCVPersistence", "DiagnosticTraceFiles",
        ]), "Reached by the shipped app: \(names.sorted())")
        #expect(names.isDisjoint(with: Self.legacyProducts), "The shipped app compiles in a legacy target")
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

    private func propertyList(at path: String) throws -> [String: Any] {
        let url = Self.root.appendingPathComponent(path)
        return try #require(PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any])
    }

    private func declaredCategories(in manifest: String) throws -> Set<String> {
        let plist = try propertyList(at: manifest)
        let types = try #require(plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        return Set(types.compactMap { $0["NSPrivacyAccessedAPIType"] as? String })
    }

    private func declaredWithoutReasons(in manifest: String) throws -> [String] {
        let plist = try propertyList(at: manifest)
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

    // MARK: Document types

    /// `Tools/Release/check-archive.sh` enforces the same rule on the archive before it is uploaded: change both together.
    private static let infoPlist = "PrestoCV/Info.plist"

    @Test("Info.plist declares PDFs only, as a viewer of alternate rank, so that \"Open in PrestoCV\" offers the import")
    func infoPlistOpensPDFs() throws {
        let types = try #require(try propertyList(at: Self.infoPlist)["CFBundleDocumentTypes"] as? [[String: Any]])

        #expect(types.count == 1)
        #expect(types.first?["LSItemContentTypes"] as? [String] == ["com.adobe.pdf"])
        #expect(types.first?["LSHandlerRank"] as? String == "Alternate", "PrestoCV is no default reader of PDFs")
        #expect(types.first?["CFBundleTypeRole"] as? String == "Viewer")
    }

    @Test("A PDF opened in the app is copied for it, never opened in place")
    func pdfsAreCopied() throws {
        #expect(try propertyList(at: Self.infoPlist)["LSSupportsOpeningDocumentsInPlace"] as? Bool == false)
    }

    @Test("Info.plist declares no type of its own", arguments: ["UTExportedTypeDeclarations", "UTImportedTypeDeclarations"])
    func infoPlistDeclaresNoTypes(key: String) throws {
        #expect(try propertyList(at: Self.infoPlist)[key] == nil)
    }
}
