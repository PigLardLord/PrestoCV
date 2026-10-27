import Testing
import Foundation
import CVGeneratorAI

// Where a run set of the drafting evaluation is written, and what says what it is: one folder per invocation, a manifest written
// first and completed last, the settings read from the environment without a surprise (`PRESTOCV_DRAFT_EVAL=0` is off).

@Suite("Drafting evaluation: the run folder")
struct DraftingRunFolderTests {
    // MARK: - The switch

    @Test("The switch is off for unset, empty, 0, false, no and off in any case, and on for anything else", arguments: SwitchCase.all)
    func isOn(_ item: SwitchCase) {
        #expect(DraftingSettings.isOn(item.value) == item.on, "\(item)")
    }

    // MARK: - The settings

    @Test("With no variable, the evaluation is off and asks for three runs into a new folder")
    func defaults() throws {
        let settings = try DraftingSettings(environment: [:])

        #expect(!settings.enabled)
        #expect(settings.runs == 3)
        #expect(settings.destination == nil)
        #expect(settings.revision == "unknown")
        #expect(settings.only.isEmpty)
    }

    @Test("The variables are read as they are named")
    func variables() throws {
        let settings = try DraftingSettings(environment: [
            "PRESTOCV_DRAFT_EVAL": "1", "PRESTOCV_DRAFT_EVAL_RUNS": " 5 ", "PRESTOCV_DRAFT_EVAL_OUT": "/tmp/run-set",
            "PRESTOCV_DRAFT_EVAL_REV": " abc1234 ", "PRESTOCV_DRAFT_EVAL_ONLY": "en-plain, it-traps,,",
        ])

        #expect(settings.enabled)
        #expect(settings.runs == 5)
        #expect(settings.destination == URL(fileURLWithPath: "/tmp/run-set"))
        #expect(settings.revision == "abc1234")
        #expect(settings.only == ["en-plain", "it-traps"])
    }

    @Test("The switch off with 0 or false starts no run")
    func switchedOff() throws {
        for value in ["0", "false", "FALSE", "no", "off", ""] {
            #expect(try !DraftingSettings(environment: ["PRESTOCV_DRAFT_EVAL": value]).enabled, "\(value)")
        }
    }

