import Testing
@testable import CVDesignCatalog

@Suite("CSS policy · what is read, and why a refusal")
struct CSSPolicyTests {
    @Test("a comment drops out of the tokens, and the white space around it stays one token")
    func comments() throws {
        #expect(try CSSTokenizer.tokenize("a /* c */  b") == [.ident("a"), .whitespace, .ident("b")])
        #expect(try CSSTokenizer.tokenize("a/**/b") == [.ident("a"), .ident("b")])
    }

    @Test("each kind of token is read as itself", arguments: [
        ("Cv-Name", CSSToken.ident("Cv-Name")), ("--color", .ident("--color")), ("VAR(", .function("var")), ("@MEDIA", .atKeyword("media")),
        ("#Id", .hash("Id")), ("'a b'", .string("a b")), ("\"x\"", .string("x")), (">", .delim(">")), ("{", .lbrace), ("]", .rbracket),
        ("-.5", .number(-0.5)), ("+3", .number(3)), ("1.5", .number(1.5)), ("50%", .percentage(50)), ("12PT", .dimension(12, "pt")),
    ])
    func tokens(css: String, token: CSSToken) throws {
        #expect(try CSSTokenizer.tokenize(css) == [token])
    }

    @Test("text outside the supported subset is refused with its reason", arguments: [
        ("a<b", "'<' is not allowed (closes <style>)"), ("a\\b", "CSS escapes are not allowed"), ("/* open", "unterminated comment"),
        ("\"open", "unterminated string"), ("\"two\nlines\"", "newline in string"), ("é", "non-ASCII or control character outside comments"),
        ("\u{1}", "non-ASCII or control character outside comments"), ("1234567890", "number out of range"),
        ("1.234567890123456", "number out of range"),
    ])
    func tokenizerRefusals(css: String, reason: String) {
        #expect(throws: CSSRejection(reason: reason)) { _ = try CSSTokenizer.tokenize(css) }
    }

    @Test("a stylesheet is refused with the reason of its first problem", arguments: [
        ("{}", "empty selector"), (".cv >{}", "dangling combinator"), ("> .cv{}", "dangling combinator"),
        (".cv > > .cv-entry{}", "double combinator"), (".cv{color:var(--color-text)", "unterminated rule"), (".cv", "expected {"),
        ("@media print{.cv{}", "unterminated @media"), ("@media speech{}", "only @media print, screen or all"),
        ("@import x;", "@import is not allowed"), (".cv{.cv-entry{}}", "nested rules are not allowed"),
        ("[data-section=x]{}", "attribute selector not in the markup contract"), ("[data-section]{}", "attribute selector not allowed"),
        ("[data-section=#]{}", "attribute value not allowed"), ("*{}", "the universal selector is not allowed"),
        (":hover{}", "pseudo-class or pseudo-element not allowed"), ("div{}", "element div is not in the markup contract"),
        (".nope{}", "class is not in the markup contract"), ("#a{}", "selector token not allowed"), (".cv{color}", "malformed declaration"),
        (".cv{color:var(--color-text) !important}", "!important is not allowed"), (".cv{position:absolute}", "property position is not allowed"),
        (".cv{display:flex}", "a flex or grid container must set gap or column-gap (at least 3pt)"),
        (".cv{margin:1pt 2pt 3pt 4pt 5pt}", "wrong number of values"), (".cv{font-size:7pt 8pt}", "wrong number of values"),
        (".cv{grid-template-columns:1fr 1fr 1fr 1fr 1fr}", "1 to 4 grid tracks"), (".cv{border:1pt 2pt}", "border value not allowed"),
    ])
    func parserRefusals(css: String, reason: String) {
        #expect(throws: CSSRejection(reason: reason)) { _ = try CSSPolicy.canonical(css) }
    }

    @Test("a rule with two problems is refused for its selector, which is judged before the declarations", arguments: [
        (".nope{position:absolute}", "class is not in the markup contract"), ("div{color}", "element div is not in the markup contract"),
        (".cv >{font-size:1pt}", "dangling combinator"), ("*{display:flex}", "the universal selector is not allowed"),
    ])
    func selectorBeforeDeclarations(css: String, reason: String) {
        #expect(throws: CSSRejection(reason: reason)) { _ = try CSSPolicy.canonical(css) }
    }

    @Test("a rule that is not closed is refused for that before its contents are judged", arguments: [
        (".nope{position:absolute", "unterminated rule"), (".nope;{position:absolute}", "unexpected token in selector"),
        (".nope{.cv{position:absolute}}", "nested rules are not allowed"),
    ])
    func structureBeforeContents(css: String, reason: String) {
        #expect(throws: CSSRejection(reason: reason)) { _ = try CSSPolicy.canonical(css) }
    }

    @Test("a border takes one width, one style and one palette colour; a second style or width is refused", arguments: [
        (".cv{border:solid dashed}", "length out of bounds or unit not allowed"), (".cv{border:solid solid}", "length out of bounds or unit not allowed"),
        (".cv{border:1pt 2pt}", "border value not allowed"), (".cv{border:1pt solid 2pt}", "border value not allowed"),
        (".cv{border:1pt var(--color-background)}", "only [\"--color-primary\", \"--color-text\"] are allowed here"),
        (".cv{border:solid var(--color-text}", "length out of bounds or unit not allowed"),
    ])
    func borderParts(css: String, reason: String) {
        #expect(throws: CSSRejection(reason: reason)) { _ = try CSSPolicy.canonical(css) }
    }

    @Test("a border may list its parts in any order, and a flex container's gap may come before or after it")
    func borderOrder() throws {
        #expect(try CSSPolicy.canonical(".cv{border:solid var(--color-text) 1pt}") == ".cv{border:1pt solid var(--color-text)}")
        #expect(try CSSPolicy.canonical(".cv{border-top:var(--color-primary) DASHED 2px}") == ".cv{border-top:2px dashed var(--color-primary)}")
        #expect(try CSSPolicy.canonical(".cv{gap:3pt;display:flex}") == ".cv{gap:3pt;display:flex}")
    }

    @Test("selectors, combinators and attribute values are written in one canonical form")
    func canonicalSelectors() throws {
        #expect(try CSSPolicy.canonical("  .cv  >  .cv-entry , SECTION~article:First-Child +h1{ color : var(--color-text) ; }")
                == ".cv>.cv-entry,section~article:first-child+h1{color:var(--color-text)}")
        #expect(try CSSPolicy.canonical("[data-section=skills] .cv-skill[data-rating='3'],[data-rating=5]{}")
                == "[data-section=\"skills\"] .cv-skill[data-rating=\"3\"],[data-rating=\"5\"]{}")
    }
}
