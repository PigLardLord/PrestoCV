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

    /// The CVs as the app reads and writes them. A UI test can ask for the first writes of a CV to fail, as on a full
    /// disk, with `-PrestoCVUITestsFailingWrites <count>`, so that it reaches what the editor shows then. Release builds
    /// ignore the request.
    static func cvs(_ cvs: CVManagementUseCaseProtocol, arguments: [String]) -> CVManagementUseCaseProtocol {
        #if DEBUG
        if let index = arguments.firstIndex(of: failingWritesArgument), arguments.indices.contains(index + 1),
           let count = Int(arguments[index + 1]), count > 0 {
            return FailingWrites(cvs: cvs, failures: count)
        }
        #endif
        return cvs
    }

    /// The launch argument with which a UI test makes the first writes of a CV fail.
    static let failingWritesArgument = "-PrestoCVUITestsFailingWrites"

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
    /// CVs whose first `failures` writes fail, as on a full disk, and whose later writes are stored.
    private actor FailingWrites: CVManagementUseCaseProtocol {
        private let cvs: CVManagementUseCaseProtocol
        private var failures: Int

        init(cvs: CVManagementUseCaseProtocol, failures: Int) {
            self.cvs = cvs
            self.failures = failures
        }

        func getAllCVs() async throws -> [CVModel] { try await cvs.getAllCVs() }
        func getCVListing() async throws -> CVListing { try await cvs.getCVListing() }
        func acknowledgeUnreadableCVs() async throws { try await cvs.acknowledgeUnreadableCVs() }
        func createCV(from template: CVModel) async throws -> CVModel { try await cvs.createCV(from: template) }
        func deleteCV(id: UUID) async throws { try await cvs.deleteCV(id: id) }
        func duplicateCV(id: UUID, named name: String) async throws -> CVModel { try await cvs.duplicateCV(id: id, named: name) }
        func getCV(by id: UUID) async throws -> CVModel? { try await cvs.getCV(by: id) }

        func storeNewCV(_ cv: CVModel) async throws -> CVModel {
            try failIfAsked()
            return try await cvs.storeNewCV(cv)
        }

        func updateCV(_ cv: CVModel) async throws -> CVModel {
            try failIfAsked()
            return try await cvs.updateCV(cv)
        }

        private func failIfAsked() throws {
            guard failures > 0 else { return }
            failures -= 1
            throw CocoaError(.fileWriteOutOfSpace)
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
    #endif
}
