import DiagnosticLogging
import DiagnosticLoggingTestSupport
import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Android)
import Android
#elseif canImport(Darwin)
import Darwin
#endif
@testable import PrestoCVLegacyLeftovers
import PrestoCVWorkflowPorts
import Testing

@Suite("The cleanup of what the released app left")
struct LegacyLeftoversAdapterTests {
    // MARK: What goes

    @Test("the design files, their cache and the export settings go")
    func theThreeGo() async throws {
        let world = try World()
        defer { world.remove() }
        try world.fillLeftovers()

        await world.adapter.clean()

        #expect(world.exists(world.paths.templates) == false)
        #expect(world.exists(world.paths.templateCache) == false)
        #expect(world.exists(world.paths.exportPreferences) == false)
        #expect(world.logger.entries.isEmpty)
    }

    @Test("the CVs, their Quarantine, the unsaved edits and an unrelated file stay")
    func everythingElseStays() async throws {
        let world = try World()
        defer { world.remove() }
        try world.fillLeftovers()
        let kept = [
            "PrestoCV/CVs/cv_A.json", "PrestoCV/CVs/Quarantine/cv_B.json", "PrestoCV/UnsavedEdits/edit_C.json",
            "PrestoCV/StoredUnsavedEdits/edit_D.json", "PrestoCV/notes.txt", "PrestoCVNext/Store/cv_E.json",
            "Diagnostics/run.json", "Other/file.txt",
        ]
        for path in kept { try world.write("kept", at: path) }

        await world.adapter.clean()

        for path in kept {
            #expect(try world.read(path) == "kept", "\(path) stays")
        }
    }

    @Test("a missing path is fine, and a second cleanup changes nothing")
    func missingPathsAreFine() async throws {
        let world = try World()
        defer { world.remove() }
        try world.write("kept", at: "PrestoCV/CVs/cv_A.json")

        await world.adapter.clean()
        try world.fillLeftovers()
        await world.adapter.clean()
        await world.adapter.clean()

        #expect(world.exists(world.paths.templates) == false)
        #expect(try world.read("PrestoCV/CVs/cv_A.json") == "kept")
        #expect(world.logger.entries.isEmpty)
    }

    @Test("a link at one of the names is removed as the link, never its target")
    func aLinkGoesAlone() async throws {
        let world = try World()
        defer { world.remove() }
        try world.write("mine", at: "Elsewhere/Templates/design.json")
        try world.write("mine", at: "Elsewhere/cache.txt")
        try world.write("mine", at: "Elsewhere/prefs.json")
        try world.link(world.paths.templates, to: "Elsewhere/Templates")
        try world.link(world.paths.templateCache, to: "Elsewhere/Templates")
        try world.link(world.paths.exportPreferences, to: "Elsewhere/prefs.json")

        await world.adapter.clean()

        #expect(world.isLink(world.paths.templates) == false && world.exists(world.paths.templates) == false)
        #expect(world.exists(world.paths.templateCache) == false)
        #expect(world.exists(world.paths.exportPreferences) == false)
        #expect(try world.read("Elsewhere/Templates/design.json") == "mine")
        #expect(try world.read("Elsewhere/prefs.json") == "mine")
        #expect(world.logger.entries.isEmpty)
    }

    @Test("a link as the folder of the design files and the settings is not followed: they stay, the cache goes, and it is logged")
    func aLinkedParentIsSkipped() async throws {
        let world = try World()
        defer { world.remove() }
        try world.write("mine", at: "Elsewhere/Templates/design.json")
        try world.write("mine", at: "Elsewhere/export-preferences.json")
        try world.write("cache", at: "TemplateCache/professional.png")
        try world.link(world.support.appendingPathComponent("PrestoCV"), to: "Elsewhere")

        await world.adapter.clean()

        #expect(try world.read("Elsewhere/Templates/design.json") == "mine")
        #expect(try world.read("Elsewhere/export-preferences.json") == "mine")
        #expect(world.exists(world.paths.templateCache) == false)
        let entries = world.logger.entries("legacy.leftovers.notRemoved")
        #expect(entries.count == 2)
        #expect(entries.map { $0.value("of") } == [.token("templates"), .token("exportPreferences")])
        #expect(entries.allSatisfy { $0.value("error") == .error(type: "LegacyLeftoverError", code: "linkedFolder") })
        #expect(entries.allSatisfy { !$0.line.contains(world.support.lastPathComponent) }, "never a path")
    }

