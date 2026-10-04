import Testing
@testable import DocsCheckKit

@Suite("GitHub heading slugs")
struct HeadingSlugTests {
    @Test("a heading becomes lower case with hyphens for spaces and no punctuation", arguments: [
        ("Hello, World!", "hello-world"),
        ("Where things are", "where-things-are"),
        ("R1. Packages are isolated; contexts depend only along documented edges",
         "r1-packages-are-isolated-contexts-depend-only-along-documented-edges"),
        ("Foo & Bar", "foo--bar"),
        ("Q&A: what? (really)", "qa-what-really"),
        ("Step 1 — Setup", "step-1--setup"),
        ("Hyphen-ated words stay", "hyphen-ated-words-stay"),
        ("snake_case_name", "snake_case_name"),
        ("100% done + more = $5", "100-done--more--5"),
    ])
    func punctuation(heading: String, slug: String) {
        #expect(HeadingSlugger.baseSlug(ofHeading: heading) == slug)
    }

    @Test("backticks are dropped and their content is kept without its punctuation", arguments: [
        ("The `rules.json` file", "the-rulesjson-file"),
        ("`Tools/ArchitectureCheck`", "toolsarchitecturecheck"),
        ("Use ``a ` b`` here", "use-a--b-here"),
        ("`_private_` names", "_private_-names"),
    ])
    func backticks(heading: String, slug: String) {
        #expect(HeadingSlugger.baseSlug(ofHeading: heading) == slug)
    }

    @Test("accented letters and other scripts are kept, symbols and emoji are dropped", arguments: [
        ("Città e Università", "città-e-università"),
        ("Café au lait", "café-au-lait"),
        ("Über Straße", "über-straße"),
        ("日本語 の 見出し", "日本語-の-見出し"),
        ("Done ✅ and 🚀", "done--and-"),
        ("Résumé: 2 pages", "résumé-2-pages"),
    ])
    func accents(heading: String, slug: String) {
        #expect(HeadingSlugger.baseSlug(ofHeading: heading) == slug)
    }

    @Test("only alphabetic characters, marks, decimal digits and connector punctuation are kept, as github-slugger does", arguments: [
        ("x² and ½ cup", "x-and--cup"),
        ("Ⓐ circle", "ⓐ-circle"),
        ("Ⅻ roman", "ⅻ-roman"),
        ("① one", "-one"),
        ("٣ digits", "٣-digits"),
        ("a‿b", "a‿b"),
    ])
    func keptSet(heading: String, slug: String) {
        #expect(HeadingSlugger.baseSlug(ofHeading: heading) == slug)
    }

    @Test("a decomposed accent is kept as it is written")
    func decomposedAccent() {
        #expect(HeadingSlugger.baseSlug(ofHeading: "Cafe\u{0301}") == "cafe\u{0301}")
    }

    @Test("inline markup contributes its text only", arguments: [
        ("*Emphasis* and _more_ and **strong** and __bold__", "emphasis-and-more-and-strong-and-bold"),
        ("[Link text](https://example.com/x_y) after", "link-text-after"),
        ("[Reference][ref] and [shortcut]", "reference-and-shortcut"),
        ("![alt text](image.png) Logo", "-logo"),
        ("A <b>bold</b> word", "a-bold-word"),
        ("An <https://example.com> link", "an-httpsexamplecom-link"),
        ("Fish &amp; chips", "fish--chips"),
        ("Escaped \\*star\\* and \\_under\\_", "escaped-star-and-_under_"),
        ("~~Struck~~ out", "struck-out"),
        ("1 < 2 and 3 > 2", "1--2-and-3--2"),
    ])
    func inlineMarkup(heading: String, slug: String) {
        #expect(HeadingSlugger.baseSlug(ofHeading: heading) == slug)
    }

    @Test("an underscore run is dropped only when it opens or closes emphasis that has its other end", arguments: [
        ("The _config.yml file", "the-_configyml-file"),
        ("_emphasis_ and __strong__ words", "emphasis-and-strong-words"),
        ("snake_case and _real_", "snake_case-and-real"),
        ("a _b c", "a-_b-c"),
        ("a b_ c", "a-b_-c"),
        ("__init__ method", "init-method"),
        ("_a_b_", "a_b"),
        ("(_a_) and _a_.", "a-and-a"),
        ("_ a _", "_-a-_"),
        ("_a __b_ c__", "a-b-c"),
        ("a_ b _c", "a_-b-_c"),
        ("foo_bar_ and _foo_bar", "foo_bar_-and-_foo_bar"),
        ("__)_.(", "___"),
        ("_`__)", "___"),
        ("_a_b_ and __c__ and ___d___", "a_b-and-c-and-d"),
    ])
    func underscoreEmphasis(heading: String, slug: String) {
        #expect(HeadingSlugger.baseSlug(ofHeading: heading) == slug)
    }

    @Test("character references are decoded: numeric ones in decimal and hexadecimal, and the six named ones", arguments: [
        ("&#169; sign", "-sign"), ("&#xA9; sign", "-sign"), ("&#XA9; sign", "-sign"), ("caf&#233;", "café"), ("caf&#xE9;", "café"),
        ("&#x1F600; smile", "-smile"), ("fish &amp; chips", "fish--chips"), ("x &lt; y &gt; z", "x--y--z"), ("&quot;q&quot; &apos;a&apos;", "q-a"),
        ("a&nbsp;b", "ab"), ("&#0; &#xD800; &#x110000;", "--"), ("&#65;&#x42; &#1234567890; &#x;", "ab-1234567890-x"),
    ])
    func characterReferences(heading: String, slug: String) {
        #expect(HeadingSlugger.baseSlug(ofHeading: heading) == slug)
    }

    @Test("named references other than the six, and a reference link whose definition is elsewhere, are not rendered as GitHub does")
    func knownLimits() {
        // GitHub: "été". The heading alone cannot tell that "&eacute;" is a reference, so it stays text.
        #expect(HeadingSlugger.baseSlug(ofHeading: "&eacute;t&eacute;") == "eacuteteacute")
        // GitHub: "ab-text" when [b] is undefined, since then the brackets are text. The label is dropped here.
        #expect(HeadingSlugger.baseSlug(ofHeading: "[a][b] text") == "a-text")
    }

    @Test("an underscore inside a word is a letter of the word, not emphasis")
    func intrawordUnderscore() {
        #expect(HeadingSlugger.baseSlug(ofHeading: "the foo_bar_baz option") == "the-foo_bar_baz-option")
    }

    @Test("a repeated heading gets -1, -2 and so on, and a literal heading that collides is numbered too")
    func duplicates() {
        var slugger = HeadingSlugger()
        let slugs = ["Install", "Install", "Install", "Foo", "Foo", "Foo 1", "Foo", "Other"].map { slugger.slug(forHeading: $0) }
        #expect(slugs == ["install", "install-1", "install-2", "foo", "foo-1", "foo-1-1", "foo-2", "other"])
    }

    @Test("two headings that differ only in punctuation collide")
    func punctuationCollision() {
        var slugger = HeadingSlugger()
        #expect(slugger.slug(forHeading: "What?") == "what")
        #expect(slugger.slug(forHeading: "What!") == "what-1")
    }
}
