/// Check 4. `AGENTS.md` states that documentation changes with the code in the same pull request, and the pull
/// request template asks which documents the change updates. Each is found by a marker, so the wording around it
/// can change:
/// - `AGENTS.md` contains the sentence "documentation changes with the code in the same pull request", in any case,
///   wrapped over lines and with any emphasis or punctuation;
/// - the template has a heading, at any level, that reads "Documents updated".
struct RuleStatedCheck {
    static let agentsPath = "AGENTS.md"
    static let templatePath = ".github/pull_request_template.md"
    static let ruleMarker = "documentation changes with the code in the same pull request"
    static let templateHeadingMarker = "documents updated"

    let tree: RepositoryTree

    func findings() throws(DocsCheckError) -> [Finding] {
        var findings: [Finding] = []
        if try tree.kind(of: Self.agentsPath) == .file {
            if !Self.contains(phrase: Self.ruleMarker, in: try tree.text(of: Self.agentsPath)) {
                findings.append(Finding(file: Self.agentsPath, line: 1, code: .ruleNotStated,
                                        message: "it does not state that \(Self.ruleMarker)"))
            }
        } else {
            findings.append(Finding(file: Self.agentsPath, line: 1, code: .ruleNotStated, message: "the file does not exist, so the rule is not stated"))
        }
        if try tree.kind(of: Self.templatePath) == .file {
            let headings = MarkdownDocument(text: try tree.text(of: Self.templatePath)).headings
            if !headings.contains(where: { Self.words(in: $0.text) == Self.words(in: Self.templateHeadingMarker) }) {
                findings.append(Finding(file: Self.templatePath, line: 1, code: .templateDoesNotAsk,
                                        message: "it has no heading \"Documents updated\", where it asks which documents the change updates"))
            }
        } else {
            findings.append(Finding(file: Self.templatePath, line: 1, code: .templateMissing, message: "the pull request template does not exist"))
        }
        return findings
    }

    /// Whether the words of `phrase` appear, whole and in order, in the words of `text`.
    private static func contains(phrase: String, in text: String) -> Bool {
        " \(words(in: text)) ".contains(" \(words(in: phrase)) ")
    }

    /// The lower-case words of a text, separated by single spaces: what is left of it once case, wrapping,
    /// emphasis and punctuation are gone, so a marker can be searched for as a phrase.
    private static func words(in text: String) -> String {
        text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).joined(separator: " ")
    }
}
