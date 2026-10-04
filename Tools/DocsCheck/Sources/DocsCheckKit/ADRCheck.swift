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
        var findings = duplicatedNumbers(among: adrPaths)
        var records: [String: Record] = [:]
        for path in adrPaths.sorted() {
            guard let markdown = byPath[path] else { continue }
            let (record, recordFindings) = statusOfADR(at: path, in: markdown, adrPaths: adrPaths)
            findings += recordFindings
            records[path] = record
        }
        guard let index = byPath[Self.indexPath] else {
            return findings + [Finding(file: Self.indexPath, line: 1, code: .adrIndexMissing, message: "the ADR index does not exist")]
        }
        return findings + indexFindings(index, records: records, adrPaths: adrPaths)
    }

    /// Two files with one number: each is a finding, because a number names one decision.
    private func duplicatedNumbers(among adrPaths: Set<String>) -> [Finding] {
        var byNumber: [String: [String]] = [:]
        for path in adrPaths.sorted() { byNumber[Self.number(of: path), default: []].append(path) }
        var findings: [Finding] = []
        for (number, paths) in byNumber where paths.count > 1 {
            for path in paths {
                let others = paths.filter { $0 != path }.map { Finding.quoted(String($0.dropFirst(Self.directory.count + 1))) }.joined(separator: ", ")
                findings.append(Finding(file: path, line: 1, code: .adrNumberDuplicated, message: "ADR \(number) is also the number of \(others)"))
            }
        }
        return findings
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
            let message = "\(Finding.quoted(text.trimmingCharacters(in: .whitespaces))) is not a status: use Proposed, Accepted, Rejected or Superseded by [NNNN](NNNN-title.md)"
            return (nil, [Finding(file: file, line: line, code: .adrStatusUnknown, message: message)])
        }
        guard case .supersededBy(let link) = status else { return (status, []) }
        guard let link else {
            let message = "a superseded ADR names, with a link, the ADR that replaces it"
            return (status, [Finding(file: file, line: line, code: .adrSupersededWithoutLink, message: message)])
        }
        let exists = RepositoryPath.resolve(link, from: Self.indexPath).map(adrPaths.contains) ?? false
        guard exists else {
            return (status, [Finding(file: file, line: line, code: .adrSuccessorMissing, message: "\(Finding.quoted(link)) is not an ADR of \(Self.directory)")])
        }
        if let shown = ADRStatus.shownNumber(inStatusText: text), shown != status.successorNumber {
            let message = "the status says ADR \(shown), but its link points at \(Finding.quoted(link))"
            return (status, [Finding(file: file, line: line, code: .adrSuccessorMissing, message: message)])
        }
        return (status, [])
    }

    // MARK: The index

    private func indexFindings(_ index: MarkdownDocument, records: [String: Record], adrPaths: Set<String>) -> [Finding] {
        var findings: [Finding] = []
        var listed: Set<String> = []
        for line in index.proseLines {
            guard let row = IndexRow(line: line.text) else { continue }
            let (status, statusFindings) = validated(row.status, file: Self.indexPath, line: line.number, adrPaths: adrPaths)
            findings += statusFindings
            guard let target = row.link.flatMap({ RepositoryPath.resolve($0, from: Self.indexPath) }), adrPaths.contains(target), let record = records[target] else {
                let message = row.link.map { "the index row \(row.number) links \(Finding.quoted($0)), which is not an ADR of \(Self.directory)" }
                    ?? "the index row \(row.number) has no link to the file of its ADR"
                findings.append(Finding(file: Self.indexPath, line: line.number, code: .adrIndexUnknown, message: message))
                continue
            }
            guard Self.number(of: target) == row.number else {
                let message = "the index row says \(row.number), but \(Finding.quoted(String(target.dropFirst(Self.directory.count + 1)))) is ADR \(Self.number(of: target))"
                findings.append(Finding(file: Self.indexPath, line: line.number, code: .adrIndexUnknown, message: message))
                continue
            }
            listed.insert(target)
            if let status, let fileStatus = record.status, status.summary != fileStatus.summary {
                let message = "the index says \(status.summary), but \(record.path) says \(fileStatus.summary)"
                findings.append(Finding(file: Self.indexPath, line: line.number, code: .adrIndexStatusDiffers, message: message))
            }
        }
        for path in records.keys.sorted() where !listed.contains(path) {
            findings.append(Finding(file: path, line: 1, code: .adrNotIndexed, message: "the ADR is not listed in \(Self.indexPath)"))
        }
        return findings
    }

    private static func number(of path: String) -> String {
        ADRStatus.number(ofADRFileNamed: String(path.dropFirst(directory.count + 1))) ?? path
    }

    /// A row of the index table: `| [0001](0001-title.md) | Decision | Status |`.
    private struct IndexRow {
        let number: String
        /// The destination of the link in the first cell, if it has one.
        let link: String?
        let status: String

        init?(line: String) {
            guard line.hasPrefix("|") else { return nil }
            let cells = line.split(separator: "|", omittingEmptySubsequences: false).dropFirst().dropLast().map { $0.trimmingCharacters(in: .whitespaces) }
            guard cells.count >= 2, let first = cells.first, let status = cells.last else { return nil }
            let digits = first.drop { $0 == "[" }.prefix(4)
            guard digits.count == 4, digits.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
            self.number = String(digits)
            self.link = MarkdownDocument(text: first).links.first.flatMap { LinkTarget(destination: $0.destination)?.path }
            self.status = status
        }
    }
}
