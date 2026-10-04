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
    private let knownTopLevelFiles: [URL]

    /// `knownTopLevelFiles` hold one name per line, such as `git ls-tree --name-only HEAD` prints. A name in them
    /// counts as a top-level entry of the repository even if it is no longer one, so that a directory that was
    /// deleted or renamed is found through the documents that still name it.
    public init(root: URL, plannedFile: URL? = nil, knownTopLevelFiles: [URL] = []) {
        self.init(files: DiskFiles(root: root), rootPath: root.path, plannedFile: plannedFile, knownTopLevelFiles: knownTopLevelFiles)
    }

    init(files: any RepositoryFiles, rootPath: String, plannedFile: URL?, knownTopLevelFiles: [URL] = []) {
        self.files = files
        self.root = URL(fileURLWithPath: rootPath)
        self.plannedFile = plannedFile
        self.knownTopLevelFiles = knownTopLevelFiles
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
        findings += try NamedPathCheck(tree: tree, planned: try plannedPaths(), plannedFileName: plannedFileName, knownTopLevel: try knownTopLevel()).findings(in: documents)
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

    private func knownTopLevel() throws(DocsCheckError) -> Set<String> {
        var names: Set<String> = []
        for file in knownTopLevelFiles {
            let text: String
            do {
                text = String(decoding: try Data(contentsOf: file), as: UTF8.self)
            } catch {
                throw .knownTopLevelUnreadable(path: displayName(of: file))
            }
            for line in text.split(whereSeparator: \.isNewline) {
                let name = line.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty, !name.contains("/") { names.insert(name) }
            }
        }
        return names
    }

    /// The planned file's path relative to the root, or its name if it is outside the repository.
    private var plannedFileName: String {
        plannedFile.map(displayName(of:)) ?? ""
    }

    private func displayName(of file: URL) -> String {
        let rootPath = root.standardizedFileURL.path + "/"
        let path = file.standardizedFileURL.path
        return path.hasPrefix(rootPath) ? String(path.dropFirst(rootPath.count)) : file.lastPathComponent
    }
}
