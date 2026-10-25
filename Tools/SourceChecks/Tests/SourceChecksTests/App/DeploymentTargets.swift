import Foundation

// MARK: - Deployment targets

/// A release of iOS, as a project file or a package manifest writes it: "26.5", "26", `.v26` or `.v26_5`.
struct IOSRelease: Comparable, CustomStringConvertible {
    let major: Int
    let minor: Int
    let patch: Int

    init(_ major: Int, _ minor: Int = 0, _ patch: Int = 0) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    /// A release written as a version string. Nothing but one to three numbers separated by dots is a release.
    init?(version: String) {
        let parts = version.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...3).contains(parts.count), parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isASCIIDigit) }) else { return nil }
        let numbers = parts.compactMap { Int($0) }
        guard numbers.count == parts.count else { return nil }
        self.init(numbers[0], numbers.count > 1 ? numbers[1] : 0, numbers.count > 2 ? numbers[2] : 0)
    }

    /// A release written as a SwiftPM constant: the text after the dot of `.v26_5`.
    init?(constant: String) {
        guard constant.hasPrefix("v") else { return nil }
        let parts = constant.dropFirst().split(separator: "_", omittingEmptySubsequences: false)
        self.init(version: parts.joined(separator: "."))
    }

    var description: String { "\(major).\(minor)" + (patch == 0 ? "" : ".\(patch)") }

    static func < (lhs: IOSRelease, rhs: IOSRelease) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}

private extension Character {
    var isASCIIDigit: Bool { ("0"..."9").contains(self) }
}

/// Where the oldest iOS release the app supports is set, and whether any place sets an older one.
///
/// A place that cannot be read as a release is a finding too: a variable or a list could hide any value, and a check
/// that skipped it would pass while the minimum was lowered.
enum DeploymentTargets {

    /// The oldest iOS release the app supports (#180).
    static let minimum = IOSRelease(26, 5)

    struct Finding: Equatable, CustomStringConvertible {
        let file: String
        let line: Int
        let reason: String
        var description: String { "\(file):\(line): \(reason)" }
    }

    // MARK: Project file

    /// The build setting that sets the oldest iOS release.
    static let projectKey = "IPHONEOS_DEPLOYMENT_TARGET"

    /// The key as the project file writes it: quoted, with any number of conditions (`[config=Debug]`,
    /// `[sdk=iphoneos*][arch=arm64]`), and its value when that is a string.
    private static let projectSetting = try! NSRegularExpression(
        pattern: #""IPHONEOS_DEPLOYMENT_TARGET(?:\[[^\]]*\])*"\s*:\s*(?:"([^"]*)")?"#
    )

    /// What the check made of the project file: how many settings it read, and what is wrong with them.
    struct ProjectReading {
        let settingsRead: Int
        let findings: [Finding]
    }

    /// Reads every build setting of the project file that sets an iOS release.
    ///
    /// A line that names the key more often than the reader found a setting on it is a finding too: it spells the
    /// setting in a form the reader does not know (unquoted, with `=`, in single quotes), and a reader that skipped it
    /// would pass while the minimum was lowered.
    static func read(project text: String, file: String) -> ProjectReading {
        var findings: [Finding] = []
        var settingsRead = 0
        for (index, line) in text.components(separatedBy: "\n").enumerated() {
            let matches = projectSetting.matches(in: line, range: NSRange(line.startIndex..., in: line))
            for match in matches {
                settingsRead += 1
                let value = Range(match.range(at: 1), in: line).map { String(line[$0]) }
                let written = value ?? line.trimmingCharacters(in: .whitespaces)
                if let reason = problem(with: value.flatMap { IOSRelease(version: $0) }, written: written, setting: projectKey) {
                    findings.append(Finding(file: file, line: index + 1, reason: reason))
                }
            }
            if line.components(separatedBy: projectKey).count - 1 > matches.count {
                findings.append(Finding(
                    file: file, line: index + 1,
                    reason: "\(projectKey) is named in a form the check does not read, so it could set any release: \(line.trimmingCharacters(in: .whitespaces))"
                ))
            }
        }
        return ProjectReading(settingsRead: settingsRead, findings: findings)
    }

