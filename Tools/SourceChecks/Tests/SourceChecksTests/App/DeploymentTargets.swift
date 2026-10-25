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

    /// The platforms every `Package` call of a manifest declares, read from the tokens of the source and not from its
    /// lines: a platform written in a comment or a string is none, and a platform that is not in the `platforms:`
    /// argument of a `Package` call (an unrelated `.iOS(` expression, a `.when(platforms:)` condition) is none either.
    ///
    /// Whatever the reader cannot tell is a finding, because a manifest could hide any value there: a `platforms`
    /// argument that is not a list written out, an element that is not a platform written out, a release that is not a
    /// string or a `.vNN_N` constant, a `Package` that is not called, a `.platforms` read or change after the call, a
    /// source that cannot be read to its end. A manifest of the app that declares no iOS platform is found too:
    /// SwiftPM then builds it for its own, older default.
    static func findings(inManifest text: String, file: String, mustDeclareIOS: Bool) -> [Finding] {
        let tokens: [SwiftToken]
        switch SwiftLexer.tokens(of: text) {
        case .success(let read): tokens = read
        case .failure(let failure):
            return [Finding(
                file: file, line: failure.line,
                reason: "cannot be read to its end (\(failure.what)), so its platforms could hide any value"
            )]
        }
        guard let partners = bracketPartners(of: tokens) else {
            return [Finding(file: file, line: 1, reason: "cannot be read to its end (its brackets do not match), so its platforms could hide any value")]
        }
        let manifest = Manifest(file: file, tokens: tokens, partners: partners, mustDeclareIOS: mustDeclareIOS)
        return manifest.findings()
    }

    private struct Manifest {
        let file: String
        let tokens: [SwiftToken]
        let partners: [Int: Int]
        let mustDeclareIOS: Bool

        func findings() -> [Finding] {
            var findings: [Finding] = []
            var calls = 0
            for (index, token) in tokens.enumerated() {
                if token.isIdentifier("Package") {
                    if !isDependencyType(at: index) { calls += 1 }
                    findings += readPackage(at: index)
                } else if token.isIdentifier("platforms"), index > 0, tokens[index - 1].isPunctuation(".") {
                    findings.append(unreadable(token.line, "the platforms of a package are read or changed after its call"))
                }
            }
            if calls == 0 { findings.append(unreadable(1, "it has no Package call")) }
            return findings.sorted { $0.line < $1.line }
        }

        // MARK: Package call

        /// A `Package` identifier: a call, whose `platforms:` argument is read, or something else, which is a finding.
        private func readPackage(at index: Int) -> [Finding] {
            let line = tokens[index].line
            if isDependencyType(at: index) { return [] }
            guard index + 1 < tokens.count, tokens[index + 1].isPunctuation("(") else {
                return [unreadable(line, "Package is used other than as a call")]
            }
            guard let close = partners[index + 1] else { return [unreadable(line, "a Package call is not closed")] }
            var findings: [Finding] = []
            var settled = false
            for argument in arguments(in: (index + 2)..<close) {
                guard argument.count >= 2, tokens[argument.lowerBound].isIdentifier("platforms"),
                      tokens[argument.lowerBound + 1].isPunctuation(":") else { continue }
                let reading = readPlatforms(argument.dropFirst(2), line: tokens[argument.lowerBound].line)
                findings += reading.findings
                settled = settled || reading.declaresIOS || !reading.findings.isEmpty
            }
            if mustDeclareIOS && !settled {
                findings.append(Finding(
                    file: file, line: line,
                    reason: "declares no iOS platform: SwiftPM then builds the package for an older default release than \(minimum) (a package that never builds for iOS goes in DeploymentTargets.hostOnlyFolders)"
                ))
            }
            return findings
        }

        /// `Package.Dependency`, the type of a dependency: it is no way to make a package, and manifests write it.
        private func isDependencyType(at index: Int) -> Bool {
            index + 2 < tokens.count && tokens[index + 1].isPunctuation(".") && tokens[index + 2].isIdentifier("Dependency")
        }

        /// The ranges of the arguments between two tokens, split at the commas that are not inside another bracket.
        /// A comma after the last argument ends it; it does not start another.
        private func arguments(in range: Range<Int>) -> [Range<Int>] {
            var ranges: [Range<Int>] = []
            var begin = range.lowerBound
            var index = range.lowerBound
            while index < range.upperBound {
                if tokens[index].isOpening, let close = partners[index] {
                    index = close + 1
                    continue
                }
                if tokens[index].isPunctuation(",") {
                    ranges.append(begin..<index)
                    begin = index + 1
                }
                index += 1
            }
            if begin < range.upperBound { ranges.append(begin..<range.upperBound) }
            return ranges
        }

        // MARK: Platforms

        /// The value of `platforms:`: a list written out, of platforms written out, such as `.iOS("26.5")`.
        private func readPlatforms(_ value: Range<Int>, line: Int) -> (findings: [Finding], declaresIOS: Bool) {
            guard !value.isEmpty, tokens[value.lowerBound].isPunctuation("["), partners[value.lowerBound] == value.upperBound - 1 else {
                return ([unreadable(line, "the platforms are not a list written out")], false)
            }
            var findings: [Finding] = []
            var declaresIOS = false
            for element in arguments(in: (value.lowerBound + 1)..<(value.upperBound - 1)) {
                // `.iOS("26.5")`, or `SupportedPlatform.iOS("26.5")`.
                var dot = element.lowerBound
                if !element.isEmpty, tokens[dot].isIdentifier("SupportedPlatform") { dot += 1 }
                guard dot + 2 < element.upperBound, tokens[dot].isPunctuation("."), tokens[dot + 1].kind == .identifier,
                      tokens[dot + 2].isPunctuation("("), partners[dot + 2] == element.upperBound - 1 else {
                    findings.append(unreadable(tokens[min(element.lowerBound, tokens.count - 1)].line, "a platform is not written out as .name(release)"))
                    continue
                }
                let name = tokens[dot + 1]
                let arguments = (dot + 3)..<(element.upperBound - 1)
                if name.text == "custom" {
                    findings.append(unreadable(name.line, "a custom platform can be named iOS"))
                } else if name.text == "iOS" {
                    declaresIOS = true
                    let written = ".iOS(\(describe(arguments)))"
                    if let reason = problem(with: release(in: arguments), written: written, setting: "The iOS platform") {
                        findings.append(Finding(file: file, line: name.line, reason: reason))
                    }
                }
            }
            return (findings, declaresIOS)
        }

        /// The release in the brackets of `.iOS(…)`: a string, `"26.5"`, or a constant, `.v26_5`; nothing else.
        private func release(in range: Range<Int>) -> IOSRelease? {
            var argument = Array(tokens[range])
            if argument.last?.isPunctuation(",") == true { argument.removeLast() }
            if argument.count == 1, argument[0].kind == .string, let value = argument[0].value {
                return IOSRelease(version: value)
            }
            if argument.count == 2, argument[0].isPunctuation("."), argument[1].kind == .identifier {
                return IOSRelease(constant: argument[1].text)
            }
            return nil
        }

        private func describe(_ range: Range<Int>) -> String {
            tokens[range].map { $0.kind == .string ? "\"\($0.value ?? "…")\"" : $0.text }.joined(separator: " ")
        }

        private func unreadable(_ line: Int, _ what: String) -> Finding {
            Finding(file: file, line: line, reason: "\(what), so the platforms of the manifest could hide any value")
        }
    }

    /// For each opening bracket, where it closes; `nil` when a closing bracket does not match the one it closes.
    /// An opening bracket that is never closed has no entry.
    private static func bracketPartners(of tokens: [SwiftToken]) -> [Int: Int]? {
        let closing = [")": "(", "]": "[", "}": "{"]
        var open: [Int] = []
        var partners: [Int: Int] = [:]
        for (index, token) in tokens.enumerated() where token.kind == .punctuation {
            if token.isOpening {
                open.append(index)
            } else if let wanted = closing[token.text] {
                guard let last = open.popLast(), tokens[last].text == wanted else { return nil }
                partners[last] = index
            }
        }
        return partners
    }

    // MARK: Verdict

    /// What is wrong with a release read from a file: nothing, or why it is a finding.
    private static func problem(with release: IOSRelease?, written: String, setting: String) -> String? {
        guard let release else { return "\(setting) does not name a release, so it could hide any value: \(written)" }
        return release < minimum ? "\(setting) is \(release), below the minimum \(minimum)" : nil
    }

    // MARK: Manifests of the repository

    /// The folders of packages that build and run on a host, a Mac or a Linux machine, and never for iOS: their
    /// manifests may declare no iOS platform. Every other manifest must declare one, or SwiftPM builds it for an older
    /// default release. A package that never builds for iOS and lives elsewhere is added here, with the reason in the
    /// pull request that adds it.
    static let hostOnlyFolders = ["Tools"]

    /// A manifest file: `Package.swift`, or `Package@swift-6.0.swift`, which SwiftPM picks for a toolchain of that
    /// version instead of `Package.swift`.
    private static let manifestName = try! NSRegularExpression(pattern: #"^Package(@swift-\d+(\.\d+){0,2})?\.swift$"#)

    /// Why the scan could not tell what a folder holds. It fails rather than skips the folder: a manifest below it could
    /// declare any release.
    struct ScanFailure: Error, CustomStringConvertible {
        let path: String
        let reason: String
        var description: String { "\(path) \(reason), so the manifests below it could hide any value" }
    }

    /// The package manifests the check reads, with whether each must declare an iOS platform.
    ///
    /// The validation prototype is left out: nothing builds it and nothing of it ships (the architecture checker maps it
    /// as excluded). So are the hidden folders, `.build`, `DerivedData` and `node_modules`, which hold no package of the
    /// app.
    ///
    /// Every other folder is read, or the scan fails with a `ScanFailure`: a folder that cannot be listed, an entry
    /// that cannot be inspected, a root that is not there, and a link to a folder, which is not followed. None of
    /// these is skipped, as the manifest it hides could declare any release. A link to a file is read as the file.
    static func manifests(under root: URL) throws -> [(path: String, mustDeclareIOS: Bool)] {
        let skipped: Set<String> = [".build", "DerivedData", "node_modules"]
        let files = FileManager.default
        // The walk starts from the resolved folder and keeps the relative paths it builds itself: they are never cut out
        // of an absolute path, which a Mac writes two ways (/var, /private/var).
        let base = root.resolvingSymlinksInPath().path
        var manifests: [(path: String, mustDeclareIOS: Bool)] = []

        func scan(_ folder: String) throws {
            let names: [String]
            do {
                names = try files.contentsOfDirectory(atPath: folder.isEmpty ? base : "\(base)/\(folder)")
            } catch {
                throw ScanFailure(path: folder.isEmpty ? "." : folder, reason: "cannot be listed (\(error.localizedDescription))")
            }
            for name in names {
                let path = folder.isEmpty ? name : "\(folder)/\(name)"
                if name.hasPrefix(".") || skipped.contains(name) || path == "Prototypes" { continue }
                let type: FileAttributeType?
                do {
                    type = try files.attributesOfItem(atPath: "\(base)/\(path)")[.type] as? FileAttributeType
                } catch {
                    throw ScanFailure(path: path, reason: "cannot be inspected (\(error.localizedDescription))")
                }
                if type == .typeDirectory {
                    try scan(path)
                } else if type == .typeSymbolicLink && isFolder("\(base)/\(path)") {
                    throw ScanFailure(path: path, reason: "is a link to a folder, which the scan does not follow")
                } else if manifestName.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)) != nil {
                    manifests.append((path: path, mustDeclareIOS: !hostOnlyFolders.contains { path.hasPrefix($0 + "/") }))
                }
            }
        }

        try scan("")
        return manifests.sorted { $0.path < $1.path }
    }

    private static func isFolder(_ path: String) -> Bool {
        var folder: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &folder) && folder.boolValue
    }
}
