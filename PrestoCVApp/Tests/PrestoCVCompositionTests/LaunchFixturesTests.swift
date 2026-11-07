#if DEBUG
import DiagnosticTrace
import Foundation
import Testing
@testable import PrestoCVComposition

/// The launch arguments of a Debug build, parsed once into a typed value (R13: codes, not sentences).
@Suite("The launch fixtures of a Debug build")
struct LaunchFixturesTests {
    private static let program = "/path/to/PrestoCVNext"

    private static func seed(_ files: [String: String]) throws -> String {
        try JSONEncoder().encode(files).base64EncodedString()
    }

    @Test("A launch with no fixture argument keeps the device storage and the gate of the build")
    func plainLaunch() throws {
        let fixtures = try LaunchFixtures.parse([Self.program])
        #expect(fixtures == LaunchFixtures(storage: .device, seed: [:], distribution: nil, unknownArguments: []))
    }

    @Test("A named storage is read as the name")
    func namedStorage() throws {
        let fixtures = try LaunchFixtures.parse([Self.program, "-PrestoCVNextStorage", "relaunch-1"])
        #expect(fixtures.storage == .named("relaunch-1"))
    }

    @Test("The empty storage argument asks for a new folder")
    func emptyStorage() throws {
        #expect(try LaunchFixtures.parse([Self.program, "-PrestoCVNextEmptyStorage"]).storage == .empty)
    }

    @Test("The seed is a map from file name to content, read from its base 64 form")
    func seedFiles() throws {
        let files = ["one.cv.json": "{}", "two.cv.json": "[]"]
        let fixtures = try LaunchFixtures.parse([
            Self.program, "-PrestoCVNextEmptyStorage", "-PrestoCVNextSeed", Self.seed(files),
        ])
        #expect(fixtures.seed == files)
    }

    @Test("Every answer of the distribution is read, and one that is not an answer fails")
    func distribution() throws {
        for answer in DistributionAnswer.allCases {
            let fixtures = try LaunchFixtures.parse([Self.program, "-PrestoCVNextDistribution", answer.rawValue])
            #expect(fixtures.distribution == answer)
        }
        #expect(throws: LaunchFixtures.Failure.unreadableDistribution) {
            try LaunchFixtures.parse([Self.program, "-PrestoCVNextDistribution", "beta"])
        }
    }

    @Test("An unknown fixture argument is ignored and named in the unknown list")
    func unknownArgument() throws {
        let fixtures = try LaunchFixtures.parse([
            Self.program, "-PrestoCVNextTeleport", "-PrestoCVNextStorage", "a", "-AppleLanguages", "(en)",
        ])
        #expect(fixtures.unknownArguments == ["-PrestoCVNextTeleport"])
        #expect(fixtures.storage == .named("a"))
    }

    @Test("Two ways to choose the storage conflict")
    func conflictingStorage() {
        #expect(throws: LaunchFixtures.Failure.conflictingStorage) {
            try LaunchFixtures.parse([Self.program, "-PrestoCVNextEmptyStorage", "-PrestoCVNextStorage", "a"])
        }
    }

    @Test("An argument that needs a value and ends the list fails with its name")
    func missingValue() {
        #expect(throws: LaunchFixtures.Failure.missingValue(argument: "-PrestoCVNextStorage")) {
            try LaunchFixtures.parse([Self.program, "-PrestoCVNextStorage"])
        }
    }

    @Test("A folder name that could leave the folder is refused", arguments: ["", "..", "a/b", "a b", "../x"])
    func invalidName(_ name: String) {
        #expect(throws: LaunchFixtures.Failure.invalidFolderName) {
            try LaunchFixtures.parse([Self.program, "-PrestoCVNextStorage", name])
        }
    }

    @Test("A seed that is not base 64 JSON, or names a file outside the CV files, is refused")
    func unreadableSeed() throws {
        #expect(throws: LaunchFixtures.Failure.unreadableSeed) {
            try LaunchFixtures.parse([Self.program, "-PrestoCVNextEmptyStorage", "-PrestoCVNextSeed", "not base 64"])
        }
        #expect(throws: LaunchFixtures.Failure.unreadableSeed) {
            try LaunchFixtures.parse([
                Self.program, "-PrestoCVNextEmptyStorage", "-PrestoCVNextSeed", Self.seed(["../escape.cv.json": "{}"]),
            ])
        }
        #expect(throws: LaunchFixtures.Failure.unreadableSeed) {
            try LaunchFixtures.parse([
                Self.program, "-PrestoCVNextEmptyStorage", "-PrestoCVNextSeed", Self.seed(["notes.txt": "x"]),
            ])
        }
    }

    @Test("A seed needs a folder of its own: it never goes into the device storage")
    func seedWithoutFolder() throws {
        #expect(throws: LaunchFixtures.Failure.seedWithoutFolder) {
            try LaunchFixtures.parse([Self.program, "-PrestoCVNextSeed", Self.seed(["a.cv.json": "{}"])])
        }
    }

    // MARK: Where the fixtures put the files

    private static let device = AppPaths(
        root: URL(filePath: "/support/PrestoCVNext", directoryHint: .isDirectory),
        temporary: URL(filePath: "/tmp/t", directoryHint: .isDirectory)
    )
    private static let fresh = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()

    @Test("The device storage keeps the paths of the device")
    func deviceStorage() {
        #expect(LaunchFixtures().paths(device: Self.device, fresh: Self.fresh) == Self.device)
    }

    @Test("A named storage is a folder of that name under the temporary folder, the same on every launch")
    func namedPaths() {
        var fixtures = LaunchFixtures()
        fixtures.storage = .named("relaunch-1")
        let paths = fixtures.paths(device: Self.device, fresh: UUID())
        #expect(paths.root.path == "/tmp/t/PrestoCVNextFixture-relaunch-1")
        #expect(paths.temporary == Self.device.temporary)
    }

    @Test("The empty storage is a new folder of its own on each launch")
    func emptyPaths() {
        var fixtures = LaunchFixtures()
        fixtures.storage = .empty
        #expect(fixtures.paths(device: Self.device, fresh: Self.fresh).root.path
            == "/tmp/t/PrestoCVNextFixture-00000000-0000-0000-0000-000000000001")
    }

    @Test("The seed is written as files in the store folder, which it makes")
    func writesTheSeed() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("Seed-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: base) }
        var fixtures = LaunchFixtures()
        fixtures.seed = ["a.cv.json": "first", "b.cv.json": "second"]

        try fixtures.writeSeed(into: base.appendingPathComponent("Store", isDirectory: true))

        #expect(try String(contentsOf: base.appendingPathComponent("Store/a.cv.json"), encoding: .utf8) == "first")
        #expect(try String(contentsOf: base.appendingPathComponent("Store/b.cv.json"), encoding: .utf8) == "second")
    }

    @Test("A seed that cannot be written fails with a typed error")
    func seedUnwritable() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("Seed-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let file = base.appendingPathComponent("file")
        try Data("x".utf8).write(to: file)
        var fixtures = LaunchFixtures()
        fixtures.seed = ["a.cv.json": "x"]

        #expect(throws: LaunchFixtures.Failure.seedUnwritable) {
            try fixtures.writeSeed(into: file.appendingPathComponent("Store", isDirectory: true))
        }
    }
}
#endif
