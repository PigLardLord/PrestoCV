import Foundation
import Testing

// MARK: - Deployment Target Tests

/// The oldest iOS release the app supports is 26.5, and nothing in the repository sets an older one (#180).
///
/// Why 26.5: the web view that renders a CV blocks every load a page can start with content rules, and those rules have
/// no resource type for `object` and `embed`. On iOS 26.2 WebKit lets those two loads through them; from 26.5 on it
/// does not (`CVRenderingWebKitSupportTests`, which runs on the releases the app supports). Lowering the minimum
/// without a defence that does not rely on the rules would reopen that hole, so the project and every manifest are
/// read here, on the build host and on the Linux job, where the repository is.
@Suite("Deployment Target Tests")
struct DeploymentTargetTests {

    // MARK: Project file

    private static let projectFile = "PrestoCV.xcodeproj/project.xcproj"

    @Test("A build setting of the project below 26.5 is found, with its line", arguments: [
        "26.0", "26.4", "26.4.9", "26", "18.2", "16.0",
    ])
    func projectSettingBelowTheMinimumIsFound(version: String) {
        let text = """
        {
          "buildSettings": {
            "IPHONEOS_DEPLOYMENT_TARGET": "\(version)",
          },
        }
        """

        let findings = DeploymentTargets.findings(inProject: text, file: Self.projectFile)

        #expect(findings.map(\.line) == [3], "\(version) should be found at line 3: \(findings)")
    }

    @Test("A build setting of the project at 26.5 or later is not found", arguments: [
        "26.5", "26.5.0", "26.5.1", "26.10", "27.0", "27", "100.0",
    ])
    func projectSettingAtTheMinimumIsNotFound(version: String) {
        let text = "    \"IPHONEOS_DEPLOYMENT_TARGET\": \"\(version)\","

        #expect(DeploymentTargets.findings(inProject: text, file: Self.projectFile).isEmpty)
    }

    @Test("A setting that is for one configuration is read like the others")
    func projectSettingOfOneConfigurationIsRead() {
        let text = """
        "IPHONEOS_DEPLOYMENT_TARGET[config=Release]": "26.5",
        "IPHONEOS_DEPLOYMENT_TARGET[config=Debug]": "26.0",
        """

        let findings = DeploymentTargets.findings(inProject: text, file: Self.projectFile)

        #expect(findings.map(\.line) == [2])
    }

    @Test("A setting with several conditions is read like the others")
    func projectSettingOfSeveralConditionsIsRead() {
        let text = """
        "IPHONEOS_DEPLOYMENT_TARGET": "26.5",
        "IPHONEOS_DEPLOYMENT_TARGET[sdk=iphoneos*][arch=arm64]": "26.0",
        "IPHONEOS_DEPLOYMENT_TARGET[sdk=iphonesimulator*][config=Debug][arch=x86_64]": "26.4",
        "IPHONEOS_DEPLOYMENT_TARGET[sdk=iphoneos*][arch=arm64]": "26.5",
        """

        let findings = DeploymentTargets.findings(inProject: text, file: Self.projectFile)

        #expect(findings.map(\.line) == [2, 3], "\(findings)")
    }

    @Test("A setting that is written in another way than the file's own is found, with its line: it is not read", arguments: [
        "IPHONEOS_DEPLOYMENT_TARGET = 26.0;",
        "IPHONEOS_DEPLOYMENT_TARGET: \"26.0\",",
        "\"IPHONEOS_DEPLOYMENT_TARGET\" = \"26.0\";",
        "'IPHONEOS_DEPLOYMENT_TARGET': '26.0',",
        "\"MY_IPHONEOS_DEPLOYMENT_TARGET\": \"26.0\",",
        "\"OTHER_FLAGS\": \"-DIPHONEOS_DEPLOYMENT_TARGET=26.0\",",
    ])
    func projectSettingThatIsNotReadIsFound(line: String) {
        let text = "\"IPHONEOS_DEPLOYMENT_TARGET\": \"26.5\",\n\(line)\n"

        let findings = DeploymentTargets.findings(inProject: text, file: Self.projectFile)

        #expect(findings.map(\.line) == [2], "\(line): \(findings)")
        #expect(findings.first?.reason.contains("does not read") == true, "\(findings)")
    }

