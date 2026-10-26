import Foundation
@testable import PrestoCVCore

// The services of PrestoCVCore take every dependency through their initialisers. These tests give the ones they do not
// vary: files in temporary folders on the machine's file system.

extension FileStorageService {
    /// A storage on the machine's file system
    init(baseDirectory: URL) throws {
        try self.init(fileManager: .default, baseDirectory: baseDirectory)
    }
}
