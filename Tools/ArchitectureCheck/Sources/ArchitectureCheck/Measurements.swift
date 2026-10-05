import SwiftSyntax

/// The thresholds of `CleanFunctions`, `CleanTypes` and `ISP` (ADR 0021 (c)). A measure above its limit is a finding.
enum Limits {
    static let functionLines = 20
    static let parameters = 3
    static let nesting = 2
    static let complexity = 5
    static let typeLines = 200
    static let fileLines = 300
    static let protocolRequirements = 5
}

extension Hit {
    /// A finding of a measuring detector. Its detail names the construct and stands for it in the fingerprint.
    init(measured detector: String, _ detail: String, line: Int) {
        self.init(detector: detector, detail: detail, node: detail, line: line, packageTarget: nil)
    }
}

/// Runs the detectors that measure the size and shape of code, and the one that reads its comments.
enum Measurements {
    static let detectors: Set<String> = [
        "functionLength", "parameterCount", "nestingDepth", "cyclomaticComplexity", "typeLength", "fileLength", "protocolSize",
        "ruleNumberCitation",
    ]

    static func hits(of tree: SourceFileSyntax, file: String) -> [Hit] {
        let lines = CodeLines(converter: SourceLocationConverter(fileName: file, tree: tree))
        let length = BodyLengthVisitor(lines: lines), shape = BodyShapeVisitor(lines: lines)
        let signatures = SignatureVisitor(lines: lines, constants: FileConstants(tree)), types = TypeLengthVisitor(lines: lines)
        let protocols = ProtocolSizeVisitor(lines: lines)
        for visitor in [length, shape, signatures, types, protocols] as [SyntaxVisitor] { visitor.walk(tree) }
        return length.hits + shape.hits + signatures.hits + types.hits + protocols.hits
            + FileLength.hits(of: tree, lines: lines) + CommentCitations.hits(in: tree, lines: lines)
    }
}