    @Test("A line with a setting that is read and one that is not is found for the one that is not")
    func projectLineWithOneSettingReadAndOneNotIsFound() {
        let text = "\"IPHONEOS_DEPLOYMENT_TARGET\": \"26.5\", IPHONEOS_DEPLOYMENT_TARGET = 26.0;"

        #expect(DeploymentTargets.findings(inProject: text, file: Self.projectFile).count == 1)
    }

    @Test("The reading counts the settings it read, and a project that sets none reads none")
    func projectReadingCountsTheSettings() {
        let text = """
        "IPHONEOS_DEPLOYMENT_TARGET": "26.5",
        "IPHONEOS_DEPLOYMENT_TARGET[config=Debug]": "26.5",
        "IPHONEOS_DEPLOYMENT_TARGET[sdk=iphoneos*][arch=arm64]": "27.0",
        """

        #expect(DeploymentTargets.read(project: text, file: Self.projectFile).settingsRead == 3)
        #expect(DeploymentTargets.read(project: "IPHONEOS_DEPLOYMENT_TARGET = 26.5;", file: Self.projectFile).settingsRead == 0)
        #expect(DeploymentTargets.read(project: "{}", file: Self.projectFile).settingsRead == 0)
    }

    @Test("A setting that does not say a release is found: it could hide any value", arguments: [
        "\"IPHONEOS_DEPLOYMENT_TARGET\": \"$(inherited)\",",
        "\"IPHONEOS_DEPLOYMENT_TARGET\": \"\",",
        "\"IPHONEOS_DEPLOYMENT_TARGET\": \"latest\",",
        "\"IPHONEOS_DEPLOYMENT_TARGET\": [\"26.0\"],",
    ])
    func projectSettingThatIsNoReleaseIsFound(line: String) {
        #expect(DeploymentTargets.findings(inProject: line, file: Self.projectFile).count == 1, "\(line)")
    }

    @Test("Every setting of the project is read, not only the first")
    func everyProjectSettingIsRead() {
        let text = """
        "IPHONEOS_DEPLOYMENT_TARGET": "26.5",
        "IPHONEOS_DEPLOYMENT_TARGET": "26.5",
        "IPHONEOS_DEPLOYMENT_TARGET": "26.1",
        "IPHONEOS_DEPLOYMENT_TARGET": "26.0",
        """

        #expect(DeploymentTargets.findings(inProject: text, file: Self.projectFile).map(\.line) == [3, 4])
    }

    // MARK: Package manifests

    /// A manifest whose `Package` call is given these platforms, on its third line.
    private static func manifest(platforms: String) -> String {
        "let package = Package(\n    name: \"P\",\n    platforms: \(platforms)\n)"
    }

    private static func findings(in text: String, mustDeclareIOS: Bool = true) -> [DeploymentTargets.Finding] {
        DeploymentTargets.findings(inManifest: text, file: "P/Package.swift", mustDeclareIOS: mustDeclareIOS)
    }

    @Test("An iOS platform of a manifest below 26.5 is found", arguments: [
        #".iOS("26.0")"#, #".iOS("26.4")"#, #".iOS("26")"#, #".iOS( "26.0" )"#,
        ".iOS(.v26)", ".iOS(.v26_4)", ".iOS(.v18)", ".iOS(.v16)", ".iOS(.v9)",
    ])
    func manifestPlatformBelowTheMinimumIsFound(platform: String) {
        let findings = Self.findings(in: Self.manifest(platforms: "[\(platform), .macOS(\"26.0\")]"))

        #expect(findings.map(\.line) == [3], "\(platform): \(findings)")
    }

