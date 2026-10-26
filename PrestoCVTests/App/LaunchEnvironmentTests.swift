import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore

@Suite("LaunchEnvironment Tests - the app as the host of the unit tests, and what a UI test may ask of it")
struct LaunchEnvironmentTests {

    @Test("The app is a bare host for the unit tests only when its launch asks for it")
    func hostsUnitTestsOnlyWhenAsked() {
        #expect(LaunchEnvironment.hostsUnitTests(arguments: ["PrestoCV", LaunchEnvironment.unitTestHostArgument]))
        #expect(!LaunchEnvironment.hostsUnitTests(arguments: ["PrestoCV"]))
    }

    @Test("The test plans launch the host that way, so it composes nothing beside the tests")
    func theseTestsRunInABareHost() {
        #expect(
            LaunchEnvironment.hostsUnitTests(arguments: ProcessInfo.processInfo.arguments),
            "The test plan should pass \(LaunchEnvironment.unitTestHostArgument) to the app"
        )
    }

    @Test("A UI test can make the first writes of a CV fail, as on a full disk; the writes after them are stored")
    func firstWritesFailWhenAsked() async throws {
        let store = MockCVManagementUseCase()
        let cvs = LaunchEnvironment.cvs(store, arguments: ["PrestoCV", LaunchEnvironment.failingWritesArgument, "2"], sleep: { _ in })
        let cv = CVModel(personalInfo: PersonalInfo(name: "Marta Rinaldi"))

        await #expect(throws: CocoaError.self) { _ = try await cvs.storeNewCV(cv) }
        await #expect(throws: CocoaError.self) { _ = try await cvs.updateCV(cv) }
        _ = try await cvs.storeNewCV(cv)

        #expect(try await cvs.getCV(by: cv.id) == cv)
        #expect(await store.createCVCallCount == 1, "The failed writes never reach the store")
    }

    @Test("A UI test can give each write of a CV a step: held a while and then stored, failed, or stored; the writes after the steps are stored")
    func writesFollowTheirSteps() async throws {
        let store = MockCVManagementUseCase()
        let holds = Holds()
        let cvs = LaunchEnvironment.cvs(
            store, arguments: ["PrestoCV", LaunchEnvironment.writeStepsArgument, "slow:6,fail,ok"], sleep: { await holds.hold($0) }
        )
        let cv = CVModel(personalInfo: PersonalInfo(name: "Marta Rinaldi"))

        _ = try await cvs.storeNewCV(cv)
        #expect(await holds.durations == [.seconds(6)], "The first write is held, and then stored")
        await #expect(throws: CocoaError.self) { _ = try await cvs.updateCV(cv) }
        _ = try await cvs.updateCV(cv)
        _ = try await cvs.updateCV(cv)

        #expect(await holds.durations == [.seconds(6)], "Only the slow step holds a write")
        #expect(await store.createCVCallCount == 1)
        #expect(await store.updateCVCallCount == 2, "The failed write never reaches the store; the others do")
    }

    @Test("Steps that cannot all be read script nothing: the CVs are the ones given")
    func unreadableStepsScriptNothing() {
        let store = MockCVManagementUseCase()
        for steps in ["", "slow", "slow:x", "slow:0", "maybe", "fail,,ok"] {
            let arguments = ["PrestoCV", LaunchEnvironment.writeStepsArgument, steps]
            #expect(LaunchEnvironment.cvs(store, arguments: arguments, sleep: { _ in }) as? MockCVManagementUseCase === store, "\(steps)")
        }
    }

    @Test("Without the request, or with a count that is not a number above zero, the CVs are the ones given")
    func noWriteFailsUnlessAsked() {
        let store = MockCVManagementUseCase()
        for arguments in [["PrestoCV"], ["PrestoCV", LaunchEnvironment.failingWritesArgument], ["PrestoCV", LaunchEnvironment.failingWritesArgument, "0"]] {
            #expect(LaunchEnvironment.cvs(store, arguments: arguments, sleep: { _ in }) as? MockCVManagementUseCase === store, "\(arguments)")
        }
    }
}

/// How long each slow write was held.
private actor Holds {
    private(set) var durations: [Duration] = []
    func hold(_ duration: Duration) { durations.append(duration) }
}

#if DEBUG
/// The CV files a UI test hands over (`-PrestoCVUITestsSeed`), which the screenshots of the store listing start from.
extension LaunchEnvironmentTests {

    /// The seed as a UI test passes it: a JSON object from file name to content, in Base64
    private func seed(_ json: String) -> String {
        Data(json.utf8).base64EncodedString()
    }

    private func folderArguments(seed: String? = nil) -> [String] {
        let folder = ["PrestoCV", "-PrestoCVUITestsStorage", UUID().uuidString]
        return seed.map { folder + ["-PrestoCVUITestsSeed", $0] } ?? folder
    }

