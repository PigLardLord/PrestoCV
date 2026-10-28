import Foundation

/// What a skill name the model writes may be made of (ADR 0031): letters, single spaces, and the few marks that the names of tools
/// carry ("C++", "C#", "Node.js", "CI/CD", "Objective-C", "Q&A"). A name is no address, link or mark-up, and holds no character that
/// the reader cannot see or that reorders what they see: a control character, a bidirectional mark, a zero-width character, a
/// separator other than the space, a private-use character. An address or a character like these in a skill would reach the CV
/// the person shares, and the claim check never sees such a skill (`ClaimCandidates`).
struct SkillNameShape {
    /// The marks a name may hold besides letters and spaces.
    private static let marks: Set<Character> = [".", "+", "#", "-", "/", "&", "'", "\u{2019}"]
    /// The most marks a name holds: "C++" has two, "Objective-C" one.
    private static let mostMarks = 3
    /// The most scalars a letter takes: a letter and the accent that follows it. More is a stack of marks that hides the text around.
    private static let mostScalarsPerCharacter = 3
    /// The dotted names of tools that read as a link, each whole and in lower case: "Node.js", "ASP.NET". No suffix is trusted
    /// ("evil.js", "node.js.evil.com", "evil.net" are links), so a tool joins this list by its whole name, with a test that a
    /// lookalike is still a link.
    static let toolNames: Set<String> = [
        "node.js", "vue.js", "react.js", "next.js", "nuxt.js", "express.js", "angular.js", "ember.js", "backbone.js", "d3.js",
        "three.js", "chart.js", "p5.js", "alpine.js", "nest.js", "asp.net", "socket.io",
    ]

    /// Whether `name` is made only of what a skill name may hold.
    static func isPlain(_ name: String) -> Bool {
        var markCount = 0
        for character in name {
            guard character.unicodeScalars.count <= mostScalarsPerCharacter, character.unicodeScalars.allSatisfy(isVisible) else {
                return false
            }
            if marks.contains(character) {
                markCount += 1
            } else if character != " " && !character.isLetter {
                return false
            }
        }
        return markCount <= mostMarks && !isAnAddress(name)
    }

    /// Whether the scalar is one the reader sees: no control, format (bidirectional marks, zero-width characters, the soft hyphen),
    /// surrogate, private-use or unassigned scalar, no line or paragraph separator, and no space but the plain one.
    private static func isVisible(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .control, .format, .surrogate, .privateUse, .unassigned, .lineSeparator, .paragraphSeparator: false
        case .spaceSeparator: scalar == " "
        default: true
        }
    }

    /// Whether a token of `name` is an email or a link, or mentions one: "Node.js" is a tool, "evil.example" is a link.
    private static func isAnAddress(_ name: String) -> Bool {
        // Each token of the name is read alone and as written: a link is a tool only when the token is, whole, a name of the list
        // ("www.node.js", "node.js/" and "https://node.js" are links, "Node.js" is not).
        return name.split(separator: " ").contains { token in
            let tokens = AddressTokens(String(token))
            guard tokens.emails.isEmpty, !tokens.hasAmbiguousAddress else { return true }
            return !tokens.links.isEmpty && !toolNames.contains(token.lowercased())
        }
    }
}