    @Test("An iOS platform of a manifest at 26.5 or later is not found", arguments: [
        #".iOS("26.5")"#, #".iOS("26.10")"#, #".iOS("27.0")"#, #".iOS("27")"#, ".iOS(.v26_5)", ".iOS(.v27)", ".iOS(.v28)",
        #".iOS("26.5",)"#, #"SupportedPlatform.iOS("26.5")"#,
    ])
    func manifestPlatformAtTheMinimumIsNotFound(platform: String) {
        #expect(Self.findings(in: Self.manifest(platforms: "[\(platform), .macOS(\"26.0\")]")).isEmpty)
    }

    @Test("An iOS platform written in other ways than the usual is read all the same", arguments: [
        #".iOS ("26.0")"#, #". iOS("26.0")"#, ".iOS(\n        \"26.0\"\n    )", #"SupportedPlatform.iOS("26.0")"#,
        #"SupportedPlatform . iOS ( "26.0" )"#, #".iOS("26.0",)"#,
    ])
    func manifestPlatformSpelledInAnotherWayIsRead(platform: String) {
        let findings = Self.findings(in: Self.manifest(platforms: "[.macOS(\"26.0\"), \(platform)]"))

        #expect(findings.count == 1 && findings[0].reason.contains("below the minimum"), "\(platform): \(findings)")
    }

    @Test("A platform on a line of its own, in a list over several lines, is found with its line")
    func manifestPlatformOverSeveralLinesIsFound() {
        let text = """
        let package = Package(
            name: "P",
            platforms: [
                .macOS("26.0"),
                .iOS("26.0"),
            ],
        )
        """

        #expect(Self.findings(in: text).map(\.line) == [5])
    }

    @Test("Every Package call is read, in every branch of a condition: the manifest of the Apple hosts is not the only one")
    func manifestBranchesAreAllRead() {
        let text = """
        #if os(Linux)
        let package = Package(name: "P", platforms: [.iOS("26.5")])
        #else
        let package = Package(name: "P", platforms: [.iOS("26.0")])
        #endif
        """

        #expect(Self.findings(in: text).map(\.line) == [4])
    }

    @Test("A platform in a comment is not a declaration, and does not make a manifest declare one")
    func manifestLineCommentsAreIgnored() {
        let commented = "// platforms: [.iOS(\"26.0\")]\nlet package = Package(name: \"P\", platforms: [.iOS(\"26.5\")]) // was .iOS(\"26.0\")"
        let onlyCommented = "// platforms: [.iOS(\"26.5\")]\nlet package = Package(name: \"P\", platforms: [.macOS(\"26.0\")])"

        #expect(Self.findings(in: commented).isEmpty)
        #expect(Self.findings(in: onlyCommented).count == 1)
    }

