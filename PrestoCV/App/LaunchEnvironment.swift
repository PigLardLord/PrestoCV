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
    static func storage(arguments: [String]) -> Storage {
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
