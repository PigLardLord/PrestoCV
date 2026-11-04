import Foundation

/// The checkout the tests run from.
enum SourceTree {
    /// The root of the repository, found from this file: CVGeneratorAI/Tests/CVGeneratorAITests/Support/SourceTree.swift.
    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent()
}
