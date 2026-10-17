import Foundation
import PrestoCVCore

/// What the app takes from the way it was launched.
enum LaunchEnvironment {
    /// Where the app keeps what the person makes: the CVs, and the edits the editor has not saved yet.
    struct Storage {
        let cvs: @Sendable () throws -> URL
        let unsavedEdits: @Sendable () throws -> URL
    }

    /// Where the app keeps its data. The debug build keeps it in a folder of its own when a UI test asks for one, so
    /// that the test does not depend on what the simulator already holds: a new, empty folder for each launch, or a
    /// named one that the launches of one test share, as a relaunch needs. Release builds ignore the request.
    static func storage(arguments: [String] = ProcessInfo.processInfo.arguments) -> Storage {
        #if DEBUG
        if let folder = uiTestFolder(arguments: arguments) {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("PrestoCVUITests-\(folder)", isDirectory: true)
            return Storage(
                cvs: { directory.appendingPathComponent("CVs", isDirectory: true) },
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
    #endif
}
