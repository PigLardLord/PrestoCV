import Foundation
import PrestoCVCore

/// What the app takes from the way it was launched.
enum LaunchEnvironment {
    /// Where the CVs are kept. The debug build keeps them in a new, empty folder when a UI test asks for it, so
    /// that the test does not depend on what the simulator already holds. Release builds ignore the request.
    static func storageDirectory(arguments: [String] = ProcessInfo.processInfo.arguments) -> @Sendable () throws -> URL {
        #if DEBUG
        if arguments.contains("-PrestoCVUITestsEmptyStorage") {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("PrestoCVUITests-\(UUID().uuidString)", isDirectory: true)
            return { directory }
        }
        #endif
        return DependencyContainer.defaultStorageDirectory
    }
}
