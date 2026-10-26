import DiagnosticLogging
import Foundation
import PrestoCVCore

/// What the app takes from the way it was launched.
enum LaunchEnvironment {
    /// Where the app keeps what the person makes: the CVs, and what earlier versions kept of editor work nobody saved.
    struct Storage {
        let cvs: @Sendable () throws -> URL
        let unsavedEdits: @Sendable () throws -> URL
    }

    /// Where the app keeps its data. The debug build keeps it in a folder of its own when a UI test asks for one, so
    /// that the test does not depend on what the simulator already holds: a new, empty folder for each launch, or a
    /// named one that the launches of one test share, as a relaunch needs. A new folder starts with the CV files the
    /// test hands over (`seedFiles(arguments:)`); a named folder that a launch has already made keeps what the app saved
    /// in it, so a test that wants to start over names a new one. Release builds ignore the request.
    /// - Parameter diagnostics: Where a seed that could not be written is logged.
    static func storage(arguments: [String], diagnostics: any DiagnosticLogger) -> Storage {
        #if DEBUG
        if let folder = uiTestFolder(arguments: arguments) {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("PrestoCVUITests-\(folder)", isDirectory: true)
            let cvs = directory.appendingPathComponent("CVs", isDirectory: true)
            seed(seedFiles(arguments: arguments), into: cvs, diagnostics: diagnostics)
            return Storage(
                cvs: { cvs },
                unsavedEdits: { directory.appendingPathComponent("UnsavedEdits", isDirectory: true) }
            )
        }
        #endif
        return Storage(
            cvs: { try DependencyContainer.defaultStorageDirectory() },
            unsavedEdits: { try DependencyContainer.defaultUnsavedEditsDirectory() }
        )
    }

    /// The CVs as the app reads and writes them. A UI test can make the writes of a CV fail, as on a full disk, or take
    /// a while, so that it reaches what the editor shows then. Release builds ignore both requests.
    /// - `-PrestoCVUITestsFailingWrites <count>`: the first `count` writes fail.
    /// - `-PrestoCVUITestsWriteSteps <steps>`: one step for each write from the launch on, parted by commas: `fail` fails
    ///   it, `slow:<seconds>` holds it that long and then stores it, `ok` stores it. Steps that cannot all be read script
    ///   nothing, and steps take the place of a count given with them.
    ///
    /// The writes after the steps are stored.
    /// - Parameter sleep: How the app waits, which holds a slow write for its time.
    static func cvs(
        _ cvs: CVManagementUseCaseProtocol,
        arguments: [String],
        sleep: @escaping @Sendable (Duration) async throws -> Void
    ) -> CVManagementUseCaseProtocol {
        #if DEBUG
        if let steps = writeSteps(arguments: arguments) {
            return ScriptedWrites(cvs: cvs, steps: steps, sleep: sleep)
        }
        #endif
        return cvs
    }

    /// The launch argument with which a UI test makes the first writes of a CV fail.
    static let failingWritesArgument = "-PrestoCVUITestsFailingWrites"

    /// The launch argument with which a UI test gives each write of a CV a step.
    static let writeStepsArgument = "-PrestoCVUITestsWriteSteps"

    /// Whether the app was launched to host the unit tests, which the test plans ask for. The tests build what they need,
    /// so the app then composes nothing: it neither reads nor changes the simulator's data, and does no work beside the
    /// tests. Release builds ignore the request.
    static func hostsUnitTests(arguments: [String]) -> Bool {
        #if DEBUG
        return arguments.contains(unitTestHostArgument)
        #else
        return false
        #endif
    }

    /// The launch argument of the test plans that makes the app a bare host for the unit tests. The plans follow it with
    /// a value, so that an argument after it is not read as its value.
    static let unitTestHostArgument = "-PrestoCVUnitTestHost"

    #if DEBUG
    /// What a write of a CV does, as a UI test asked.
    private enum WriteStep: Equatable, Sendable {
        case stores
        case fails
        /// Held this long, and then stored.
        case slow(Duration)

        init?(_ text: Substring) {
            let step = text.trimmingCharacters(in: .whitespaces)
            switch step {
            case "ok": self = .stores
            case "fail": self = .fails
            default:
                guard step.hasPrefix("slow:"), let seconds = Int(step.dropFirst("slow:".count)), seconds > 0 else { return nil }
                self = .slow(.seconds(seconds))
            }
        }
    }

