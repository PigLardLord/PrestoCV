import Foundation
@testable import PrestoCVCore

// The services of PrestoCVCore take every dependency through their initialisers. These tests give the ones they do not
// vary: files in temporary folders on the machine's file system, and random tokens for the claims on unsaved edits.

extension FileStorageService {
    /// A storage on the machine's file system
    init(baseDirectory: URL) throws {
        try self.init(fileManager: .default, baseDirectory: baseDirectory)
    }
}

extension UnsavedEditsUseCase {
    /// Unsaved edits whose claims get random tokens
    init(repository: UnsavedEditsRepositoryProtocol, now: @escaping @Sendable () -> Date) {
        self.init(repository: repository, now: now, makeToken: { UUID() })
    }
}
