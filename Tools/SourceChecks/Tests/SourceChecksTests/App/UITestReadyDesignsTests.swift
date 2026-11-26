import Testing
import Foundation

// MARK: - The bundled designs in the UI tests of the new stack

/// A launch over an empty folder of the fixture is a first install: before its first screen the app checks every bundled
/// design by rendering it, three designs in each of their font schemes, which takes seconds on every launch (#561). A UI
/// test that is not about the designs or the first launch passes `-PrestoCVNextReadyDesigns`, and the app accepts the
/// bundled designs without rendering them. So every launch over a folder of the fixture passes it, launch by launch
/// (`FixtureLaunches`), unless its file is one of those listed here, which keep the real check on purpose and never pass it.
@Suite("UI tests of the new stack - the bundled designs are accepted without their renders")
struct UITestReadyDesignsTests {

    // MARK: - The rule

    private static let folder = "PrestoCVNextUITests/"
    private static let readyDesigns = #""-PrestoCVNextReadyDesigns""#
    private static let storageArguments = [#""-PrestoCVNextEmptyStorage""#, #""-PrestoCVNextStorage""#]

    /// The files that keep the real check of the bundled designs, and why.
    private static let realCheck: [String: String] = [
        "PrestoCVNextUITests/FirstRunUITests.swift": "the first launch, with its wait for the designs, is what it tests",
        "PrestoCVNextUITests/LaunchUITests.swift": "the launch itself is what it tests",
        "PrestoCVNextUITests/ExportLookUITests.swift": "every bundled design passes the real check before a person picks it",
        "PrestoCVNextUITests/FailedCompositionUITests.swift": "the launch fails at the folder, before the designs",
    ]

    private static func code(_ path: String) throws -> String {
        SwiftCode(try Repository.text(path)).code.joined(separator: "\n")
    }

    /// The files of the target that launch over a folder of the fixture
    private static func launchingFiles() throws -> [String] {
        try Repository.presentFiles()
            .filter { $0.hasPrefix(folder) && $0.hasSuffix(".swift") }
            .filter { path in
                let code = try Self.code(path)
                return storageArguments.contains { code.contains($0) }
            }
    }

    // MARK: - Tests

    @Test("the check finds the UI tests that launch over a folder of the fixture, so a wrong folder does not pass it")
    func checkFindsTheLaunches() throws {
        let files = try Self.launchingFiles()

        #expect(files.count >= 15, "Only \(files.count) files under \(Self.folder) launch over a folder of the fixture")
        #expect(files.contains("PrestoCVNextUITests/EditorDetailsUITests.swift"))
        #expect(Set(Self.realCheck.keys).isSubset(of: Set(files)), "A file listed for the real check no longer launches")
    }

    @Test("every launch of a UI test that is not about the designs or the first launch accepts the bundled designs")
    func everyOtherLaunchAcceptsTheDesigns() throws {
        let problems = try Self.launchingFiles()
            .filter { Self.realCheck[$0] == nil }
            .flatMap { path in FixtureLaunches(try Repository.text(path)).problems().map { "\(path) \($0)" } }

        #expect(problems.isEmpty, "Pass \(Self.readyDesigns), or list the file with its reason in realCheck: \(problems)")
    }

    @Test("the UI tests that keep the real check of the bundled designs never skip it")
    func theRealCheckStays() throws {
        let skipping = try Self.realCheck.keys.sorted().filter { try Self.code($0).contains(Self.readyDesigns) }

        #expect(skipping.isEmpty, "These files keep the real check of the designs: \(skipping)")
    }

    // MARK: - The check on sources made up for it

    @Test("a second launch of a file that leaves the argument out is found, though the first one passes it")
    func secondLaunchWithoutTheArgument() {
        let source = #"""
            func testFirst() {
                app.launchArguments += ["-PrestoCVNextEmptyStorage", "-PrestoCVNextReadyDesigns"]
            }
            func testSecond() {
                app.launchArguments += [
                    "-AppleLanguages", "(en)", "-PrestoCVNextStorage", folder,
                ]
            }
            """#

        #expect(FixtureLaunches(source).problems() == ["line 5: a launch over a folder without -PrestoCVNextReadyDesigns"])
    }

    @Test("a folder kept in a value is read through the launches that name it")
    func folderInAValue() {
        let passing = #"""
            private func launch(traced: Bool = false, storage: [String] = ["-PrestoCVNextEmptyStorage"]) {
                app.launchArguments += storage + [
                    "-PrestoCVNextReadyDesigns", "-PrestoCVNextSeed", seed,
                ]
                if traced { app.launchArguments += ["-PrestoCVNextTraceRuns"] }
            }
            func testAgain() {
                let storage = ["-PrestoCVNextStorage", "again-\(UUID().uuidString)"]
                launch(storage: storage)
            }
            """#
        let failing = #"""
            func testIndirect() {
                let fixture = [
                    "-PrestoCVNextEmptyStorage",
                ]
                app.launchArguments += fixture + ["-PrestoCVNextSeed", seed]
            }
            """#

        #expect(FixtureLaunches(passing).problems().isEmpty)
        #expect(FixtureLaunches(failing).problems() == [
            "line 3: a folder in `fixture`, which a launch of this file uses without -PrestoCVNextReadyDesigns",
        ])
    }

    @Test("a folder is followed into the values it is copied or added to and into the parameters it is passed to")
    func folderThroughOtherValues() {
        let copied = #"""
            let storage = ["-PrestoCVNextStorage", folder]
            let copied = storage
            app.launchArguments += storage + ["-PrestoCVNextReadyDesigns"]
            app.launchArguments += copied
            """#
        let added = #"""
            let storage = ["-PrestoCVNextStorage", folder]
            var arguments = ["-AppleLanguages", "(en)"]
            arguments.append(contentsOf: storage)
            app.launchArguments += arguments
            """#
        let passed = #"""
            func launch(arguments: [String]) {
                app.launchArguments += arguments
            }
            func testPassed() {
                let fixture = [
                    "-PrestoCVNextStorage", folder,
                ]
                launch(arguments: fixture)
            }
            """#
        let passing = #"""
            func launch(with arguments: [String]) {
                app.launchArguments += arguments + ["-PrestoCVNextReadyDesigns"]
            }
            func testPassing() {
                let storage = ["-PrestoCVNextStorage", folder]
                let all = storage + ["-AppleLanguages", "(en)"]
                launch(with: all)
            }
            """#

        #expect(FixtureLaunches(copied).problems() == [
            "line 1: a folder in `storage`, which a launch of this file uses through `copied` without -PrestoCVNextReadyDesigns",
        ])
        #expect(FixtureLaunches(added).problems() == [
            "line 1: a folder in `storage`, which a launch of this file uses through `arguments` without -PrestoCVNextReadyDesigns",
        ])
        #expect(FixtureLaunches(passed).problems() == [
            "line 6: a folder in `fixture`, which a launch of this file uses through `arguments` without -PrestoCVNextReadyDesigns",
        ])
        #expect(FixtureLaunches(passing).problems().isEmpty)
    }

    @Test("a folder in a value used where the check cannot follow it fails the check, though its other launches pass")
    func folderBeyondTheCheck() {
        let source = #"""
            let storage = ["-PrestoCVNextStorage", folder]
            app.launchArguments += storage + ["-PrestoCVNextReadyDesigns"]
            let extended = Self.extended(storage)
            app.launchArguments += extended
            """#

        #expect(FixtureLaunches(source).problems() == [
            "line 3: a folder in `storage` goes where the check cannot follow it",
        ])
    }

    @Test("a folder before a colon that names nothing there, as a dictionary key or in a branch, fails the check")
    func folderBeforeAColon() {
        let key = #"""
            func launch(values: [[String]: Int]) {
                app.launchArguments += values.keys.flatMap { $0 }
            }
            func testKey() {
                let storage = ["-PrestoCVNextStorage", folder]
                app.launchArguments += storage + ["-PrestoCVNextReadyDesigns"]
                launch(values: [storage: 1])
            }
            """#
        let branch = #"""
            func launch(arguments: [String]) {
                app.launchArguments += arguments
            }
            func testBranch() {
                let storage = ["-PrestoCVNextStorage", folder]
                app.launchArguments += storage + ["-PrestoCVNextReadyDesigns"]
                launch(arguments: traced ? storage: [])
            }
            """#

        #expect(FixtureLaunches(key).problems() == ["line 7: a folder in `storage` goes where the check cannot follow it"])
        #expect(FixtureLaunches(branch).problems() == ["line 7: a folder in `storage` goes where the check cannot follow it"])
    }

    @Test("a folder the check cannot tie to a launch of its file fails the check, so no launch escapes it")
    func folderOutOfSight() {
        let source = #"""
            static func fixture() -> [String] { ["-PrestoCVNextEmptyStorage"] }
            static let shared = ["-PrestoCVNextStorage", "shared"]
            func testElsewhere() {
                app.launchArguments += Self.fixture() + ["-PrestoCVNextReadyDesigns"]
                XCTAssertEqual(app.launchArguments.first, "-PrestoCVNextEmptyStorage")
            }
            """#

        #expect(FixtureLaunches(source).problems() == [
            "line 1: a folder the check cannot tie to a launch of this file",
            "line 2: a folder in `shared`, which no launch of this file names",
            "line 5: a folder the check cannot tie to a launch of this file",
        ])
    }

    @Test("an argument in a comment neither launches nor passes")
    func commentsDoNotCount() {
        let source = #"""
            // app.launchArguments += ["-PrestoCVNextEmptyStorage"]
            app.launchArguments += ["-PrestoCVNextEmptyStorage"] // "-PrestoCVNextReadyDesigns"
            """#

        #expect(FixtureLaunches(source).problems() == ["line 2: a launch over a folder without -PrestoCVNextReadyDesigns"])
    }
}