    @Test("The CV files a UI test hands over are in its folder before the app reads it")
    func seedFilesAreWrittenIntoTheTestFolder() throws {
        let files = seed(#"{"cv_1.json":"{\"name\":\"Atelier Numérique de l'Erdre\"}","cv_2.json":"{}"}"#)
        let storage = LaunchEnvironment.storage(arguments: folderArguments(seed: files))
        let cvs = try storage.cvs()
        defer { try? FileManager.default.removeItem(at: cvs.deletingLastPathComponent()) }

        #expect(try String(contentsOf: cvs.appendingPathComponent("cv_1.json"), encoding: .utf8)
            == #"{"name":"Atelier Numérique de l'Erdre"}"#)
        #expect(try String(contentsOf: cvs.appendingPathComponent("cv_2.json"), encoding: .utf8) == "{}")
    }

    @Test("A seed name that is not a plain JSON file name is left out, and so is its file")
    func seedNamesThatAreNotPlainFileNamesAreLeftOut() throws {
        let files = seed(#"{"../out.json":"{}","inner/cv.json":"{}","notes.txt":"x",".json":"{}","cv_1.json":"{}"}"#)
        #expect(LaunchEnvironment.seedFiles(arguments: ["PrestoCV", "-PrestoCVUITestsSeed", files]) == ["cv_1.json": "{}"])

        let storage = LaunchEnvironment.storage(arguments: folderArguments(seed: files))
        let cvs = try storage.cvs()
        defer { try? FileManager.default.removeItem(at: cvs.deletingLastPathComponent()) }

        #expect(try FileManager.default.contentsOfDirectory(atPath: cvs.path) == ["cv_1.json"])
        #expect(!FileManager.default.fileExists(atPath: cvs.deletingLastPathComponent().appendingPathComponent("out.json").path))
    }

    @Test("Without the argument, without a value after it, or with a value that is not Base64 or not an object of texts, nothing is seeded")
    func missingOrMalformedSeedIsIgnored() throws {
        let notBase64 = "{\"cv_1.json\":\"{}\"}"
        let arguments: [[String]] = [
            ["PrestoCV"],
            ["PrestoCV", "-PrestoCVUITestsSeed"],
            ["PrestoCV", "-PrestoCVUITestsSeed", notBase64],
            ["PrestoCV", "-PrestoCVUITestsSeed", "%%%"],
            ["PrestoCV", "-PrestoCVUITestsSeed", seed("[1, 2]")],
            ["PrestoCV", "-PrestoCVUITestsSeed", seed(#"{"cv_1.json":1}"#)],
            ["PrestoCV", "-PrestoCVUITestsSeed", seed("{not json")],
        ]
        for argument in arguments {
            #expect(LaunchEnvironment.seedFiles(arguments: argument).isEmpty, "\(argument)")
        }

        let storage = LaunchEnvironment.storage(arguments: folderArguments(seed: notBase64))
        let cvs = try storage.cvs()
        defer { try? FileManager.default.removeItem(at: cvs.deletingLastPathComponent()) }
        #expect(!FileManager.default.fileExists(atPath: cvs.path), "A seed that cannot be read makes no folder and no file")
    }

    @Test("A seed is read only for the folder of a UI test: without one, the CVs stay where the app keeps them")
    func seedWithoutATestFolderIsNotWritten() throws {
        let files = seed(#"{"cv_1.json":"{}"}"#)
        let storage = LaunchEnvironment.storage(arguments: ["PrestoCV", "-PrestoCVUITestsSeed", files])
        let cvs = try storage.cvs()

        #expect(cvs.path.hasSuffix("/PrestoCV/CVs"))
        #expect(!FileManager.default.fileExists(atPath: cvs.appendingPathComponent("cv_1.json").path))
    }

    @Test("The CVs a UI test hands over are listed, and the scripted writes then apply to them")
    func seededCVsTakeTheScriptedWrites() async throws {
        let cv = CVModel(name: "Backend", personalInfo: PersonalInfo(name: "Emily Parker", title: "Engineer"))
        let source = FileManager.default.temporaryDirectory.appendingPathComponent("seed-source-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: source) }
        _ = try await DependencyContainer(storageDirectory: { source }).makeCVManagementUseCase().storeNewCV(cv)
        var files: [String: String] = [:]
        for name in try FileManager.default.contentsOfDirectory(atPath: source.path) where name.hasSuffix(".json") {
            files[name] = try String(contentsOf: source.appendingPathComponent(name), encoding: .utf8)
        }
        #expect(files.count == 1, "The store keeps a CV in one file")

        let seeded = try JSONEncoder().encode(files).base64EncodedString()
        let storage = LaunchEnvironment.storage(arguments: folderArguments(seed: seeded))
        defer { try? FileManager.default.removeItem(at: storage.cvs().deletingLastPathComponent()) }
        let cvs = LaunchEnvironment.cvs(
            try DependencyContainer(storageDirectory: storage.cvs).makeCVManagementUseCase(),
            arguments: ["PrestoCV", LaunchEnvironment.writeStepsArgument, "fail,ok"],
            sleep: { _ in }
        )
        let edited = CVModel(id: cv.id, name: "Backend, edited", personalInfo: cv.personalInfo)

        #expect(try await cvs.getAllCVs() == [cv], "The CV handed over is the one the app lists")
        await #expect(throws: CocoaError.self) { _ = try await cvs.updateCV(edited) }
        #expect(try await cvs.getCV(by: cv.id) == cv, "The write that failed changed nothing")
        _ = try await cvs.updateCV(edited)
        #expect(try await cvs.getCV(by: cv.id) == edited, "The write after the steps is stored")
    }
}
#endif
