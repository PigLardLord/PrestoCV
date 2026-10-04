import Testing
@testable import DocsCheckKit

@Suite("Check 4 · the rule is stated")
struct RuleStatedCheckTests {
    private let agents = "AGENTS.md"
    private let template = ".github/pull_request_template.md"

    @Test("AGENTS.md that states the rule and a template with a Documents updated heading pass")
    func accepted() throws {
        #expect(try findings(in: [:]) == [])
    }

    @Test("AGENTS.md without the sentence is a finding")
    func ruleMissing() throws {
        let text = "# Guidelines\n\n- Tests are required.\n- Documentation is welcome, and changes with the code."
        #expect(try findings(in: ["AGENTS.md": text]) == ["AGENTS.md:1 rule-not-stated"])
    }

    @Test("the sentence may be wrapped, emphasised, capitalised and punctuated as the author likes", arguments: [
        "**Documentation changes with the code in the same pull request.**",
        "documentation changes with the code\nin the same pull request",
        "DOCUMENTATION CHANGES WITH THE CODE IN THE SAME PULL REQUEST!",
        "Documentation   changes with `the code` in *the same* pull request: always.",
        "- Rule: documentation changes with the code, in the same pull request",
    ])
    func spelling(text: String) throws {
        #expect(try findings(in: ["AGENTS.md": "# Guidelines\n\n" + text + "\n"]) == [])
    }

    @Test("only part of the rule is not the rule", arguments: [
        "Documentation changes with the code.", "Documentation changes in the same pull request.", "The code changes with the documentation in the same pull request.",
        "Documentation changes with the code in the same commit.", "Documentation never changes with the code in the same pull request.",
        "Documentation changes with the code in the same pull requests.", "Undocumentation changes with the code in the same pull request.",
    ])
    func partialRule(text: String) throws {
        #expect(try findings(in: ["AGENTS.md": "# Guidelines\n\n" + text]) == ["AGENTS.md:1 rule-not-stated"])
    }

    @Test("the rule is read from the prose: a comment or a code block that holds the sentence does not state it", arguments: [
        "<!-- Documentation changes with the code in the same pull request. -->",
        "<!--\nDocumentation changes with the code\nin the same pull request.\n-->",
        "```\nDocumentation changes with the code in the same pull request.\n```",
        "~~~markdown\n- **Documentation changes with the code in the same pull request.**\n~~~",
    ])
    func ruleOutsideTheProse(text: String) throws {
        #expect(try findings(in: ["AGENTS.md": "# Guidelines\n\n" + text + "\n"]) == ["AGENTS.md:1 rule-not-stated"])
    }

    @Test("the rule stated in the prose, with a comment elsewhere in the file, is stated")
    func ruleBesideAComment() throws {
        let text = "# Guidelines\n\n<!-- note -->\nDocumentation changes with the code <!-- really --> in the same pull request.\n"
        #expect(try findings(in: ["AGENTS.md": text]) == [])
    }

    @Test("a missing AGENTS.md is a finding, never a pass")
    func noAgents() throws {
        #expect(try findings(in: [:], removing: ["AGENTS.md"]) == ["AGENTS.md:1 rule-not-stated"])
    }

    @Test("a missing pull request template is a finding")
    func noTemplate() throws {
        #expect(try findings(in: [:], removing: [".github/pull_request_template.md"]) == [".github/pull_request_template.md:1 template-missing"])
    }

    @Test("a template that does not ask which documents the change updates is a finding")
    func templateDoesNotAsk() throws {
        let text = "## Purpose\n\n## Validation\n\nDocuments updated: none.\n"
        #expect(try findings(in: [".github/pull_request_template.md": text]) == [".github/pull_request_template.md:1 template-does-not-ask"])
    }

    @Test("the heading may be at any level, in any case and with punctuation, and a heading in a code block is not one", arguments: [
        ("# Documents updated", true), ("### documents UPDATED", true), ("## Documents updated ##", true), ("## Documents updated?", true),
        ("## The documents updated", false), ("```\n## Documents updated\n```", false), ("    ## Documents updated", false),
    ])
    func headingForms(text: String, accepted: Bool) throws {
        let result = try findings(in: [".github/pull_request_template.md": "## Purpose\n\n" + text + "\n\nWhich?"])
        #expect(result == (accepted ? [] : [".github/pull_request_template.md:1 template-does-not-ask"]))
    }
}
