import Foundation

// Where a run set of the drafting evaluation (#202) is written, and what says what it is. One folder per invocation, a manifest
// written before the first run and completed after the last, the revision in every run record: a folder never mixes the runs of two
// invocations, and a set that stopped halfway says so instead of leaving files that look like a result.

// MARK: - Errors

enum DraftingError: Error, Equatable, CustomStringConvertible {
    /// PRESTOCV_DRAFT_EVAL_RUNS is not a whole number of at least 1.
    case runs(String)
    /// PRESTOCV_DRAFT_EVAL_ONLY names inputs that do not exist.
    case unknownInputs([String])
    /// The destination already holds files: another run set, or the remains of one.
    case notEmpty(path: String, entries: [String])
    /// The runs are not exactly the ones the manifest announces.
    case incompleteSet([String])

    var description: String {
        switch self {
        case .runs(let value): "PRESTOCV_DRAFT_EVAL_RUNS must be a whole number of at least 1, not \"\(value)\""
        case .unknownInputs(let ids): "PRESTOCV_DRAFT_EVAL_ONLY names inputs that do not exist: \(ids)"
        case .notEmpty(let path, let entries):
            "\(path) is not empty (\(entries.prefix(3).joined(separator: ", "))): a run set gets a folder of its own"
        case .incompleteSet(let problems): "the runs are not the set the manifest announces: \(problems.prefix(5).joined(separator: "; "))"
        }
    }
}

// MARK: - Settings

/// The environment of an invocation.
struct DraftingSettings: Equatable {
    static let defaultRuns = 3

    /// PRESTOCV_DRAFT_EVAL.
    let enabled: Bool
    /// PRESTOCV_DRAFT_EVAL_RUNS.
    let runs: Int
    /// PRESTOCV_DRAFT_EVAL_OUT: the folder of this run set, which must be absent or empty; nil for a new folder in the temporary one.
    let destination: URL?
    /// PRESTOCV_DRAFT_EVAL_REV.
    let revision: String
    /// PRESTOCV_DRAFT_EVAL_ONLY.
    let only: Set<String>

    /// - Throws: `DraftingError.runs` for a number of runs that is not a whole number of at least 1.
    init(environment: [String: String]) throws {
        enabled = Self.isOn(environment["PRESTOCV_DRAFT_EVAL"])
        if let value = environment["PRESTOCV_DRAFT_EVAL_RUNS"] {
            guard let runs = Int(value.trimmingCharacters(in: .whitespaces)), runs >= 1 else { throw DraftingError.runs(value) }
            self.runs = runs
        } else {
            runs = Self.defaultRuns
        }
        destination = environment["PRESTOCV_DRAFT_EVAL_OUT"].flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0) }
        let revision = (environment["PRESTOCV_DRAFT_EVAL_REV"] ?? "").trimmingCharacters(in: .whitespaces)
        self.revision = revision.isEmpty ? "unknown" : revision
        only = Set((environment["PRESTOCV_DRAFT_EVAL_ONLY"] ?? "").split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespaces)
        }.filter { !$0.isEmpty })
    }

    /// Whether the switch is on. Unset, empty, 0, false, no and off are off, in any case: `PRESTOCV_DRAFT_EVAL=0` must not start a
    /// run that needs the model. Any other value is on.
    static func isOn(_ value: String?) -> Bool {
        guard let value = value?.trimmingCharacters(in: .whitespaces).lowercased() else { return false }
        return !["", "0", "false", "no", "off"].contains(value)
    }

    /// The inputs this invocation drafts, in the order of `all`.
    /// - Throws: `DraftingError.unknownInputs` for an id in PRESTOCV_DRAFT_EVAL_ONLY that no input has.
    func inputs(from all: [DraftingInput]) throws -> [DraftingInput] {
        let unknown = only.subtracting(all.map(\.id))
        guard unknown.isEmpty else { throw DraftingError.unknownInputs(unknown.sorted()) }
        return all.filter { only.isEmpty || only.contains($0.id) }
    }

    /// The folder of this run set: the one asked for, else a new one in `temporary`, named after the revision and the time.
    func folder(now: Date, temporary: URL, timeZone: TimeZone = .current) -> URL {
        destination ?? temporary.appendingPathComponent(RunFolder.name(revision: revision, now: now, timeZone: timeZone))
    }
}

// MARK: - Manifest

/// What a run set is, written before its first run and completed after its last.
struct RunManifest: Codable, Equatable {
    let revision: String
    let system: String
    let xcode: String
    /// When the set started, as an ISO 8601 date in UTC.
    let started: String
    let runsPerInput: Int
    /// The inputs this set drafts.
    let inputs: [String]
    /// Every input the evaluation has.
    let allInputs: [String]
    /// The runs written so far; the set is complete when this reaches `expectedRuns`.
    private(set) var completedRuns: Int

    init(revision: String, system: String, xcode: String, started: Date, runsPerInput: Int, inputs: [String], allInputs: [String]) {
        self.revision = revision
        self.system = system
        self.xcode = xcode
        self.started = ISO8601DateFormatter().string(from: started)
        self.runsPerInput = runsPerInput
        self.inputs = inputs
        self.allInputs = allInputs
        completedRuns = 0
    }

