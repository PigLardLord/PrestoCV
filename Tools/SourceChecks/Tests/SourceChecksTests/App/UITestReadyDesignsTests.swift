import Testing
import Foundation

// MARK: - The bundled designs in the UI tests of the new stack

/// A launch over an empty folder of the fixture is a first install: before its first screen the app checks every bundled
/// design by rendering it, three designs in each of their font schemes, which takes seconds on every launch (#561). A UI
/// test that is not about the designs or the first launch passes `-PrestoCVNextReadyDesigns`, and the app accepts the
/// bundled designs without rendering them. So every file of the target that launches over a folder of the fixture passes
/// it, unless it is one of the files listed here, which keep the real check on purpose and never pass it.
///
/// The check reads the code of the files without their comments, with the text of their strings (`SwiftCode.code`): the
/// arguments are string literals.
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

    @Test("the check finds the UI tests that launch over a folder of the fixture, so a wrong folder or name does not pass it")
    func checkFindsTheLaunches() throws {
        let files = try Self.launchingFiles()

        #expect(files.count >= 15, "Only \(files.count) files under \(Self.folder) launch over a folder of the fixture")
        #expect(files.contains("PrestoCVNextUITests/EditorDetailsUITests.swift"))
        #expect(Set(Self.realCheck.keys).isSubset(of: Set(files)), "A file listed for the real check no longer launches")
    }

    @Test("every UI test that is not about the designs or the first launch accepts the bundled designs without their renders")
    func everyOtherLaunchAcceptsTheDesigns() throws {
        let missing = try Self.launchingFiles()
            .filter { Self.realCheck[$0] == nil }
            .filter { try !Self.code($0).contains(Self.readyDesigns) }

        #expect(missing.isEmpty, "Pass \(Self.readyDesigns), or list the file with its reason in realCheck: \(missing)")
    }

    @Test("the UI tests that keep the real check of the bundled designs never skip it")
    func theRealCheckStays() throws {
        let skipping = try Self.realCheck.keys.sorted().filter { try Self.code($0).contains(Self.readyDesigns) }

        #expect(skipping.isEmpty, "These files keep the real check of the designs: \(skipping)")
    }
}
