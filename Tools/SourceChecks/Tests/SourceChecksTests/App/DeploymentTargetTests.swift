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

    @Test("An iOS platform of a manifest below 26.5 is found", arguments: [
        #".iOS("26.0")"#, #".iOS("26.4")"#, #".iOS("26")"#, #".iOS( "26.0" )"#,
        ".iOS(.v26)", ".iOS(.v26_4)", ".iOS(.v18)", ".iOS(.v16)", ".iOS(.v9)",
    ])
    func manifestPlatformBelowTheMinimumIsFound(platform: String) {
        let text = "let package = Package(\n    name: \"P\",\n    platforms: [\(platform), .macOS(\"26.0\")]\n)"

        let findings = DeploymentTargets.findings(inManifest: text, file: "P/Package.swift", mustDeclareIOS: true)

        #expect(findings.map(\.line) == [3], "\(platform): \(findings)")
    }

    @Test("An iOS platform of a manifest at 26.5 or later is not found", arguments: [
        #".iOS("26.5")"#, #".iOS("26.10")"#, #".iOS("27.0")"#, #".iOS("27")"#, ".iOS(.v26_5)", ".iOS(.v27)", ".iOS(.v28)",
    ])
    func manifestPlatformAtTheMinimumIsNotFound(platform: String) {
        let text = "platforms: [\(platform), .macOS(\"26.0\")],"

        #expect(DeploymentTargets.findings(inManifest: text, file: "P/Package.swift", mustDeclareIOS: true).isEmpty)
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

        #expect(DeploymentTargets.findings(inManifest: text, file: "P/Package.swift", mustDeclareIOS: true).map(\.line) == [5])
    }

    @Test("Every branch of a condition is read: the manifest of the Apple hosts is not the only one")
    func manifestBranchesAreAllRead() {
        let text = """
        #if os(Linux)
        let platforms: [SupportedPlatform] = [.iOS("26.5")]
        #else
        let platforms: [SupportedPlatform] = [.iOS("26.0")]
        #endif
        """

        #expect(DeploymentTargets.findings(inManifest: text, file: "P/Package.swift", mustDeclareIOS: true).map(\.line) == [4])
    }

    @Test("A platform in a comment is not a declaration, and does not make a manifest declare one")
    func manifestCommentsAreIgnored() {
        let commented = "// platforms: [.iOS(\"26.0\")]\nplatforms: [.iOS(\"26.5\")], // was .iOS(\"26.0\")"
        let onlyCommented = "// platforms: [.iOS(\"26.5\")]\nplatforms: [.macOS(\"26.0\")]"

        #expect(DeploymentTargets.findings(inManifest: commented, file: "P/Package.swift", mustDeclareIOS: true).isEmpty)
        #expect(DeploymentTargets.findings(inManifest: onlyCommented, file: "P/Package.swift", mustDeclareIOS: true).count == 1)
    }

    @Test("A platform that does not say a release is found: it could hide any value", arguments: [
        ".iOS(minimum)", ".iOS(.v26_5 + 1)", ".iOS(\"26.\\(minor)\")", ".iOS(", ".iOS()",
    ])
    func manifestPlatformThatIsNoReleaseIsFound(platform: String) {
        let text = "platforms: [\(platform)]"

        #expect(DeploymentTargets.findings(inManifest: text, file: "P/Package.swift", mustDeclareIOS: true).count == 1, "\(platform)")
    }

    @Test("A manifest of the app that declares no iOS platform is found: SwiftPM then builds it for an older default")
    func productManifestWithoutIOSIsFound() {
        let text = "let package = Package(name: \"P\", platforms: [.macOS(\"26.0\")])"

        #expect(DeploymentTargets.findings(inManifest: text, file: "P/Package.swift", mustDeclareIOS: true).count == 1)
        #expect(DeploymentTargets.findings(inManifest: "let package = Package(name: \"P\")", file: "P/Package.swift", mustDeclareIOS: true).count == 1)
    }

    @Test("A tool's manifest need not declare iOS, but if it does the release counts")
    func toolManifestMayOmitIOS() {
        let macOnly = "platforms: [.macOS(.v13)]"

        #expect(DeploymentTargets.findings(inManifest: macOnly, file: "Tools/T/Package.swift", mustDeclareIOS: false).isEmpty)
        #expect(DeploymentTargets.findings(inManifest: "platforms: [.iOS(.v16)]", file: "Tools/T/Package.swift", mustDeclareIOS: false).count == 1)
    }

    @Test("A platform used as a condition, not declared, is not read as a declaration")
    func platformConditionIsNotADeclaration() {
        let text = "platforms: [.iOS(\"26.5\")]\n.target(name: \"T\", dependencies: [.product(name: \"D\", package: \"D\", condition: .when(platforms: [.iOS]))])"

        #expect(DeploymentTargets.findings(inManifest: text, file: "P/Package.swift", mustDeclareIOS: true).isEmpty)
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
}
