import Foundation
import SwiftParser
import SwiftSyntax

// Tools/ArchitectureCheck prototype (ADR 0006).
//
//   ArchitectureCheck <root> --rules rules.json --baseline baseline.json
//                     [--against base-baseline.json] [--modules modules.md] [--adr-dir dir]
//                     [--packages dirA,dirB] [--write-baseline]
//
// 1. Inventory: every .swift file under <root> (except .build/.git) belongs to exactly one target;
//    symbolic links in the source tree are refused (SwiftPM follows them, a scanner might not).
// 2. Each file is parsed with SwiftSyntax. Detectors report constructs; the rules of docs/architecture/rules.md
//    (cited by name, never by number) map to detectors.
// 3. Findings are occurrences: file | rule | detector | fingerprint#ordinal, fingerprint = hash of the
//    construct's text without trivia. The baseline must match exactly; --against forbids growth.
// 4. Exceptions are permanent, justified by an existing ADR; baseline entries are temporary.
// 5. --modules: rules.json and modules.md must agree in both directions; rules may be stricter.
// 6. --packages: each package's declared target dependencies must be allowed imports.

struct Config: Decodable {
    struct Target: Decodable {
        let name: String, path: String
        let kind: TargetKind?             // production when absent
        let docName: String?              // row name in modules.md, when it differs (app folders)
        let allowedImports: [String]
        let rules: [String]               // the rules whose detectors run on this target
        /// module → "internal": the import must be `internal`, `fileprivate` or `private` (HumbleViews: no domain
        /// type in a public API). A plain `import` is public in the Swift 6 language mode, so it fails too.
        let requiredImportAccess: [String: ImportAccess]?

        /// A target without a kind is a production target.
        var isProduction: Bool { (kind ?? .production) == .production }
    }
    struct Exception: Decodable { let path: String; let detector: String; let adr: String; let reason: String }
    let targets: [Target]
    let rules: [String: [String]]         // rule name → detectors
    let productionRules: [String]?        // rules whose detectors run on every production target, listed or not
    let infrastructureTypes: [String]
    let exceptions: [Exception]?
    let notYetImplemented: [String]?
}

struct Finding { let key: String; let message: String }

func value(after flag: String) -> String? {
    guard let i = CommandLine.arguments.firstIndex(of: flag), i + 1 < CommandLine.arguments.count else { return nil }
    return CommandLine.arguments[i + 1]
}
func fail(_ message: String) -> Never { print("error: \(message)"); exit(2) }

/// A decoding error in words: what is wrong, and where in the file.
func describe(_ error: Error) -> String {
    guard case DecodingError.dataCorrupted(let context) = error else { return "\(error)" }
    return "\(context.debugDescription) (at \(context.codingPath.map(\.stringValue).joined(separator: ".")))"
}

guard CommandLine.arguments.count > 1, let rulesPath = value(after: "--rules"), let baselinePath = value(after: "--baseline") else {
    fail("usage: ArchitectureCheck <root> --rules <json> --baseline <json> [--against <json>] [--modules <md>] [--adr-dir <dir>] [--packages a,b] [--write-baseline] [--search-steps n]")
}
let root = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL
/// What the search for data initialisers in one file may spend (see `WorkMeter`); `--search-steps` lowers it for a test. The
/// flag takes a whole number above zero, and anything else fails the run.
let searchSteps: Int = {
    guard CommandLine.arguments.contains("--search-steps") else { return Limits.searchSteps }
    guard let steps = value(after: "--search-steps").flatMap({ Int($0) }), steps > 0 else {
        fail("--search-steps needs a whole number above zero")
    }
    return steps
}()
let config: Config
do { config = try JSONDecoder().decode(Config.self, from: Data(contentsOf: URL(fileURLWithPath: rulesPath))) }
catch { fail("cannot read rules: \(describe(error))") }

func loadBaseline(_ path: String) -> [String]? { try? JSONDecoder().decode([String].self, from: Data(contentsOf: URL(fileURLWithPath: path))) }
var problems: [String] = []
var findings: [Finding] = []

// MARK: 1. Inventory

