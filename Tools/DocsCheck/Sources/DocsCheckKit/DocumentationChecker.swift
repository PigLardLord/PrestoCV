import Foundation

/// The result of a run: every finding, sorted, and how many documents were read.
public struct Report: Sendable {
    public let findings: [Finding]
    public let documentCount: Int
}

/// Runs every check over the repository at `root`. It reads the tree and writes nothing.
public struct DocumentationChecker: Sendable {
    private let files: any RepositoryFiles
    private let root: URL
    private let plannedFile: URL?

    public init(root: URL, plannedFile: URL? = nil) {
        self.init(files: DiskFiles(root: root), rootPath: root.path, plannedFile: plannedFile)
    }

    init(files: any RepositoryFiles, rootPath: String, plannedFile: URL?) {
        self.files = files
        self.root = URL(fileURLWithPath: rootPath)
        self.plannedFile = plannedFile
    }

    public func run() throws(DocsCheckError) -> Report {
        let tree = RepositoryTree(files: files)
        _ = try tree.topLevelEntries()
        var documents: [Document] = []
        for path in try tree.documentPaths() {
            documents.append(Document(path: path, markdown: MarkdownDocument(text: try tree.text(of: path))))
        }
        var links = LinkCheck(tree: tree)
        var findings = try links.findings(in: documents)
        findings += unreadHeadings(in: documents)
        findings += try NamedPathCheck(tree: tree, planned: try plannedPaths(), plannedFileName: plannedFileName).findings(in: documents)
        findings += try ADRCheck(tree: tree).findings(in: documents)
        findings += try RuleStatedCheck(tree: tree).findings()
        return Report(findings: findings.sorted(), documentCount: documents.count)
    }

    private func unreadHeadings(in documents: [Document]) -> [Finding] {
        var findings: [Finding] = []
        for document in documents {
            for problem in document.markdown.problems {
                switch problem.reason {
                case .tooLong:
                    let message = "the heading is longer than \(MarkdownDocument.maximumHeadingLength) characters, so it is not read and has no anchor"
                    findings.append(Finding(file: document.path, line: problem.line, code: .headingTooLong, message: message))
                case .tooNested:
                    let message = "the heading nests link labels more than \(InlineText.maximumNesting) deep, so it is not read and has no anchor"
                    findings.append(Finding(file: document.path, line: problem.line, code: .headingTooNested, message: message))
                }
            }
        }
        return findings
    }

    private func plannedPaths() throws(DocsCheckError) -> PlannedPaths {
        guard let plannedFile else { return .none }
        do {
            return PlannedPaths(json: String(decoding: try Data(contentsOf: plannedFile), as: UTF8.self))
        } catch {
            throw .plannedFileUnreadable(path: plannedFileName)
        }
    }

    /// The planned file's path relative to the root, or its name if it is outside the repository.
    private var plannedFileName: String {
        guard let plannedFile else { return "" }
        let rootPath = root.standardizedFileURL.path + "/"
        let path = plannedFile.standardizedFileURL.path
        return path.hasPrefix(rootPath) ? String(path.dropFirst(rootPath.count)) : plannedFile.lastPathComponent
    }
}
