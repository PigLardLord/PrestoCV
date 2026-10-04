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