    @Test("A platform in a block comment is not a declaration either, and nested comments end where the outer one ends")
    func manifestBlockCommentsAreIgnored() {
        let hidesTheOnlyIOS = Self.manifest(platforms: #"[/* .iOS("26.5"), */ .macOS("26.0")]"#)
        let nested = Self.manifest(platforms: #"[/* a /* b */ .iOS("26.5"), */ .macOS("26.0")]"#)
        let hidesALowOne = Self.manifest(platforms: #"[.iOS("26.5") /* , .iOS("26.0") */, .macOS("26.0")]"#)
        let outsideTheNesting = Self.manifest(platforms: #"[/* a /* b */ c */ .iOS("26.0")]"#)

        #expect(Self.findings(in: hidesTheOnlyIOS).count == 1, "\(Self.findings(in: hidesTheOnlyIOS))")
        #expect(Self.findings(in: nested).count == 1, "\(Self.findings(in: nested))")
        #expect(Self.findings(in: hidesALowOne).isEmpty, "\(Self.findings(in: hidesALowOne))")
        #expect(Self.findings(in: outsideTheNesting).first?.reason.contains("below the minimum") == true)
    }

    @Test("A comment over several lines does not shift the lines of what follows")
    func manifestCommentsKeepTheLines() {
        let text = "/* one\n   two\n   three */\n// four\nlet package = Package(\n    name: \"P\",\n    platforms: [.iOS(\"26.0\")]\n)"

        #expect(Self.findings(in: text).map(\.line) == [7])
    }

    @Test("A comment marker or a bracket inside a string is no comment and no bracket")
    func manifestStringsHideTheirContent() {
        let slashes = "let package = Package(name: \"P\", dependencies: [.package(url: \"https://x.y/z\", from: \"1.0.0\")], platforms: [.iOS(\"26.0\")])"
        let star = "let package = Package(name: \"a/*b\", dependencies: [.package(url: \"a/*b\", from: \"1.0.0\")], platforms: [.iOS(\"26.0\")])"
        let brackets = "let package = Package(name: \"a)]}(\", platforms: [.iOS(\"26.0\")])"
        let escaped = "let package = Package(name: \"a\\\"//b\", platforms: [.iOS(\"26.0\")])"
        let interpolated = "let package = Package(name: \"a\\(\"b)\")c\", platforms: [.iOS(\"26.0\")])"
        let raw = "let package = Package(name: #\"a\"//b\"#, platforms: [.iOS(\"26.0\")])"
        let multiline = "let package = Package(name: \"\"\"\n    x \"// /* \"quoted\"\n    \"\"\", platforms: [.iOS(\"26.0\")])"

        for text in [slashes, star, brackets, escaped, interpolated, raw, multiline] {
            let findings = Self.findings(in: text)
            #expect(findings.count == 1 && findings[0].reason.contains("below the minimum"), "\(text)\n\(findings)")
        }
    }

    @Test("An iOS platform that is not in the platforms of a Package call is no declaration")
    func manifestPlatformOutsideThePackageCallIsNoDeclaration() {
        let text = "let unused: SupportedPlatform = .iOS(\"26.5\")\nlet package = Package(name: \"P\", platforms: [.macOS(\"26.0\")])"
        let inAString = "let note = \"\"\"\n    platforms: [.iOS(\"26.5\")]\n    \"\"\"\nlet package = Package(name: \"P\", platforms: [.macOS(\"26.0\")])"
        let lowOutside = "let unused: SupportedPlatform = .iOS(\"26.0\")\nlet package = Package(name: \"P\", platforms: [.iOS(\"26.5\")])"

        #expect(Self.findings(in: text).map(\.reason).allSatisfy { $0.contains("declares no iOS platform") } && Self.findings(in: text).count == 1)
        #expect(Self.findings(in: inAString).count == 1)
        #expect(Self.findings(in: lowOutside).isEmpty, "A release that no Package call declares does not set the minimum")
    }

    @Test("A platform that does not say a release is found: it could hide any value", arguments: [
        ".iOS(minimum)", ".iOS(.v26_5 + 1)", ".iOS(\"26.\\(minor)\")", ".iOS()", ".iOS(26.5)", ".iOS(version: \"26.0\")",
        ".iOS(\"26.5\", \"26.0\")", ".iOS(\"\"\"\n26.5\n\"\"\")", ".iOS(\"26.5.0.1\")", ".iOS(.v26_5.self)",
    ])
    func manifestPlatformThatIsNoReleaseIsFound(platform: String) {
        let findings = Self.findings(in: Self.manifest(platforms: "[\(platform)]"))

        #expect(findings.count == 1 && findings[0].reason.contains("could hide any value"), "\(platform): \(findings)")
    }

    @Test("A platforms list that cannot be read is found: it could hide any value", arguments: [
        "platforms",
        "makePlatforms()",
        #"[.iOS("26.5")] + [.iOS("26.0")]"#,
        #"[.iOS("26.5")] + extra"#,
        #"[.iOS("26.5"), platform]"#,
        #"[.iOS("26.5"), makePlatform()]"#,
        #"[.iOS("26.5"), .iOS]"#,
        #"[.iOS("26.5"), ] as [SupportedPlatform]"#,
        #"nil"#,
    ])
    func manifestPlatformsThatCannotBeReadAreFound(platforms: String) {
        let findings = Self.findings(in: Self.manifest(platforms: platforms), mustDeclareIOS: false)

        #expect(findings.count == 1 && findings[0].reason.contains("could hide any value"), "\(platforms): \(findings)")
    }

    @Test("A platforms list taken from a variable is found, however the variable is set")
    func manifestPlatformsFromAVariableAreFound() {
        let text = """
        #if os(Linux)
        let platforms: [SupportedPlatform] = [.macOS("26.0")]
        #else
        let platforms: [SupportedPlatform] = [.iOS("26.0")]
        #endif
        let package = Package(name: "P", platforms: platforms)
        """

        #expect(Self.findings(in: text).map(\.line) == [6])
    }

    @Test("A platforms list read or changed after the Package call is found")
    func manifestPlatformsChangedAfterTheCallAreFound() {
        let assigned = Self.manifest(platforms: #"[.iOS("26.5")]"#) + "\npackage.platforms = [.iOS(\"26.0\")]"
        let appended = Self.manifest(platforms: #"[.iOS("26.5")]"#) + "\npackage.platforms?.append(.iOS(\"26.0\"))"

        for text in [assigned, appended] {
            let findings = Self.findings(in: text)
            #expect(findings.map(\.line) == [5], "\(text)\n\(findings)")
        }
    }

    @Test("A source that cannot be read to its end is found: a string or a comment that is not closed", arguments: [
        "let package = Package(name: \"P, platforms: [.iOS(\"26.5\")])",
        "let package = Package(name: \"P\", platforms: [.iOS(\"26.5\")]) /* never closed",
        "let package = Package(name: \"P\", platforms: [.iOS(\"26.5\")]) \"\"\"\n never closed",
        "let package = Package(name: \"a\\(\", platforms: [.iOS(\"26.5\")])",
    ])
    func manifestThatCannotBeReadToItsEndIsFound(text: String) {
        let findings = Self.findings(in: text)

        #expect(findings.count == 1 && findings[0].reason.contains("cannot be read"), "\(text)\n\(findings)")
    }

    @Test("A manifest without a Package call, or that uses Package in another way, is found: its platforms cannot be read")
    func manifestWithoutAPackageCallIsFound() {
        let none = "import PackageDescription\n// let package = Package(name: \"P\", platforms: [.iOS(\"26.5\")])"
        let alias = "typealias Manifest = Package\nlet package = Manifest(name: \"P\", platforms: [.iOS(\"26.0\")])"
        let unclosed = "let package = Package(name: \"P\", platforms: [.iOS(\"26.5\")]"

        for text in [none, alias, unclosed] {
            let findings = Self.findings(in: text, mustDeclareIOS: false)
            #expect(findings.count == 1 && findings[0].reason.contains("could hide any value"), "\(text)\n\(findings)")
        }
    }

    @Test("The type Package.Dependency is no use of Package as a manifest, but another member of Package is")
    func manifestPackageDependencyTypeIsNotAFinding() {
        let dependencyType = "var dependencies: [Package.Dependency] = []\n" + Self.manifest(platforms: #"[.iOS("26.5")]"#)
        let initializer = "let package = Package.init(name: \"P\", platforms: [.iOS(\"26.0\")])"
        let metatype = "let kind = Package.self\n" + Self.manifest(platforms: #"[.iOS("26.5")]"#)

        #expect(Self.findings(in: dependencyType).isEmpty, "\(Self.findings(in: dependencyType))")
        for text in [initializer, metatype] {
            let findings = Self.findings(in: text)
            #expect(findings.count == 1 && findings[0].reason.contains("could hide any value"), "\(text)\n\(findings)")
        }
    }

    @Test("A Package call qualified by its module is read")
    func manifestPackageCallQualifiedByItsModuleIsRead() {
        let text = "let package = PackageDescription.Package(name: \"P\", platforms: [.iOS(\"26.0\")])"

        #expect(Self.findings(in: text).count == 1)
    }

    @Test("A manifest of the app that declares no iOS platform is found: SwiftPM then builds it for an older default")
    func productManifestWithoutIOSIsFound() {
        let withMacOnly = "let package = Package(name: \"P\", platforms: [.macOS(\"26.0\")])"
        let withNone = "let package = Package(name: \"P\")"
        let emptyList = "let package = Package(name: \"P\", platforms: [])"

        for text in [withMacOnly, withNone, emptyList] {
            let findings = Self.findings(in: text)
            #expect(findings.count == 1 && findings[0].reason.contains("declares no iOS platform"), "\(text)\n\(findings)")
        }
    }

    @Test("A tool's manifest need not declare iOS, but if it does the release counts")
    func toolManifestMayOmitIOS() {
        #expect(Self.findings(in: Self.manifest(platforms: "[.macOS(.v13)]"), mustDeclareIOS: false).isEmpty)
        #expect(Self.findings(in: "let package = Package(name: \"T\")", mustDeclareIOS: false).isEmpty)
        #expect(Self.findings(in: Self.manifest(platforms: "[.iOS(.v16)]"), mustDeclareIOS: false).count == 1)
    }

    @Test("A platform used as a condition, not declared, is not read as a declaration")
    func platformConditionIsNotADeclaration() {
        let condition = ".target(name: \"T\", dependencies: [.product(name: \"D\", package: \"D\", condition: .when(platforms: [.iOS]))])"
        let declared = "let package = Package(name: \"P\", platforms: [.iOS(\"26.5\")], targets: [\(condition)])"
        let notDeclared = "let package = Package(name: \"P\", platforms: [.macOS(\"26.0\")], targets: [\(condition)])"

        #expect(Self.findings(in: declared).isEmpty)
        #expect(Self.findings(in: notDeclared).count == 1)
    }

    // MARK: The repository

    @Test("The project sets its deployment targets, the check reads every one, and none is below 26.5")
    func projectHasNoTargetBelowTheMinimum() throws {
        let text = try String(contentsOf: Repository.root.appendingPathComponent(Self.projectFile), encoding: .utf8)

        let reading = DeploymentTargets.read(project: text, file: Self.projectFile)

        try #require(reading.settingsRead > 0, "A project whose settings are not read would pass without being checked")
        let named = text.components(separatedBy: DeploymentTargets.projectKey).count - 1
        #expect(reading.settingsRead == named, "The project names \(DeploymentTargets.projectKey) \(named) times and the check read \(reading.settingsRead)")
        #expect(reading.findings.isEmpty, "The oldest supported iOS is \(DeploymentTargets.minimum) (#180):\n\(reading.findings.map(\.description).joined(separator: "\n"))")
    }

    @Test("Every package manifest of the repository sets an iOS release of 26.5 or later, outside the prototype")
    func manifestsHaveNoTargetBelowTheMinimum() throws {
        let manifests = DeploymentTargets.manifests(under: Repository.root)
        let paths = Set(manifests.map(\.path))
        for linked in ["PrestoCVCore", "CVPDFExporter", "CVGeneratorAI", "PrestoCVApp", "CVPDFExporterExamples"] {
            try #require(paths.contains("\(linked)/Package.swift"), "The scan did not find \(linked)/Package.swift: found \(paths.sorted())")
        }

        var findings: [DeploymentTargets.Finding] = []
        for manifest in manifests {
            let url = Repository.root.appendingPathComponent(manifest.path)
            let text = try String(contentsOf: url, encoding: .utf8)
            findings += DeploymentTargets.findings(inManifest: text, file: manifest.path, mustDeclareIOS: manifest.mustDeclareIOS)
        }

        #expect(findings.isEmpty, "The oldest supported iOS is \(DeploymentTargets.minimum) (#180):\n\(findings.map(\.description).joined(separator: "\n"))")
    }

    @Test("The scan reads the manifests of the tools but not the prototype's, which nothing builds")
    func scanSkipsOnlyThePrototype() {
        let manifests = DeploymentTargets.manifests(under: Repository.root)

        #expect(manifests.contains { $0.path == "Tools/SourceChecks/Package.swift" && !$0.mustDeclareIOS })
        #expect(manifests.contains { $0.path == "PrestoCVCore/Package.swift" && $0.mustDeclareIOS })
        #expect(!manifests.contains { $0.path.hasPrefix("Prototypes/") })
        #expect(!manifests.contains { $0.path.contains("/.build/") })
    }

    // MARK: Which manifests are scanned

    /// A tree with a manifest at each of these paths, in a folder of its own.
    private static func tree(of paths: [String]) throws -> URL {
        // Not resolved: a Mac's temporary folder is a link (/var to /private/var), and the scan must report the same paths
        // whichever way its root is written.
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("DeploymentTargetTests-\(UUID().uuidString)")
        for path in paths {
            let url = root.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data().write(to: url)
        }
        return root
    }

    @Test("A manifest named for a tools version is scanned like Package.swift: SwiftPM picks it for that toolchain")
    func versionedManifestsAreScanned() throws {
        let root = try Self.tree(of: [
            "App/Package.swift", "App/Package@swift-6.swift", "App/Package@swift-6.0.swift", "App/Package@swift-5.9.1.swift",
            "App/Package@swift-6.0.0.1.swift", "App/Package@swift-.swift", "App/Package@swift-6.swift.bak", "App/Package@6.swift",
            "App/Packages.swift", "App/NotPackage.swift", "App/Sources/Package@swift-6.swift",
        ])
        defer { try? FileManager.default.removeItem(at: root) }

        let paths = DeploymentTargets.manifests(under: root).map(\.path)

        #expect(paths == [
            "App/Package.swift", "App/Package@swift-5.9.1.swift", "App/Package@swift-6.0.swift", "App/Package@swift-6.swift",
            "App/Sources/Package@swift-6.swift",
        ], "\(paths)")
    }

    @Test("Only the folders for tools that run on a host may omit iOS: any other manifest must declare it")
    func onlyHostOnlyFoldersMayOmitIOS() throws {
        let root = try Self.tree(of: [
            "Tools/Check/Package.swift", "Tools/Check/Package@swift-6.swift", "Backend/Package.swift", "Toolset/Package.swift",
            "Prototypes/ADRValidation/Package.swift", "App/.hidden/Package.swift", "App/.build/Package.swift",
            "App/DerivedData/Package.swift", "App/node_modules/Package.swift",
        ])
        defer { try? FileManager.default.removeItem(at: root) }

        let manifests = DeploymentTargets.manifests(under: root)

        #expect(manifests.map(\.path) == ["Backend/Package.swift", "Tools/Check/Package.swift", "Tools/Check/Package@swift-6.swift", "Toolset/Package.swift"])
        #expect(manifests.map(\.mustDeclareIOS) == [true, false, false, true])
        #expect(DeploymentTargets.hostOnlyFolders == ["Tools"])
    }

    @Test("The paths found are relative to the root however it is written: through a link, or with the form a Mac's temporary folder has")
    func pathsDoNotDependOnHowTheRootIsWritten() throws {
        let real = try Self.tree(of: ["Tools/Check/Package.swift", "App/Package.swift", "Prototypes/P/Package.swift"])
        let link = real.deletingLastPathComponent().appendingPathComponent("DeploymentTargetTests-link-\(UUID().uuidString)")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)
        defer {
            try? FileManager.default.removeItem(at: link)
            try? FileManager.default.removeItem(at: real)
        }

        for root in [real, link, real.resolvingSymlinksInPath(), URL(fileURLWithPath: real.path + "/")] {
            let manifests = DeploymentTargets.manifests(under: root)

            #expect(manifests.map(\.path) == ["App/Package.swift", "Tools/Check/Package.swift"], "\(root.path): \(manifests.map(\.path))")
            #expect(manifests.map(\.mustDeclareIOS) == [true, false], "\(root.path)")
        }
    }

    @Test("A manifest of the app that declares no iOS platform is told where a package that never builds for iOS goes")
    func missingIOSReasonNamesTheRemedy() {
        let findings = Self.findings(in: "let package = Package(name: \"P\")")

        #expect(findings.count == 1 && findings[0].reason.contains("hostOnlyFolders"), "\(findings)")
    }
}
