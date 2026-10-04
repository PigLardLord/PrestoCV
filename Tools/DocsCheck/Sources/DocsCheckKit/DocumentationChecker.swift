import Foundation

/// The result of a run: every finding, sorted, and how many documents were read.
public struct Report: Sendable {
    public let findings: [Finding]
    public let documentCount: Int
}

/// Runs every check over the repository at `root`. It reads the tree and writes nothing.
public struct DocumentationChecker: Sendable {
    private let root: URL
    private let plannedFile: URL?

    public init(root: URL, plannedFile: URL? = nil) {
        self.root = root
        self.plannedFile = plannedFile
    }

    public func run() throws -> Report {
        let tree = RepositoryTree(root: root)
        let documents = try tree.documentPaths().map { Document(path: $0, markdown: MarkdownDocument(text: try tree.text(of: $0))) }
        var links = LinkCheck(tree: tree)
        var findings = try links.findings(in: documents)
        findings += NamedPathCheck(tree: tree, planned: try plannedPaths(), plannedFileName: plannedFileName).findings(in: documents)
        findings += ADRCheck(tree: tree).findings(in: documents)
        return Report(findings: findings.sorted(), documentCount: documents.count)
    }

    private func plannedPaths() throws -> PlannedPaths {
        guard let plannedFile else { return .none }
        return PlannedPaths(json: String(decoding: try Data(contentsOf: plannedFile), as: UTF8.self))
    }

    /// The planned file's path relative to the root, or its name if it is outside the repository.
    private var plannedFileName: String {
        guard let plannedFile else { return "" }
        let rootPath = root.standardizedFileURL.path + "/"
        let path = plannedFile.standardizedFileURL.path
        return path.hasPrefix(rootPath) ? String(path.dropFirst(rootPath.count)) : plannedFile.lastPathComponent
    }
}