    @Test("A number of runs that is not a whole number of at least 1 is an error", arguments: ["0", "-2", "x", "", "1.5", "three"])
    func badRuns(_ value: String) {
        #expect(throws: DraftingError.runs(value)) {
            try DraftingSettings(environment: ["PRESTOCV_DRAFT_EVAL_RUNS": value])
        }
    }

    @Test("An empty destination is no destination")
    func emptyDestination() throws {
        #expect(try DraftingSettings(environment: ["PRESTOCV_DRAFT_EVAL_OUT": ""]).destination == nil)
    }

    // MARK: - The inputs

    @Test("Without PRESTOCV_DRAFT_EVAL_ONLY every input is drafted, in order")
    func allInputs() throws {
        let all = try DraftingInputs.all()

        let inputs = try DraftingSettings(environment: [:]).inputs(from: all)

        #expect(inputs.map(\.id) == all.map(\.id))
    }

    @Test("PRESTOCV_DRAFT_EVAL_ONLY keeps the named inputs, in the order of the evaluation")
    func someInputs() throws {
        let inputs = try DraftingSettings(environment: ["PRESTOCV_DRAFT_EVAL_ONLY": "it-plain,en-plain"]).inputs(from: DraftingInputs.all())

        #expect(inputs.map(\.id) == ["en-plain", "it-plain"])
    }

    @Test("PRESTOCV_DRAFT_EVAL_ONLY with an input that does not exist is an error, not an empty run")
    func unknownInput() throws {
        let settings = try DraftingSettings(environment: ["PRESTOCV_DRAFT_EVAL_ONLY": "en-plain,nope,also-not"])
        let all = try DraftingInputs.all()

        #expect(throws: DraftingError.unknownInputs(["also-not", "nope"])) { try settings.inputs(from: all) }
    }

    // MARK: - The folder

    @Test("An invocation that names no folder gets a new one named after the revision and the time")
    func defaultFolder() throws {
        let settings = try DraftingSettings(environment: ["PRESTOCV_DRAFT_EVAL_REV": "feature/a b"])
        let temporary = URL(fileURLWithPath: "/tmp/scratch")
        let now = Date(timeIntervalSince1970: 1_792_000_000)

        let folder = settings.folder(now: now, temporary: temporary, timeZone: TimeZone(identifier: "UTC") ?? .gmt)

        #expect(folder == temporary.appendingPathComponent("draft-feature-a-b-20261014-174640"))
    }

    @Test("The name of a folder follows the time zone it is asked for")
    func folderTimeZone() {
        let now = Date(timeIntervalSince1970: 1_792_000_000)

        #expect(RunFolder.name(revision: "abc", now: now, timeZone: TimeZone(secondsFromGMT: 7200) ?? .gmt) == "draft-abc-20261014-194640")
    }

    @Test("A folder that was named is the one used")
    func namedFolder() throws {
        let settings = try DraftingSettings(environment: ["PRESTOCV_DRAFT_EVAL_OUT": "/tmp/mine"])

        #expect(settings.folder(now: Date(), temporary: URL(fileURLWithPath: "/tmp/scratch")) == URL(fileURLWithPath: "/tmp/mine"))
    }

    @Test("A folder is made when it is absent, with the folders above it")
    func prepareMakes() throws {
        let root = try Self.scratch()
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent("a/b/run")

        try RunFolder.prepare(folder)

        #expect(FileManager.default.fileExists(atPath: folder.path))
    }

    @Test("A folder that exists and is empty is used")
    func prepareEmpty() throws {
        let root = try Self.scratch()
        defer { try? FileManager.default.removeItem(at: root) }

        try RunFolder.prepare(root)
    }

    @Test("A folder that holds anything is an error: a run set never lands beside the files of another")
    func prepareNotEmpty() throws {
        let root = try Self.scratch()
        defer { try? FileManager.default.removeItem(at: root) }
        try RunFolder.writeText("old", to: "summary.json", in: root)
        try RunFolder.writeText("old", to: "en-plain-1.json", in: root)

        #expect(throws: DraftingError.notEmpty(path: root.path, entries: ["en-plain-1.json", "summary.json"])) {
            try RunFolder.prepare(root)
        }
        #expect(try String(contentsOf: root.appendingPathComponent("summary.json"), encoding: .utf8) == "old")
    }

    // MARK: - The manifest

    @Test("A manifest is written first, with no run done, and completed after the last")
    func manifestLifecycle() {
        let manifest = DraftMeasures.manifest(["en-plain", "it-plain"], runs: 3)

        #expect(manifest.expectedRuns == 6)
        #expect(manifest.completedRuns == 0)
        #expect(!manifest.complete)
        #expect(manifest.completed(runs: 6).complete)
        #expect(manifest.completed(runs: 6).completedRuns == 6)
        #expect(manifest.completedRuns == 0)
        #expect(!manifest.completed(runs: 5).complete)
    }

    @Test("A manifest of fewer inputs than the evaluation has is partial")
    func manifestPartial() {
        #expect(!DraftMeasures.manifest(["en-plain"], all: ["en-plain"]).partial)
        #expect(DraftMeasures.manifest(["en-plain"], all: ["en-plain", "it-plain"]).partial)
    }

    @Test("A manifest records when the set started, in UTC")
    func manifestStarted() {
        #expect(DraftMeasures.manifest(["en-plain"]).started == "2026-10-14T17:46:40Z")
    }

    @Test("The problems of a set are the runs missing, repeated, foreign or of another revision")
    func manifestProblems() throws {
        let manifest = DraftMeasures.manifest(["en-plain", "it-plain"], runs: 2)
        let complete = try DraftMeasures.set(["en-plain", "it-plain"], runs: 2)
        let foreign = try DraftMeasures.measure("de-plain")
        let stale = try DraftMeasures.measure("en-plain", revision: "other")

        #expect(manifest.problems(in: complete).isEmpty)
        #expect(manifest.problems(in: Array(complete.dropFirst())) == ["en-plain run 1 is missing"])
        #expect(manifest.problems(in: complete + [complete[0]]) == ["en-plain run 1 is there 2 times"])
        #expect(manifest.problems(in: complete + [foreign]) == ["de-plain run 1 is not part of this set"])
        #expect(manifest.problems(in: [stale]).first == "en-plain run 1 was measured at revision other, not abc1234")
    }

    // MARK: - The files

    @Test("A value is written and read back, and a file is replaced whole")
    func writeAndRead() throws {
        let root = try Self.scratch()
        defer { try? FileManager.default.removeItem(at: root) }
        let manifest = DraftMeasures.manifest(["en-plain"])

        try RunFolder.write(manifest, to: "manifest.json", in: root)
        try RunFolder.write(manifest.completed(runs: 1), to: "manifest.json", in: root)

        #expect(try RunFolder.read(RunManifest.self, named: "manifest.json", in: root) == manifest.completed(runs: 1))
    }

    @Test("A file of text is written as it is")
    func writeText() throws {
        let root = try Self.scratch()
        defer { try? FileManager.default.removeItem(at: root) }

        try RunFolder.writeText("HARD FINDINGS\nline 2\n", to: "summary.txt", in: root)

        #expect(try String(contentsOf: root.appendingPathComponent("summary.txt"), encoding: .utf8) == "HARD FINDINGS\nline 2\n")
    }

    @Test("The files are readable by a person: sorted keys, indented, slashes as they are")
    func readable() throws {
        let root = try Self.scratch()
        defer { try? FileManager.default.removeItem(at: root) }

        try RunFolder.write(DraftMeasures.manifest(["en-plain"], all: ["en-plain", "a/b"]), to: "manifest.json", in: root)
        let text = try String(contentsOf: root.appendingPathComponent("manifest.json"), encoding: .utf8)
        let first = try #require(text.range(of: "\"allInputs\""))
        let last = try #require(text.range(of: "\"xcode\""))

        #expect(text.contains("\n  \"allInputs\""))
        #expect(first.lowerBound < last.lowerBound)
        #expect(text.contains("\"a/b\""))
    }

    // MARK: - The verdict of a folder

    @Test("A folder of a reviewed set is GO, and without its adjudication it is not")
    func readiness() throws {
        let root = try Self.scratch()
        defer { try? FileManager.default.removeItem(at: root) }
        let scenario = try Scenario.make(runs: 2, tweak: DraftMeasures.tweak(Scenario.reviewed, for: "en-plain")).adjudicated()
        try Self.write(scenario, to: root)

        #expect(try RunFolder.readiness(of: root) == .go)

        try FileManager.default.removeItem(at: root.appendingPathComponent("adjudication.json"))

        #expect(try RunFolder.readiness(of: root).reasons.contains { $0.contains("nobody has adjudicated them") })
    }

    @Test("A folder without its manifest, summary or review is no run set")
    func readinessNeedsTheFiles() throws {
        let scenario = try Scenario.make()
        for missing in ["manifest.json", "summary.json", "review.json"] {
            let root = try Self.scratch()
            defer { try? FileManager.default.removeItem(at: root) }
            try Self.write(scenario, to: root)
            try FileManager.default.removeItem(at: root.appendingPathComponent(missing))

            #expect(throws: (any Error).self, "\(missing)") { try RunFolder.readiness(of: root) }
        }
    }

    @Test("A folder whose manifest was never completed is not GO")
    func readinessOfAnInterruptedSet() throws {
        let root = try Self.scratch()
        defer { try? FileManager.default.removeItem(at: root) }
        var scenario = try Scenario.make(runs: 2)
        scenario.manifest = DraftMeasures.manifest(["en-plain", "it-plain"], runs: 2)
        try Self.write(scenario, to: root)

        #expect(try RunFolder.readiness(of: root).reasons.contains { $0.contains("the run set is not complete: 0 of 4 runs") })
    }

    // MARK: - Xcode

    @Test("The version of Xcode is read from the Xcode that owns the developer directory")
    func xcodeVersion() throws {
        let root = try Self.scratch()
        defer { try? FileManager.default.removeItem(at: root) }
        let app = root.appendingPathComponent("Xcode-test.app")
        let contents = app.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents.appendingPathComponent("Developer"), withIntermediateDirectories: true)
        try Self.plist(["CFBundleShortVersionString": "27.0"], to: contents.appendingPathComponent("Info.plist"))
        try Self.plist(["ProductBuildVersion": "27A5001a"], to: contents.appendingPathComponent("version.plist"))

        let described = XcodeVersion.describe(developerDirectory: contents.appendingPathComponent("Developer"))

        #expect(described == "27.0 (27A5001a) at \(app.path)")
    }

    @Test("An Xcode that cannot be read, or none, is unknown, not a guess")
    func xcodeUnknown() throws {
        let root = try Self.scratch()
        defer { try? FileManager.default.removeItem(at: root) }

        #expect(XcodeVersion.describe(developerDirectory: nil) == "unknown")
        #expect(XcodeVersion.describe(developerDirectory: root.appendingPathComponent("X.app/Contents/Developer"))
            == "unknown (unknown) at \(root.appendingPathComponent("X.app").path)")
    }

    @Test("DEVELOPER_DIR names the Xcode when it is set, whatever is selected")
    func developerDirectory() {
        #expect(XcodeVersion.developerDirectory(environment: ["DEVELOPER_DIR": "/Applications/Xcode-x.app/Contents/Developer"])
            == URL(fileURLWithPath: "/Applications/Xcode-x.app/Contents/Developer"))
    }

    #if os(macOS)
    @Test("Without DEVELOPER_DIR the Xcode that is selected is used")
    func selectedDeveloperDirectory() {
        let directory = XcodeVersion.developerDirectory(environment: [:])

        #expect(directory != nil)
        #expect(directory?.path.hasPrefix("/") == true)
    }
    #endif

    // MARK: - Helpers

    /// A new empty folder in the temporary one; the test removes it.
    static func scratch() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("drafting-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// The files an evaluation writes for a run set.
    static func write(_ scenario: Scenario, to folder: URL) throws {
        try RunFolder.write(scenario.manifest, to: "manifest.json", in: folder)
        try RunFolder.write(scenario.summary, to: "summary.json", in: folder)
        try RunFolder.write(scenario.review, to: "review.json", in: folder)
        if let adjudication = scenario.adjudication {
            try RunFolder.write(adjudication, to: "adjudication.json", in: folder)
        }
    }

    private static func plist(_ values: [String: String], to file: URL) throws {
        try PropertyListSerialization.data(fromPropertyList: values, format: .xml, options: 0).write(to: file)
    }
}

// MARK: - Cases

struct SwitchCase: Sendable, CustomTestStringConvertible {
    let value: String?
    let on: Bool

    var testDescription: String { "\(value.map { "\"\($0)\"" } ?? "unset") is \(on ? "on" : "off")" }

    static let all: [SwitchCase] = [
        SwitchCase(value: nil, on: false), SwitchCase(value: "", on: false), SwitchCase(value: " ", on: false),
        SwitchCase(value: "0", on: false), SwitchCase(value: "false", on: false), SwitchCase(value: "False", on: false),
        SwitchCase(value: "NO", on: false), SwitchCase(value: "off", on: false), SwitchCase(value: " 0 ", on: false),
        SwitchCase(value: "1", on: true), SwitchCase(value: "true", on: true), SwitchCase(value: "yes", on: true),
        SwitchCase(value: "on", on: true), SwitchCase(value: "2", on: true), SwitchCase(value: "anything", on: true),
    ]
}