    // MARK: A removal that fails

    @Test("one removal that fails is logged by its kind, and the other two still go")
    func oneFailureLetsTheOthersGo() async throws {
        #if !os(Windows)
        guard geteuid() != 0 else { return }
        #endif
        let world = try World()
        defer { world.remove() }
        try world.fillLeftovers()
        // The design files hold a folder that cannot be emptied: the removal of the whole fails on it
        let locked = world.paths.templates.appendingPathComponent("Locked", isDirectory: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: locked.path)
        defer { world.allowWrites(locked) }

        await world.adapter.clean()

        #expect(world.exists(world.paths.templateCache) == false)
        #expect(world.exists(world.paths.exportPreferences) == false)
        #expect(world.exists(world.paths.templates))
        let entries = world.logger.entries("legacy.leftovers.notRemoved")
        #expect(entries.count == 1)
        #expect(entries.first?.level == .error)
        #expect(entries.first?.category == .legacy)
        #expect(entries.first?.value("of") == .token("templates"))
        #expect(entries.first?.value("error") == .error(type: "LegacyLeftoverError", code: "noPermission"))
        #expect(entries.first?.line.contains(world.support.lastPathComponent) == false, "never a path")

        world.allowWrites(locked)
        await world.adapter.clean()
        #expect(world.exists(world.paths.templates) == false, "the next launch tries again")
    }

    @Test("the paths are the three names under Application Support, by one rule")
    func thePaths() {
        let paths = LegacyLeftoverPaths(applicationSupport: URL(fileURLWithPath: "/support", isDirectory: true))

        #expect(paths.templates.path == "/support/PrestoCV/Templates")
        #expect(paths.templateCache.path == "/support/TemplateCache")
        #expect(paths.exportPreferences.path == "/support/PrestoCV/export-preferences.json")
    }
}

private struct World {
    let scratch: URL
    let support: URL
    let paths: LegacyLeftoverPaths
    let logger = RecordingLogger()
    let adapter: LegacyLeftoversAdapter

    init() throws {
        scratch = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        support = scratch.appendingPathComponent("Application Support", isDirectory: true)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        paths = LegacyLeftoverPaths(applicationSupport: support)
        adapter = LegacyLeftoversAdapter(paths: paths, logger: logger)
    }

    /// Puts the three leftovers in place: the design files with a folder in them, their cache and the settings.
    func fillLeftovers() throws {
        try write("design", at: "PrestoCV/Templates/professional/template.json")
        try FileManager.default.createDirectory(
            at: paths.templates.appendingPathComponent("Locked", isDirectory: true), withIntermediateDirectories: true
        )
        try write("x", at: "PrestoCV/Templates/Locked/file.json")
        try write("cache", at: "TemplateCache/professional.png")
        try write("{}", at: "PrestoCV/export-preferences.json")
    }

    func write(_ text: String, at path: String) throws {
        let url = support.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }

    func read(_ path: String) throws -> String {
        String(decoding: try Data(contentsOf: support.appendingPathComponent(path)), as: UTF8.self)
    }

    func link(_ url: URL, to path: String) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: url, withDestinationURL: support.appendingPathComponent(path))
    }

    /// Whether something is at the path, a link itself included, whatever it points at.
    func exists(_ url: URL) -> Bool {
        (try? FileManager.default.attributesOfItem(atPath: url.path)) != nil
    }

    func isLink(_ url: URL) -> Bool {
        (try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)) != nil
    }

    func allowWrites(_ folder: URL) {
        guard exists(folder) else { return }
        do {
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: folder.path)
        } catch {
            Issue.record("the folder stays read-only: \(error)")
        }
    }

    func remove() {
        guard FileManager.default.fileExists(atPath: scratch.path) else { return }
        do {
            try FileManager.default.removeItem(at: scratch)
        } catch {
            Issue.record("the scratch folder stays: \(error)")
        }
    }
}