    /// The steps a UI test gave the writes of a CV, or nil when it gave none that can be read.
    private static func writeSteps(arguments: [String]) -> [WriteStep]? {
        if let text = value(of: writeStepsArgument, in: arguments) {
            let steps = text.split(separator: ",", omittingEmptySubsequences: false).map(WriteStep.init)
            guard !steps.contains(nil) else { return nil }
            return steps.compactMap { $0 }
        }
        guard let text = value(of: failingWritesArgument, in: arguments), let count = Int(text), count > 0 else { return nil }
        return Array(repeating: .fails, count: count)
    }

    /// The value that follows `argument`, if both are there.
    private static func value(of argument: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: argument), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    /// CVs whose writes take the steps a UI test gave them, one each, and whose later writes are stored.
    private actor ScriptedWrites: CVManagementUseCaseProtocol {
        private let cvs: CVManagementUseCaseProtocol
        private var steps: [WriteStep]
        private let sleep: @Sendable (Duration) async throws -> Void

        init(cvs: CVManagementUseCaseProtocol, steps: [WriteStep], sleep: @escaping @Sendable (Duration) async throws -> Void) {
            self.cvs = cvs
            self.steps = steps
            self.sleep = sleep
        }

        func getAllCVs() async throws -> [CVModel] { try await cvs.getAllCVs() }
        func getCVListing() async throws -> CVListing { try await cvs.getCVListing() }
        func acknowledgeUnreadableCVs() async throws { try await cvs.acknowledgeUnreadableCVs() }
        func createCV(from template: CVModel) async throws -> CVModel { try await cvs.createCV(from: template) }
        func deleteCV(id: UUID) async throws { try await cvs.deleteCV(id: id) }
        func duplicateCV(id: UUID, named name: String) async throws -> CVModel { try await cvs.duplicateCV(id: id, named: name) }
        func getCV(by id: UUID) async throws -> CVModel? { try await cvs.getCV(by: id) }

        func storeNewCV(_ cv: CVModel) async throws -> CVModel {
            try await takeTheNextStep()
            return try await cvs.storeNewCV(cv)
        }

        func updateCV(_ cv: CVModel) async throws -> CVModel {
            try await takeTheNextStep()
            return try await cvs.updateCV(cv)
        }

        private func takeTheNextStep() async throws {
            guard !steps.isEmpty else { return }
            switch steps.removeFirst() {
            case .stores:
                return
            case .fails:
                throw CocoaError(.fileWriteOutOfSpace)
            case .slow(let duration):
                try await sleep(duration)
            }
        }
    }

    /// The name of the folder a UI test asked for, if it asked for one.
    private static func uiTestFolder(arguments: [String]) -> String? {
        if arguments.contains("-PrestoCVUITestsEmptyStorage") {
            return UUID().uuidString
        }
        guard let index = arguments.firstIndex(of: "-PrestoCVUITestsStorage"), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }

    /// The CV files a UI test hands over, so that it can start from CVs it wrote itself, saved at the times it chose:
    /// `-PrestoCVUITestsSeed` followed by a JSON object from file name to file content, in Base64: as plain JSON, CVs
    /// whose texts had apostrophes did not reach the app. A name that is not a plain `.json` file name is left out.
    static func seedFiles(arguments: [String]) -> [String: String] {
        guard let index = arguments.firstIndex(of: "-PrestoCVUITestsSeed"), arguments.indices.contains(index + 1),
              let json = Data(base64Encoded: arguments[index + 1]),
              let files = try? JSONDecoder().decode([String: String].self, from: json) else {
            return [:]
        }
        return files.filter { name, _ in
            name.hasSuffix(".json") && !name.hasPrefix(".") && !name.contains("/")
        }
    }

    /// Writes the files into a new folder before the app reads it. A folder that exists already holds what an earlier
    /// launch of the test saved, and the seed would overwrite it, so it is left as it is. A file that cannot be written
    /// leaves the test without it, and the log says why.
    private static func seed(_ files: [String: String], into directory: URL, diagnostics: any DiagnosticLogger) {
        guard !files.isEmpty, !isFolder(directory) else { return }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for (name, content) in files {
                try Data(content.utf8).write(to: directory.appendingPathComponent(name), options: .atomic)
            }
        } catch {
            diagnostics.error(.launch, "launch.seedFailed", .count("files", files.count), .error(error))
        }
    }

    private static func isFolder(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
    #endif
}

#if DEBUG
extension LogCategory {
    /// The launch of a UI test: the seed that could not be written
    fileprivate static let launch = LogCategory("launch")
}
#endif
