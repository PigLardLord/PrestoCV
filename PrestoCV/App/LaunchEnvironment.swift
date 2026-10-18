import Foundation
import PrestoCVCore
#if DEBUG
import os
#endif

/// What the app takes from the way it was launched.
enum LaunchEnvironment {
    /// Where the app keeps what the person makes: the CVs, and the edits the editor has not saved yet.
    struct Storage {
        let cvs: @Sendable () throws -> URL
        let unsavedEdits: @Sendable () throws -> URL
    }

    /// Where the app keeps its data. The debug build keeps it in a folder of its own when a UI test asks for one, so
    /// that the test does not depend on what the simulator already holds: a new, empty folder for each launch, or a
    /// named one that the launches of one test share, as a relaunch needs. The folder starts with the CV files the
    /// test hands over (`seedFiles(arguments:)`). Release builds ignore the request.
    static func storage(arguments: [String] = ProcessInfo.processInfo.arguments) -> Storage {
        #if DEBUG
        if let folder = uiTestFolder(arguments: arguments) {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("PrestoCVUITests-\(folder)", isDirectory: true)
            let cvs = directory.appendingPathComponent("CVs", isDirectory: true)
            write(seedFiles(arguments: arguments), into: cvs)
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

    #if DEBUG
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

    /// Writes the files into the folder before the app reads it. A file that cannot be written leaves the test
    /// without it, and the log says why.
    private static func write(_ files: [String: String], into directory: URL) {
        guard !files.isEmpty else { return }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for (name, content) in files {
                try Data(content.utf8).write(to: directory.appendingPathComponent(name), options: .atomic)
            }
        } catch {
            Logger(subsystem: "com.PigLardLord.prestocv", category: "launch")
                .error("The UI test's CV files were not written: \(error.localizedDescription, privacy: .public)")
        }
    }
    #endif
}