    /// The settings of the project file that set an iOS release below the minimum, or none that can be read.
    static func findings(inProject text: String, file: String) -> [Finding] {
        read(project: text, file: file).findings
    }

    // MARK: Package manifests

    /// A `.iOS(` platform and what stands in its brackets; the closing bracket is missing when the call goes on to
    /// another line.
    private static let manifestPlatform = try! NSRegularExpression(pattern: #"\.iOS\(([^)]*)(\)?)"#)

    /// The iOS platforms of a manifest that name a release below the minimum, or none that can be read. A manifest of
    /// the app that declares no iOS platform is found too: SwiftPM then builds it for its own, older default.
    static func findings(inManifest text: String, file: String, mustDeclareIOS: Bool) -> [Finding] {
        var findings: [Finding] = []
        var declaresIOS = false
        for (index, raw) in text.components(separatedBy: "\n").enumerated() {
            let line = raw.components(separatedBy: "//").first ?? ""
            for match in manifestPlatform.matches(in: line, range: NSRange(line.startIndex..., in: line)) {
                declaresIOS = true
                let argument = Range(match.range(at: 1), in: line).map { String(line[$0]).trimmingCharacters(in: .whitespaces) } ?? ""
                let closed = match.range(at: 2).length > 0
                let release = closed ? release(ofPlatformArgument: argument) : nil
                if let reason = problem(with: release, written: ".iOS(\(argument)\(closed ? ")" : "")", setting: "The iOS platform") {
                    findings.append(Finding(file: file, line: index + 1, reason: reason))
                }
            }
        }
        if mustDeclareIOS && !declaresIOS {
            findings.append(Finding(
                file: file, line: 1,
                reason: "declares no iOS platform: SwiftPM then builds the package for an older default release than \(minimum)"
            ))
        }
        return findings
    }

    /// The release that stands in the brackets of `.iOS(…)`: a string, `"26.5"`, or a constant, `.v26_5`.
    private static func release(ofPlatformArgument argument: String) -> IOSRelease? {
        if argument.count >= 2, argument.hasPrefix("\""), argument.hasSuffix("\"") {
            return IOSRelease(version: String(argument.dropFirst().dropLast()))
        }
        if argument.hasPrefix(".") { return IOSRelease(constant: String(argument.dropFirst())) }
        return nil
    }

    // MARK: Verdict

    /// What is wrong with a release read from a file: nothing, or why it is a finding.
    private static func problem(with release: IOSRelease?, written: String, setting: String) -> String? {
        guard let release else { return "\(setting) does not name a release, so it could hide any value: \(written)" }
        return release < minimum ? "\(setting) is \(release), below the minimum \(minimum)" : nil
    }

    // MARK: Manifests of the repository

    /// The package manifests the check reads, with whether each must declare an iOS platform.
    ///
    /// The manifests of `Tools/` build and run on a Mac or Linux host, so they may declare none. The validation
    /// prototype is left out: nothing builds it and nothing of it ships (the architecture checker maps it as excluded).
    static func manifests(under root: URL) -> [(path: String, mustDeclareIOS: Bool)] {
        let skipped: Set<String> = [".build", "DerivedData", "node_modules"]
        guard let walk = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey]) else { return [] }
        var manifests: [(path: String, mustDeclareIOS: Bool)] = []
        for case let url as URL in walk {
            let path = String(url.path.dropFirst(root.path.count + 1))
            let name = url.lastPathComponent
            if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                if name.hasPrefix(".") || skipped.contains(name) || path == "Prototypes" { walk.skipDescendants() }
            } else if name == "Package.swift" {
                manifests.append((path: path, mustDeclareIOS: !path.hasPrefix("Tools/")))
            }
        }
        return manifests.sorted { $0.path < $1.path }
    }
}
