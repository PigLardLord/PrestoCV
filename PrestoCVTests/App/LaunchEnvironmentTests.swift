#if DEBUG
import Foundation
import Testing
@testable import PrestoCV

@Suite("LaunchEnvironment Tests")
struct LaunchEnvironmentTests {

    /// The seed as a UI test passes it: a JSON object from file name to content, in Base64
    private func seed(_ json: String) -> String {
        Data(json.utf8).base64EncodedString()
    }

    @Test("The CV files a UI test hands over are in its folder before the app reads it")
    func seedFilesAreWrittenIntoTheTestFolder() throws {
        let files = seed(#"{"cv_1.json":"{\"name\":\"Atelier Numérique de l'Erdre\"}","cv_2.json":"{}"}"#)
        let storage = LaunchEnvironment.storage(
            arguments: ["PrestoCV", "-PrestoCVUITestsStorage", UUID().uuidString, "-PrestoCVUITestsSeed", files]
        )
        let cvs = try storage.cvs()
        defer { try? FileManager.default.removeItem(at: cvs.deletingLastPathComponent()) }

        #expect(try String(contentsOf: cvs.appendingPathComponent("cv_1.json"), encoding: .utf8)
            == #"{"name":"Atelier Numérique de l'Erdre"}"#)
        #expect(try String(contentsOf: cvs.appendingPathComponent("cv_2.json"), encoding: .utf8) == "{}")
    }

    @Test("A seed name that is not a plain JSON file name is left out")
    func seedNamesThatAreNotPlainFileNamesAreLeftOut() {
        let files = seed(#"{"../out.json":"{}","inner/cv.json":"{}","notes.txt":"x",".json":"{}","cv_1.json":"{}"}"#)

        #expect(LaunchEnvironment.seedFiles(arguments: ["PrestoCV", "-PrestoCVUITestsSeed", files]) == ["cv_1.json": "{}"])
    }

    @Test("Without the argument, without a value after it, or with a value that is not an object of texts in Base64, nothing is seeded")
    func missingOrMalformedSeedIsIgnored() {
        #expect(LaunchEnvironment.seedFiles(arguments: ["PrestoCV"]).isEmpty)
        #expect(LaunchEnvironment.seedFiles(arguments: ["PrestoCV", "-PrestoCVUITestsSeed"]).isEmpty)
        #expect(LaunchEnvironment.seedFiles(arguments: ["PrestoCV", "-PrestoCVUITestsSeed", seed("[1, 2]")]).isEmpty)
        #expect(LaunchEnvironment.seedFiles(arguments: ["PrestoCV", "-PrestoCVUITestsSeed", #"{"cv_1.json":"{}"}"#]).isEmpty)
    }
}
#endif
