import Foundation

/// Check 3. Every ADR has a status the ADR README defines, a superseded ADR links to the ADR that replaces it and
/// that ADR exists, and the index lists every ADR with the status its file has.
struct ADRCheck {
    static let directory = "docs/architecture/adr"
    private static let indexPath = directory + "/README.md"
    private static let statusMarker = "- **Status:**"

    let tree: RepositoryTree

    private struct Record {
        let path: String
        let status: ADRStatus?
    }

    func findings(in documents: [Document]) throws(DocsCheckError) -> [Finding] {
        guard try tree.kind(of: Self.directory) == .directory else {
            return [Finding(file: Self.directory, line: 1, code: .adrDirectoryMissing, message: "the ADR directory does not exist, so there is no ADR to check")]
        }
        let byPath = Dictionary(documents.map { ($0.path, $0.markdown) }, uniquingKeysWith: { first, _ in first })
        let adrPaths = Set(byPath.keys.filter { path in
            path.hasPrefix(Self.directory + "/") && ADRStatus.number(ofADRFileNamed: String(path.dropFirst(Self.directory.count + 1))) != nil
        })
        var findings: [Finding] = []
        var records: [String: Record] = [:]
        for path in adrPaths.sorted() {
            guard let markdown = byPath[path] else { continue }
            let (record, recordFindings) = statusOfADR(at: path, in: markdown, adrPaths: adrPaths)
            findings += recordFindings
            records[Self.number(of: path)] = record
        }
        guard let index = byPath[Self.indexPath] else {
            return findings + [Finding(file: Self.indexPath, line: 1, code: .adrIndexMissing, message: "the ADR index does not exist")]
        }
        return findings + indexFindings(index, records: records, adrPaths: adrPaths)
    }

    // MARK: Statuses of the ADR files

    private func statusOfADR(at path: String, in markdown: MarkdownDocument, adrPaths: Set<String>) -> (Record, [Finding]) {
        guard let line = markdown.proseLines.first(where: { $0.text.hasPrefix(Self.statusMarker) }) else {
            let finding = Finding(file: path, line: 1, code: .adrStatusMissing, message: "the ADR has no `\(Self.statusMarker)` line")
            return (Record(path: path, status: nil), [finding])
        }
        let text = String(line.text.dropFirst(Self.statusMarker.count))
        let (status, findings) = validated(text, file: path, line: line.number, adrPaths: adrPaths)
        return (Record(path: path, status: status), findings)
    }

    /// The status the text says, if it is one, and what is wrong with it.
    private func validated(_ text: String, file: String, line: Int, adrPaths: Set<String>) -> (ADRStatus?, [Finding]) {
        guard let status = ADRStatus(text: text) else {
            let message = "`\(text.trimmingCharacters(in: .whitespaces))` is not a status: use Proposed, Accepted, Rejected or Superseded by [NNNN](NNNN-title.md)"
            return (nil, [Finding(file: file, line: line, code: .adrStatusUnknown, message: message)])
        }
        guard case .supersededBy(let link) = status else { return (status, []) }
        guard let link else {
            let message = "a superseded ADR names, with a link, the ADR that replaces it"
            return (status, [Finding(file: file, line: line, code: .adrSupersededWithoutLink, message: message)])
        }
        let exists = RepositoryPath.resolve(link, from: Self.indexPath).map(adrPaths.contains) ?? false
        guard exists else {
            return (status, [Finding(file: file, line: line, code: .adrSuccessorMissing, message: "`\(link)` is not an ADR of \(Self.directory)")])
        }
        return (status, [])
    }

    // MARK: The index

    private func indexFindings(_ index: MarkdownDocument, records: [String: Record], adrPaths: Set<String>) -> [Finding] {
        var findings: [Finding] = []
        var listed: Set<String> = []
        for line in index.proseLines {
            guard let row = IndexRow(line: line.text) else { continue }
            listed.insert(row.number)
            let (status, statusFindings) = validated(row.status, file: Self.indexPath, line: line.number, adrPaths: adrPaths)
            findings += statusFindings
            guard let record = records[row.number] else {
                findings.append(Finding(file: Self.indexPath, line: line.number, code: .adrIndexUnknown, message: "the index lists ADR \(row.number), which has no file"))
                continue
            }
            if let status, let fileStatus = record.status, status.summary != fileStatus.summary {
                let message = "the index says \(status.summary), but \(record.path) says \(fileStatus.summary)"
                findings.append(Finding(file: Self.indexPath, line: line.number, code: .adrIndexStatusDiffers, message: message))
            }
        }
        for (number, record) in records where !listed.contains(number) {
            findings.append(Finding(file: record.path, line: 1, code: .adrNotIndexed, message: "the ADR is not listed in \(Self.indexPath)"))
        }
        return findings
    }

    private static func number(of path: String) -> String {
        ADRStatus.number(ofADRFileNamed: String(path.dropFirst(directory.count + 1))) ?? path
    }

    /// A row of the index table: `| [0001](0001-title.md) | Decision | Status |`.
    private struct IndexRow {
        let number: String
        let status: String

        init?(line: String) {
            guard line.hasPrefix("|") else { return nil }
            let cells = line.split(separator: "|", omittingEmptySubsequences: false).dropFirst().dropLast().map { $0.trimmingCharacters(in: .whitespaces) }
            guard cells.count >= 2, let first = cells.first, let status = cells.last else { return nil }
            let digits = first.drop { $0 == "[" }.prefix(4)
            guard digits.count == 4, digits.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
            self.number = String(digits)
            self.status = status
        }
    }
}
