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
        let findings = try links.findings(in: documents)
        return Report(findings: findings.sorted(), documentCount: documents.count)
    }
}