    var expectedRuns: Int { runsPerInput * inputs.count }
    var complete: Bool { completedRuns == expectedRuns }
    /// Whether the set drafts fewer inputs than the evaluation has.
    var partial: Bool { inputs.count < allInputs.count }

    func completed(runs: Int) -> RunManifest {
        var manifest = self
        manifest.completedRuns = runs
        return manifest
    }

    /// Why `measured` is not exactly the runs of this set: a run missing, repeated, of another input or of another revision.
    func problems(in measured: [DraftMeasure]) -> [String] {
        var problems: [String] = []
        var counts: [String: Int] = [:]
        for draft in measured {
            counts["\(draft.id) run \(draft.run)", default: 0] += 1
            if draft.revision != revision {
                problems.append("\(draft.id) run \(draft.run) was measured at revision \(draft.revision), not \(revision)")
            }
        }
        var expected: Set<String> = []
        for id in inputs {
            for run in (0..<max(runsPerInput, 0)).map({ $0 + 1 }) {
                let key = "\(id) run \(run)"
                expected.insert(key)
                switch counts[key] ?? 0 {
                case 1: break
                case 0: problems.append("\(key) is missing")
                default: problems.append("\(key) is there \(counts[key] ?? 0) times")
                }
            }
        }
        for key in counts.keys.sorted() where !expected.contains(key) {
            problems.append("\(key) is not part of this set")
        }
        return problems
    }
}

// MARK: - Folder

enum RunFolder {
    /// Makes the folder of a run set.
    /// - Throws: `DraftingError.notEmpty` when it already holds anything: a second invocation must not add to the files of the first,
    ///   whose summary it would then sit beside.
    static func prepare(_ folder: URL) throws {
        let manager = FileManager.default
        if manager.fileExists(atPath: folder.path) {
            let entries = try manager.contentsOfDirectory(atPath: folder.path).sorted()
            guard entries.isEmpty else { throw DraftingError.notEmpty(path: folder.path, entries: entries) }
        } else {
            try manager.createDirectory(at: folder, withIntermediateDirectories: true)
        }
    }

    static func write(_ value: some Encodable, to name: String, in folder: URL) throws {
        try encoder().encode(value).write(to: folder.appendingPathComponent(name), options: .atomic)
    }

    static func writeText(_ text: String, to name: String, in folder: URL) throws {
        try Data(text.utf8).write(to: folder.appendingPathComponent(name), options: .atomic)
    }

    static func read<Value: Decodable>(_ type: Value.Type, named name: String, in folder: URL) throws -> Value {
        try JSONDecoder().decode(type, from: Data(contentsOf: folder.appendingPathComponent(name)))
    }

    /// "draft-<revision>-<yyyyMMdd-HHmmss>": the folder of an invocation that asked for none.
    static func name(revision: String, now: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let safe = String(revision.map { $0.isLetter || $0.isNumber || $0 == "." ? $0 : "-" })
        return "draft-\(safe)-\(formatter.string(from: now))"
    }

    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    // MARK: - GO

    /// The verdict on a run set already written.
    /// - Throws: when manifest.json, summary.json or review.json is missing or does not decode: a set without them is not one.
    static func readiness(of folder: URL) throws -> Readiness {
        let manifest = try read(RunManifest.self, named: "manifest.json", in: folder)
        let summary = try read(DraftSummary.self, named: "summary.json", in: folder)
        let review = try read([ReviewItem].self, named: "review.json", in: folder)
        var adjudication: Adjudication?
        if FileManager.default.fileExists(atPath: folder.appendingPathComponent("adjudication.json").path) {
            adjudication = try read(Adjudication.self, named: "adjudication.json", in: folder)
        }
        return Readiness.verdict(manifest: manifest, summary: summary, review: review, adjudication: adjudication)
    }
}

// MARK: - Xcode

enum XcodeVersion {
    /// "<version> (<build>) at <path of the app>" of the Xcode that owns `developerDirectory`; "unknown" without one.
    static func describe(developerDirectory: URL?) -> String {
        guard let developerDirectory else { return "unknown" }
        let contents = developerDirectory.deletingLastPathComponent()
        let version = value("CFBundleShortVersionString", in: contents.appendingPathComponent("Info.plist")) ?? "unknown"
        let build = value("ProductBuildVersion", in: contents.appendingPathComponent("version.plist")) ?? "unknown"
        return "\(version) (\(build)) at \(contents.deletingLastPathComponent().path)"
    }

    /// The Xcode the run uses: DEVELOPER_DIR when set, else the one `xcode-select` has selected (macOS only), never a fixed path.
    static func developerDirectory(environment: [String: String]) -> URL? {
        if let path = environment["DEVELOPER_DIR"], !path.isEmpty { return URL(fileURLWithPath: path) }
        #if os(macOS)
        return selectedDeveloperDirectory()
        #else
        return nil
        #endif
    }

    private static func value(_ key: String, in file: URL) -> String? {
        guard let data = try? Data(contentsOf: file),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return nil }
        return plist[key] as? String
    }

    #if os(macOS)
    private static func selectedDeveloperDirectory() -> URL? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
        process.arguments = ["-p"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path)
    }
    #endif
}
