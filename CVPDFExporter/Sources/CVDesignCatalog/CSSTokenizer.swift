import Foundation

// MARK: - Tokenizer (subset of CSS Syntax 3; anything outside it is rejected)

enum CSSTokenizer {
    static func tokenize(_ css: String) throws(CSSRejection) -> [CSSToken] {
        let s = Array(css.unicodeScalars)
        // Checked on the raw text, before anything else: comments and strings included.
        if s.contains("<") { throw CSSRejection(reason: "'<' is not allowed (closes <style>)") }
        if s.contains("\\") { throw CSSRejection(reason: "CSS escapes are not allowed") }
        var tokens: [CSSToken] = []
        var i = 0
        func at(_ k: Int) -> Unicode.Scalar? { k < s.count ? s[k] : nil }
        func isNameStart(_ c: Unicode.Scalar?) -> Bool { guard let c else { return false }; return ("a"..."z").contains(c) || ("A"..."Z").contains(c) || c == "_" }
        func isName(_ c: Unicode.Scalar?) -> Bool { guard let c else { return false }; return isNameStart(c) || ("0"..."9").contains(c) || c == "-" }
        func isDigit(_ c: Unicode.Scalar?) -> Bool { guard let c else { return false }; return ("0"..."9").contains(c) }
        func name() -> String { var n = String.UnicodeScalarView(); while isName(at(i)) { n.append(s[i]); i += 1 }; return String(n) }

        while i < s.count {
            let c = s[i]
            if c == " " || c == "\t" || c == "\n" || c == "\r" || c == "\u{0C}" {
                while let w = at(i), w == " " || w == "\t" || w == "\n" || w == "\r" || w == "\u{0C}" { i += 1 }
                if tokens.last != .whitespace { tokens.append(.whitespace) }
            } else if c == "/", at(i + 1) == "*" {
                i += 2
                while i < s.count, !(s[i] == "*" && at(i + 1) == "/") { i += 1 }
                guard i < s.count else { throw CSSRejection(reason: "unterminated comment") }
                i += 2
            } else if c == "\"" || c == "'" {
                i += 1
                var v = String.UnicodeScalarView()
                while let d = at(i), d != c {
                    if d == "\n" || d == "\r" { throw CSSRejection(reason: "newline in string") }
                    v.append(d); i += 1
                }
                guard at(i) == c else { throw CSSRejection(reason: "unterminated string") }
                i += 1; tokens.append(.string(String(v)))
            } else if c.value > 0x7E || (c.value < 0x20) {
                throw CSSRejection(reason: "non-ASCII or control character outside comments")
            } else if isDigit(c) || (c == "." && isDigit(at(i + 1))) || ((c == "-" || c == "+") && (isDigit(at(i + 1)) || (at(i + 1) == "." && isDigit(at(i + 2))))) {
                var n = String.UnicodeScalarView()
                if c == "-" || c == "+" { n.append(c); i += 1 }
                var integerDigits = 0, seenPoint = false
                while isDigit(at(i)) || (at(i) == "." && isDigit(at(i + 1)) && !seenPoint) {
                    if s[i] == "." { seenPoint = true } else if !seenPoint { integerDigits += 1 }
                    n.append(s[i]); i += 1
                }
                guard integerDigits <= 9, n.count <= 16, let value = Double(String(n)) else { throw CSSRejection(reason: "number out of range") }
                if at(i) == "%" { i += 1; tokens.append(.percentage(value)) }
                else if isNameStart(at(i)) { tokens.append(.dimension(value, name().lowercased())) }
                else { tokens.append(.number(value)) }
            } else if isNameStart(c) || (c == "-" && (isNameStart(at(i + 1)) || at(i + 1) == "-")) {
                let n = name()
                if at(i) == "(" { i += 1; tokens.append(.function(n.lowercased())) } else { tokens.append(.ident(n)) }
            } else if c == "@" {
                i += 1; tokens.append(.atKeyword(name().lowercased()))
            } else if c == "#" {
                i += 1; tokens.append(.hash(name()))
            } else {
                i += 1
                switch c {
                case ":": tokens.append(.colon)
                case ";": tokens.append(.semicolon)
                case ",": tokens.append(.comma)
                case "{": tokens.append(.lbrace)
                case "}": tokens.append(.rbrace)
                case "(": tokens.append(.lparen)
                case ")": tokens.append(.rparen)
                case "[": tokens.append(.lbracket)
                case "]": tokens.append(.rbracket)
                default: tokens.append(.delim(c))
                }
            }
        }
        return tokens
    }
}
