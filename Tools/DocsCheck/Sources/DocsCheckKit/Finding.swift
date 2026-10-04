/// What a check can report. The raw value is the code printed in the report and documented in the README.
public enum FindingCode: String, CaseIterable, Sendable {
    case linkTargetMissing = "link-target-missing"
    case linkAnchorMissing = "link-anchor-missing"
    case headingTooLong = "heading-too-long"
    case headingTooNested = "heading-too-nested"
    case pathMissing = "path-missing"
    case plannedPathExists = "planned-path-exists"
    case plannedPathUnused = "planned-path-unused"
    case plannedFileInvalid = "planned-file-invalid"
    case adrDirectoryMissing = "adr-directory-missing"
    case adrStatusMissing = "adr-status-missing"
    case adrStatusUnknown = "adr-status-unknown"
    case adrSupersededWithoutLink = "adr-superseded-without-link"
    case adrSuccessorMissing = "adr-successor-missing"
    case adrIndexMissing = "adr-index-missing"
    case adrNotIndexed = "adr-not-indexed"
    case adrIndexUnknown = "adr-index-unknown"
    case adrIndexStatusDiffers = "adr-index-status-differs"
    case adrNumberDuplicated = "adr-number-duplicated"
    case ruleNotStated = "rule-not-stated"
    case templateMissing = "template-missing"
    case templateDoesNotAsk = "template-does-not-ask"
}

/// One place where a document and the repository disagree.
public struct Finding: Hashable, Comparable, Sendable, CustomStringConvertible {
    /// The path of the document, relative to the repository root.
    public let file: String
    public let line: Int
    public let code: FindingCode
    public let message: String

    public var description: String { "\(file):\(line): \(code.rawValue): \(message)" }

    /// Text of a document, as a code span in a message. A long one is cut, so a finding stays a line.
    static func quoted(_ text: String) -> String {
        let limit = 160
        return text.dropFirst(limit).isEmpty ? "`\(text)`" : "`\(text.prefix(limit))…`"
    }

    public static func < (lhs: Finding, rhs: Finding) -> Bool {
        if lhs.file != rhs.file { return lhs.file < rhs.file }
        if lhs.line != rhs.line { return lhs.line < rhs.line }
        if lhs.code != rhs.code { return lhs.code.rawValue < rhs.code.rawValue }
        return lhs.message < rhs.message
    }
}