func key(_ path: String) -> String { path.hasSuffix(".swift") || path.hasSuffix("/") ? path : path + "/" }
let byPath = Dictionary(grouping: config.targets, by: { key($0.path) })
for (p, ts) in byPath where ts.count > 1 { problems.append("path \(p) is claimed by \(ts.map(\.name))") }
for t in config.targets where !FileManager.default.fileExists(atPath: root.appendingPathComponent(t.path).path) {
    problems.append("target \(t.name): path \(t.path) does not exist")
}
var files: [String] = [], documents: [String] = []
if let e = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isSymbolicLinkKey]) {
    for case let url as URL in e {
        let rel = url.standardizedFileURL.path.replacingOccurrences(of: root.path + "/", with: "")
        if rel.hasPrefix(".git") || rel.contains("/.build") || rel.hasPrefix(".build") { e.skipDescendants(); continue }
        if (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true {
            problems.append("symbolic link in the source tree: \(rel)"); continue
        }
        if url.pathExtension == "swift" { files.append(rel) }
        if url.pathExtension == "md" { documents.append(rel) }
    }
}
var assignment: [(file: String, target: Config.Target)] = []
for file in files.sorted() {
    let owners = byPath.filter { $0.key.hasSuffix(".swift") ? file == $0.key : file.hasPrefix($0.key) }.sorted { $0.key.count > $1.key.count }
    guard let target = owners.first?.value.first else { problems.append("unmapped file: \(file)"); continue }
    if target.kind == .excluded { continue }
    assignment.append((file, target))
}

// MARK: 2–4. Scan

let adrDir = value(after: "--adr-dir")
if let adrDir, ((try? FileManager.default.contentsOfDirectory(atPath: adrDir)) ?? []).isEmpty {
    problems.append("cannot read the ADR directory \(adrDir)")
}
// Target names are identities (allow-lists, modules.md, manifest exemptions): they must be unique.
for (name, entries) in Dictionary(grouping: config.targets, by: \.name) where entries.count > 1 {
    problems.append("target name \(name) appears \(entries.count) times in the rules")
}
var exceptionsValid: [Config.Exception] = []
for ex in config.exceptions ?? [] {
    let adrExists = adrDir.map { dir in
        ((try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []).contains { $0.hasPrefix(ex.adr + "-") }
    } ?? false
    if adrExists { exceptionsValid.append(ex) } else { problems.append("exception for \(ex.path) cites ADR \(ex.adr), which does not exist") }
}

func fingerprint(_ text: String) -> String {
    let normalized = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    var h: UInt64 = 0xcbf29ce484222325
    for b in normalized.utf8 { h ^= UInt64(b); h &*= 0x100000001b3 }
    return String(h, radix: 16)
}

let implementedDetectors = Scanner.detectors.union(Measurements.detectors)
for (rule, detectors) in config.rules.sorted(by: { $0.key < $1.key }) {
    for detector in detectors where !implementedDetectors.contains(detector) {
        problems.append("rule \(rule) lists the detector \(detector), which the checker does not implement")
    }
}
for rule in config.productionRules ?? [] where config.rules[rule] == nil {
    problems.append("productionRules lists the production rule \(rule), which rules.json does not define")
}
for target in config.targets {
    for rule in target.rules where config.rules[rule] == nil {
        problems.append("target \(target.name) lists the rule \(rule), which rules.json does not define")
    }
}

/// The rules whose detectors run on a target: the ones it lists, and on every production target the production rules, so
/// that a new target cannot forget them.
func rulesRunning(on target: Config.Target) -> [String] {
    return target.rules + (target.isProduction ? (config.productionRules ?? []).filter { !target.rules.contains($0) } : [])
}

let detectorToRules: (Config.Target) -> [String: [String]] = { target in
    var map: [String: [String]] = [:]
    for rule in rulesRunning(on: target) { for d in config.rules[rule] ?? [] { map[d, default: []].append(rule) } }
    return map
}

var ordinals: [String: Int] = [:]
@MainActor func recordFinding(_ hit: Hit, in file: String, rule: String) {
    if exceptionsValid.contains(where: { file.hasPrefix($0.path) && $0.detector == hit.detector }) { return }
    let base = "\(file)|\(rule)|\(hit.detector)|\(fingerprint(hit.node))"
    let n = ordinals[base, default: 0]; ordinals[base] = n + 1
    findings.append(Finding(key: "\(base)#\(n)", message: "\(file):\(hit.line): \(rule): \(hit.detector): \(hit.detail)"))
}

let legacyTargets = config.targets.filter { $0.kind == .legacy }

let manifestPaths = config.targets.filter { $0.kind == .manifest }.map(\.path)
func packageDirectory(_ manifest: String) -> String { manifest.split(separator: "/").dropLast().joined(separator: "/") }

/// The manifest that owns a path: the nearest `Package.swift` above it, so a nested package is never owned
/// by its parent.
func owningManifest(of path: String) -> String? {
    manifestPaths.filter { let dir = packageDirectory($0); return dir.isEmpty || path.hasPrefix(dir + "/") }
        .max { packageDirectory($0).count < packageDirectory($1).count }
}

/// A manifest may exempt only the legacy targets it owns.
func isLegacyDeclaration(_ name: String, inManifest manifest: String) -> Bool {
    legacyTargets.contains { $0.name == name && owningManifest(of: $0.path) == manifest }
}

for (file, target) in assignment where target.kind != .legacy {
    guard let source = try? String(contentsOf: root.appendingPathComponent(file), encoding: .utf8) else { problems.append("cannot read \(file)"); continue }
    let tree = Parser.parse(source: source)
    let scanner = Scanner(tree: tree, file: file, infrastructureTypes: Set(config.infrastructureTypes))
    scanner.walk(tree)
    func record(rule: String, detector: String, detail: String, node: String, line: Int) {
        recordFinding(Hit(detector: detector, detail: detail, node: node, line: line, packageTarget: nil), in: file, rule: rule)
    }
    let allowed = Set(target.allowedImports + ["Swift"])
    for imp in scanner.imports where !allowed.contains(imp.module) {
        record(rule: "DependencyRule", detector: "import", detail: imp.node, node: imp.node, line: imp.line)
    }
    for imp in scanner.imports where target.requiredImportAccess?[imp.module] == .internal {
        if !["internal", "fileprivate", "private"].contains(imp.access ?? "public") {
            record(rule: "HumbleViews", detector: "importAccess", detail: "\(imp.access ?? "(default public)") import \(imp.module) must be internal",
                   node: (imp.access ?? "") + " " + imp.node, line: imp.line)
        }
    }
    let rulesFor = detectorToRules(target)
    let measured = Measurements.detectors.isDisjoint(with: rulesFor.keys) ? [] : Measurements.hits(of: tree, file: file, searchSteps: searchSteps)
    for hit in scanner.hits + measured {
        // Inside a manifest, the declaration of a legacy target is exempt like its sources (ADR 0012); anything
        // else in the manifest, including package-level settings and new targets, is checked.
        if target.kind == .manifest, let owner = hit.packageTarget, isLegacyDeclaration(owner, inManifest: file) { continue }
        // A manifest runs the manifest detectors only, and a source file never does.
        guard Scanner.manifestDetectors.contains(hit.detector) == (target.kind == .manifest) else { continue }
        for rule in rulesFor[hit.detector] ?? [] { record(rule: rule, detector: hit.detector, detail: hit.detail, node: hit.node, line: hit.line) }
    }
    // A tools version below 6 builds every target without an explicit mode in Swift 5 mode. Only a manifest
    // whose targets are all legacy may keep one.
    if target.kind == .manifest,
       let line = source.split(separator: "\n", maxSplits: 1).first, line.contains("swift-tools-version"),
       let major = Int(line.split(separator: ":").last?.trimmingCharacters(in: .whitespaces).prefix { $0.isNumber } ?? ""), major < 6 {
        let newTargets = scanner.declaredPackageTargets.filter { !isLegacyDeclaration($0, inManifest: file) }
        if !newTargets.isEmpty {
            for rule in rulesFor["swift5Mode"] ?? [] {
                record(rule: rule, detector: "swift5Mode", detail: "swift-tools-version \(major) builds \(newTargets.sorted()) in Swift 5 mode",
                       node: String(line), line: 1)
            }
        }
    }
}

// MARK: Documents: a rule cited by its former number

let citationRules = config.rules.filter { $0.value.contains("ruleNumberCitation") }.keys.sorted()
for path in documents.sorted() where DocumentCitations.isChecked(path) {
    guard let text = try? String(contentsOf: root.appendingPathComponent(path), encoding: .utf8) else { problems.append("cannot read \(path)"); continue }
    for hit in DocumentCitations.hits(in: text, at: path) {
        for rule in citationRules { recordFinding(hit, in: path, rule: rule) }
    }
}

// MARK: 5. modules.md, both directions

let frameworks: Set<String> = ["Glibc", "Darwin", "Dispatch", "Foundation", "Observation", "WebKit", "UIKit", "AppKit", "FoundationModels", "Testing", "SwiftUI", "PDFKit", "QuickLook", "UniformTypeIdentifiers", "Synchronization"]
if let modulesPath = value(after: "--modules") {
    var documented: [String: Set<String>?] = [:]
    let modulesText = (try? String(contentsOfFile: modulesPath, encoding: .utf8)) ?? ""
    if modulesText.isEmpty { problems.append("cannot read \(modulesPath): the modules check has nothing to compare") }
    for line in modulesText.components(separatedBy: "\n") where line.hasPrefix("| `") {
        let cells = line.split(separator: "|", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
        guard cells.count >= 4, let name = cells[1].split(separator: "`").first.map(String.init) else { continue }
        let allowCell = cells[cells.count - 2]
        if allowCell.lowercased().contains("everything above") { documented[name] = .some(nil); continue }
        var allowed = Set(allowCell.components(separatedBy: "`").enumerated().filter { $0.offset % 2 == 1 }.map(\.element))
        for word in allowCell.components(separatedBy: CharacterSet.alphanumerics.inverted) where frameworks.contains(word) { allowed.insert(word) }
        documented[name] = .some(allowed)
    }
    let checked = config.targets.filter(\.isProduction)
    for t in checked {
        let docName = t.docName ?? t.name
        guard let entry = documented[docName] else { problems.append("target \(t.name) is not listed in modules.md"); continue }
        guard let doc = entry else { continue }
        let extra = Set(t.allowedImports).subtracting(doc).subtracting(["Swift", "Foundation"])
        if !extra.isEmpty { problems.append("target \(t.name) allows \(extra.sorted()) which modules.md does not") }
    }
    let known = Set(checked.map { $0.docName ?? $0.name }).union(config.notYetImplemented ?? [])
    for name in documented.keys.sorted() where !known.contains(name) {
        problems.append("modules.md lists \(name), which has no target in rules.json and is not in notYetImplemented")
    }
}

// MARK: 6. Declared package dependencies

if let packages = value(after: "--packages") {
    let byName = Dictionary(config.targets.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })
    for dir in packages.split(separator: ",").map(String.init) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = ["swift", "package", "dump-package", "--package-path", root.appendingPathComponent(dir).path]
        let out = Pipe(); p.standardOutput = out; p.standardError = Pipe()
        do { try p.run() } catch { problems.append("cannot run swift package dump-package for \(dir)"); continue }
        let data = out.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
        guard p.terminationStatus == 0, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let targets = json["targets"] as? [[String: Any]] else { problems.append("cannot read the manifest of \(dir)"); continue }
        // The effective language mode, as SwiftPM evaluated it: the target's setting, else the package's list, else the
        // tools version. Every target that is not a legacy target of this package must build in Swift 6 mode (StrictConcurrency).
        let manifestPath = dir == "." ? "Package.swift" : dir + "/Package.swift"
        let toolsMajor = ((json["toolsVersion"] as? [String: Any])?["_version"] as? String).flatMap { Int($0.prefix { $0.isNumber }) } ?? 6
        let packageModes = (json["swiftLanguageVersions"] as? [String]) ?? (json["swiftLanguageModes"] as? [String]) ?? []
        func major(_ mode: String) -> Int { Int(mode.prefix { $0.isNumber }) ?? 6 }
        for t in targets {
            guard let name = t["name"] as? String else { continue }
            guard let rule = byName[name] else { problems.append("package \(dir) declares target \(name), which rules.json does not know"); continue }
            let isLegacyHere = rule.kind == .legacy && owningManifest(of: rule.path) == manifestPath
            // Every language-mode setting counts, whatever its condition: a Swift 5 mode for one platform is still Swift 5.
            let targetModes = (t["settings"] as? [[String: Any]] ?? []).compactMap { s -> String? in
                ((s["kind"] as? [String: Any])?["swiftLanguageMode"] as? [String: Any])?["_0"] as? String
            }
            let effective = targetModes.map(major).min() ?? (packageModes.isEmpty ? (toolsMajor >= 6 ? 6 : 5) : packageModes.map(major).max() ?? 6)
            if !isLegacyHere, effective < 6 {
                problems.append("package \(dir): target \(name) builds in Swift \(effective) mode, not Swift 6 (StrictConcurrency)")
            }
            let deps = (t["dependencies"] as? [[String: Any]] ?? []).compactMap { dep -> String? in
                for k in ["byName", "target", "product"] { if let a = dep[k] as? [Any], let n = a.first as? String { return n } }
                return nil
            }
            let extra = Set(deps).subtracting(rule.allowedImports)
            if !extra.isEmpty { problems.append("package \(dir): target \(name) depends on \(extra.sorted()), which its rules do not allow") }
        }
    }
}

// MARK: Report

/// The detector of a baseline key, which reads `file|rule|detector|fingerprint#n`, when it is a size, shape or comment
/// detector. Their findings are never baselined (ADR 0021 (e)): they are fixed.
func measurementDetector(ofKey key: String) -> String? {
    let parts = key.split(separator: "|", omittingEmptySubsequences: false)
    return parts.count > 2 && Measurements.detectors.contains(String(parts[2])) ? String(parts[2]) : nil
}

let current = Set(findings.map(\.key))
if CommandLine.arguments.contains("--write-baseline") {
    guard problems.isEmpty else { for p in problems { print("error: \(p)") }; print("refusing to write a baseline while there are problems"); exit(1) }
    let writable = current.filter { measurementDetector(ofKey: $0) == nil }
    do { try JSONEncoder().encode(writable.sorted()).write(to: URL(fileURLWithPath: baselinePath)) } catch { fail("cannot write baseline") }
    print("wrote \(writable.count) entries to \(baselinePath)")
    if writable.count < current.count { print("left out \(current.count - writable.count) findings of the size, shape and comment detectors: they are never baselined") }
    exit(0)
}
guard let baseline = loadBaseline(baselinePath) else { fail("cannot read baseline \(baselinePath)") }
for key in baseline { if let detector = measurementDetector(ofKey: key) { problems.append("baseline entry of the measurement detector \(detector) is refused, fix the finding instead: \(key)") } }
let baselined = Set(baseline.filter { measurementDetector(ofKey: $0) == nil })
let new = findings.filter { !baselined.contains($0.key) }
let stale = baselined.subtracting(current).sorted()
var added: [String] = []
if let againstPath = value(after: "--against") {
    guard let base = loadBaseline(againstPath) else { fail("cannot read base baseline \(againstPath)") }
    added = baselined.subtracting(Set(base)).sorted()
}
for p in problems { print("error: \(p)") }
for f in new { print("error: new violation \(f.message)") }
for s in stale { print("error: baseline entry no longer occurs, remove it: \(s)") }
for a in added { print("error: baseline grew compared with the base branch: \(a)") }
print("checked \(assignment.count) files in \(config.targets.count) targets: \(findings.count) findings, \(baseline.count) baselined, \(new.count) new, \(stale.count) stale, \(added.count) added")
exit(problems.isEmpty && new.isEmpty && stale.isEmpty && added.isEmpty ? 0 : 1)
