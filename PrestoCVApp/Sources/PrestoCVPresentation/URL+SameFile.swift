import Foundation

extension URL {
    /// Whether this file URL and `other` name the same file: the same path once links and `..` are resolved (decision 2
    /// of 5-7b). The inbox and the shell hold one file at a time, and the same file opened again is not held twice.
    func namesTheSameFile(as other: URL) -> Bool {
        resolvingSymlinksInPath().standardizedFileURL == other.resolvingSymlinksInPath().standardizedFileURL
    }
}
