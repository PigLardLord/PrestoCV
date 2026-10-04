import Testing
import Foundation
@testable import CVDocumentModel
import CVDesignCatalog
@testable import CVRendering

/// Only what a letter cannot do without: a sender's name, a paragraph, the signature and a date. English, a neutral recipient.
let letterMinimal = LetterDocument(language: "en", sender: Person(name: "Ada Lovelace"), date: LetterDate(year: 2026, month: 1, day: 9),
                                   body: ["I am writing to apply."], name: "Ada Lovelace")

/// Whether the design validator refuses a design whose stylesheet is `css`.
func designRejects(_ css: String) -> Bool { (try? DesignPackageValidator().validate(designData(css))) == nil }

func render(_ letter: LetterDocument) throws -> RenderedDocument { try LetterHTMLBuilder().render(letter) }

/// The text nodes a letter must produce, written from its fields and from the conventions, and nowhere else: the
/// layout adds no word of its own (R13).
func expectedLetterNodes(_ letter: LetterDocument, _ conventions: LetterConventions) -> [String] {
    func filled(_ lines: [String]) -> [String] { lines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
    var nodes = [letter.sender.name]
    nodes += [letter.sender.professionalTitle, letter.sender.email, letter.sender.phone, letter.sender.location, letter.sender.website].compactMap { $0 }
    nodes += [letter.recipient.name, letter.recipient.company].compactMap { $0 } + filled(letter.recipient.address)
    nodes.append(conventions.dateLine(place: letter.place, date: letter.date) ?? "")
    if let reference = letter.reference { nodes += [conventions.referenceLabel, reference] }
    if let subject = letter.subject { nodes.append(subject) }
    nodes.append(conventions.salutation(letter.recipient.formOfAddress, familyName: letter.recipient.familyName) ?? "")
    nodes += filled(letter.body)
    if let closing = letter.closing { nodes.append(closing) }
    nodes += [conventions.valediction(letter.recipient.formOfAddress), letter.name]
    if !filled(letter.attachments).isEmpty { nodes += [conventions.attachmentsLabel] + filled(letter.attachments) }
    return nodes
}

/// The classes and the tag names of the body's start tags.
func letterTags(_ html: String) throws -> [(name: String, classes: [String])] {
    let body = String(html[try #require(html.range(of: "<body>")).upperBound...])
    return startTags(in: body).map { (name: $0.name, classes: ($0.attributes["class"] ?? "").split(separator: " ").map(String.init)) }
}

/// What a letter's paragraphs say, by class: the text of the first element with that class.
func letterText(_ html: String, _ cls: String) -> String? {
    guard let open = html.range(of: "class=\"\(cls)\""), let start = html.range(of: ">", range: open.upperBound..<html.endIndex),
          let end = html.range(of: "</", range: start.upperBound..<html.endIndex) else { return nil }
    return String(html[start.upperBound..<end.lowerBound])
}

@Suite("ADR 0019 · the letter's typed HTML builder")
struct LetterBuilderTests {
    /// Golden tests (R10): the committed files are the reviewed output. To change one on purpose, set UPDATE_GOLDEN=1, run once,
    /// and review the diff of Golden/letter-*.html like code.
    func golden(_ name: String, matches html: String, file: String = #filePath) throws {
        let source = URL(fileURLWithPath: file).deletingLastPathComponent().appendingPathComponent("Golden/\(name).html")
        if ProcessInfo.processInfo.environment["UPDATE_GOLDEN"] == "1" { try Data(html.utf8).write(to: source) }
        let url = try #require(Bundle.module.url(forResource: "Golden/\(name)", withExtension: "html"))
        #expect(html == (try String(contentsOf: url, encoding: .utf8)))
    }

    @Test("golden output: a letter with every field renders exactly to the reviewed HTML")
    func goldenFull() throws { try golden("letter-it", matches: try render(letterFixture).html) }

    @Test("golden output: a letter with only the required fields renders exactly to the reviewed HTML")
    func goldenMinimal() throws { try golden("letter-en-minimal", matches: try render(letterMinimal).html) }

    @Test("the markup uses only the letter's own elements and classes, and a letter with every field uses all of them")
    func structure() throws {
        let tags = try letterTags(try render(letterFixture).html)
        #expect(Set(tags.map(\.name)) == LetterMarkup.elements)
        #expect(Set(tags.flatMap(\.classes)) == LetterMarkup.classes)
        let minimal = try letterTags(try render(letterMinimal).html)
        #expect(Set(minimal.flatMap(\.classes)).isSubset(of: LetterMarkup.classes) && Set(minimal.map(\.name)).isSubset(of: LetterMarkup.elements))
        #expect(LetterMarkup.classes.isDisjoint(with: MarkupContract.classes) && LetterMarkup.classes.count == LetterClass.allCases.count)
    }

    @Test("the document says where it is written, and its schema version")
    func root() throws {
        let html = try render(letterFixture).html
        #expect(html.hasPrefix(#"<!DOCTYPE html><html lang="it"><head><meta charset="utf-8"><title>Candidatura per la posizione di Analista</title>"#))
        #expect(html.contains(#"<main class="letter" data-schema="1">"#))
        #expect(try render(letterMinimal).html.contains("<title>Ada Lovelace</title>"))
        var odd = letterFixture
        odd.language = "pt-BR"
        #expect(try render(odd).html.contains(#"<html lang="pt-BR">"#))
    }

    @Test("every text node is a field or a convention of the language, in each of the six languages",
          arguments: LetterConventionsTests.languages)
    func textNodes(language: String) throws {
        var letter = letterFixture
        letter.language = language
        let conventions = try LetterConventionsCatalog.conventions(for: language)
        #expect(try render(letter).textNodes == expectedLetterNodes(letter, conventions))
        for form in FormOfAddress.allCases {
            letter.recipient.formOfAddress = form
            #expect(try render(letter).textNodes == expectedLetterNodes(letter, conventions), "\(language) \(form)")
        }
    }

    @Test("the page writes the salutation, the valediction and the date from the language's conventions, whatever the layout",
          arguments: LetterConventionsTests.expected)
    func writtenByThePage(expected: LetterConventionsTests.Expected) throws {
        for (index, form) in FormOfAddress.allCases.enumerated() {
            var letter = letterFixture
            letter.language = expected.language
            letter.place = "Roma"
            letter.date = LetterConventionsTests.day
            letter.recipient.formOfAddress = form
            letter.recipient.familyName = "Rossi"
            let html = try render(letter).html
            #expect(html.contains(#"<html lang="\#(expected.language)">"#))
            #expect(letterText(html, "letter-dateline") == expected.dateLine)
            #expect(letterText(html, "letter-salutation") == expected.salutations[index])
            #expect(letterText(html, "letter-valediction") == expected.valedictions[index])
            #expect(letterText(html, "letter-attachments-title") == expected.labels[1])
            #expect(letterText(html, "letter-reference-label") == expected.labels[0])
        }
    }

    @Test("the first of the month is written as the language writes it: 1er in French", arguments: LetterConventionsTests.expected)
    func firstOfTheMonth(expected: LetterConventionsTests.Expected) throws {
        var letter = letterFixture
        letter.language = expected.language
        letter.place = "Roma"
        letter.date = LetterConventionsTests.firstDay
        let rendered = try render(letter)
        #expect(letterText(rendered.html, "letter-dateline") == expected.firstDateLine)
        #expect(rendered.textNodes.contains(expected.firstDateLine))
    }

    @Test("the layout holds no word: with the conventions' words replaced, nothing of the old ones is left")
    func layoutHoldsNoWords() throws {
        var table = try LetterData.raw("en")
        table["salutations"] = ["masculine": "SM {name}", "feminine": "SF {name}", "neutral": "SN"]
        table["valedictions"] = ["masculine": "VM", "feminine": "VF", "neutral": "VN"]
        table["labels"] = ["reference": "LR", "attachments": "LA"]
        table["date"] = ["format": "{year}/{month}/{day}", "months": (1...12).map { "m\($0)" }, "withPlace": "{date} @ {place}", "withoutPlace": "{date}"]
        let conventions = try LetterConventions.parse(try JSONSerialization.data(withJSONObject: table), language: "en")
        var letter = letterFixture
        letter.language = "en"
        let rendered = try LetterHTMLBuilder().render(letter, conventions: conventions)
        #expect(rendered.textNodes == expectedLetterNodes(letter, conventions))
        #expect(rendered.textNodes.contains("SF Rossi") && rendered.textNodes.contains("2026/m10/4 @ Roma") && rendered.textNodes.contains("VF"))
        #expect(rendered.textNodes.contains("LR") && rendered.textNodes.contains("LA"))
        for word in ["Dear", "Yours", "Enclosures", "Reference", "October"] { #expect(!rendered.html.contains(word), "\(word)") }
    }

    @Test("every populated field of the document reaches the page")
    func everyFieldIsPrinted() throws {
        let nodes = try render(letterFixture).textNodes
        let leaves = stringLeaves(of: letterFixture).filter { $0 != letterFixture.language }
        #expect(leaves.count == LetterTextField.all.count)
        for leaf in leaves { #expect(nodes.contains { $0.contains(leaf) }, "\(leaf) is not on the page") }
    }

    @Test("user text is escaped and never re-parsed: a hole, a tag, a quote and a combining mark stay text")
    func escaping() throws {
        var letter = letterFixture
        letter.body = ["Writes {{title}} {name} {date} literally & <script>alert(1)</script>", "x\"\u{0301} onload=alert(1) y=\""]
        letter.recipient.familyName = "{date}<b>"
        letter.recipient.name = "Ada <Lovelace>"
        let rendered = try render(letter)
        #expect(rendered.html.contains("Writes {{title}} {name} {date} literally &amp; &lt;script&gt;alert(1)&lt;/script&gt;"))
        #expect(rendered.html.contains("Gentile Sig.ra {date}&lt;b&gt;,") && rendered.html.contains("Ada &lt;Lovelace&gt;"))
        #expect(!rendered.html.contains("<script>") && !rendered.html.contains("<b>"))
        #expect(try letterTags(rendered.html).count == (try letterTags(try render(letterFixture).html)).count)     // no element was added
        #expect(rendered.textNodes.contains("Writes {{title}} {name} {date} literally & <script>alert(1)</script>"))
    }

    @Test("a letter with no body renders its header, its salutation, its valediction and its signature, and no paragraph", arguments: LetterDocumentContractTests.emptyBodies)
    func emptyBody(body: [String]) throws {
        var letter = letterFixture
        letter.body = body
        letter.closing = nil
        let rendered = try render(letter)
        #expect(rendered.textNodes == expectedLetterNodes(letter, try LetterConventionsCatalog.conventions(for: "it")))
        #expect(!rendered.html.contains("class=\"letter-paragraph\"") && !rendered.html.contains("class=\"letter-closing\""))
        #expect(letterText(rendered.html, "letter-salutation") == "Gentile Sig.ra Rossi," && letterText(rendered.html, "letter-valediction") == "Distinti saluti,")
        #expect(rendered.html.contains("letter-signature") && rendered.html.contains("letter-sender-name"))
        var bare = letterMinimal
        bare.body = []
        #expect(try render(bare).textNodes == ["Ada Lovelace", "9 January 2026", "Dear Sir or Madam,", "Yours faithfully,", "Ada Lovelace"])
    }

    @Test("a line break in a paragraph or the closing is printed: the builder's base style keeps the line breaks of those two, and only those")
    func baseStylePrintsLineBreaks() throws {
        #expect(LetterHTMLBuilder.baseStyle == "\(DocumentHTMLBuilder.baseStyle).letter-paragraph,.letter-closing{white-space:pre-line}")
        let html = try render(letterFixture).html
        #expect(html.contains("<style>\(LetterHTMLBuilder.baseStyle)</style>"))
        #expect(!LetterHTMLBuilder.baseStyle.contains("<"))
        // The property is the builder's own: the CSS policy has no white-space, so neither the letter's stylesheet nor a design can set it.
        #expect(!(try LetterStyle.stylesheet().css.contains("white-space")))
        #expect(throws: CSSRejection.self) { _ = try ValidatedStylesheet.validating(".letter-paragraph{white-space:pre-line}", against: LetterMarkup.vocabulary) }
        #expect(designRejects(".cv-summary{white-space:pre-line}") && designRejects(".letter-paragraph{white-space:pre-line}"))
    }

    @Test("a line break inside a paragraph or the closing stays in its text node, as the CV's builder keeps one in its text")
    func lineBreaks() throws {
        var letter = letterFixture
        letter.body[0] = "First line\nSecond line"
        letter.closing = "Thanks,\nAda"
        let rendered = try render(letter)
        #expect(rendered.html.contains("<p class=\"letter-paragraph\">First line\nSecond line</p>"))
        #expect(rendered.html.contains("<p class=\"letter-closing\">Thanks,\nAda</p>"))
        #expect(rendered.textNodes.contains("First line\nSecond line") && rendered.textNodes.contains("Thanks,\nAda"))
        let cv = DocumentHTMLBuilder().build(CVDocument(language: "en", person: Person(name: "A"), sections: [.summary("First line\nSecond line")]),
                                             stylesheet: try stylesheet(), palette: palette, headings: try HeadingsCatalog.headings(for: "en"))
        #expect(cv.contains("<p class=\"cv-summary\">First line\nSecond line</p>"))
    }

    static let websiteCases: [(String, Bool)] = [
        ("https://ada.example", true), ("http://example.org/path?q=1", true), ("javascript:alert(1)", false), ("https://linkedin.com@example.org/", false),
        ("//evil.example", false), ("https://example.org:8443/", false), ("data:text/html,<script>", false), ("https://example.org/ with space", false),
    ]

    @Test("the sender's website is kept only as a parsed link, and prints its destination", arguments: websiteCases)
    func website(url: String, kept: Bool) throws {
        var letter = letterMinimal
        letter.sender.website = url
        let rendered = try render(letter)
        #expect(rendered.html.contains(#"<a class="letter-sender-website" href="\#(url)">\#(url)</a>"#) == kept)
        #expect(startTags(in: rendered.html).contains { $0.name == "a" } == kept)
        #expect(rendered.textNodes.contains(url) == kept)
    }

    @Test("blank optional values are absent, not empty elements")
    func blanks() throws {
        var letter = letterFixture
        letter.sender.professionalTitle = ""
        letter.sender.email = ""
        letter.recipient.name = ""
        letter.recipient.company = nil
        letter.recipient.address = ["", ""]
        letter.place = ""
        letter.reference = ""
        letter.subject = nil
        letter.body = ["First", "", "  ", "Last"]
        letter.closing = ""
        letter.attachments = ["", ""]
        let html = try render(letter).html
        for cls in ["letter-sender-title", "letter-sender-email", "letter-recipient", "letter-recipient-name", "letter-recipient-address", "letter-reference",
                    "letter-subject", "letter-closing", "letter-attachments", "letter-attachment"] {
            #expect(!html.contains("class=\"\(cls)\""), "\(cls)")
        }
        #expect(html.components(separatedBy: "class=\"letter-paragraph\"").count == 3)
        #expect(letterText(html, "letter-dateline") == "4 ottobre 2026")
        #expect(!html.contains("<p class=\"letter-sender-title\"></p>") && !html.contains("<p></p>"))
    }

    static let invalidCases: [(String, String)] = [
        ("language", "language is not supported"), ("hidden", LetterDocumentValidator.textReason("a paragraph")), ("untrimmed", "the place starts or ends with white space"),
        ("family", "the recipient's family name is required"), ("date", "the date does not exist"),
    ]

    @Test("a letter that cannot be rendered is a typed error that names the validator's reason", arguments: invalidCases)
    func invalidLetters(what: String, reason: String) throws {
        var letter = letterFixture
        switch what {
        case "language": letter.language = "ja"
        case "hidden": letter.body[0] = "\u{202E}evil"
        case "untrimmed": letter.place = "Roma "
        case "family": letter.recipient.familyName = nil
        default: letter.date = LetterDate(year: 2026, month: 2, day: 30)
        }
        #expect(throws: LetterBuildFailure.invalid(reason)) { _ = try LetterHTMLBuilder().render(letter) }
    }

    @Test("the conventions' own guards: a date or a name the conventions cannot write is invalid, not a crash")
    func conventionsGuards() throws {
        let conventions = try LetterConventionsCatalog.conventions(for: "en")
        var letter = letterFixture
        letter.date = LetterDate(year: 2026, month: 13, day: 1)
        #expect(throws: LetterBuildFailure.invalid("the date does not exist")) { _ = try LetterHTMLBuilder().render(letter, conventions: conventions) }
        letter = letterFixture
        letter.recipient.familyName = nil
        #expect(throws: LetterBuildFailure.invalid("the recipient's family name is required")) { _ = try LetterHTMLBuilder().render(letter, conventions: conventions) }
    }

    @Test("the validator's languages are the conventions' languages, so a valid letter always has its data", arguments: LetterDocument.supportedLanguages)
    func everyValidLanguageHasConventions(language: String) throws {
        var letter = letterMinimal
        letter.language = language
        #expect(try render(letter).html.contains(#"<html lang="\#(language)">"#))
    }
}

@Suite("ADR 0019 · the letter's stylesheet is built in, and is not a design")
struct LetterStyleTests {
    @Test("it passes the same tokenizer and property allow-list as a design's, against the letter's selectors")
    func passesThePolicy() throws {
        let sheet = try LetterStyle.stylesheet()
        #expect(!sheet.css.isEmpty && !sheet.css.contains("/*"))
        // What was validated is what is emitted: validating it again changes nothing.
        #expect(try ValidatedStylesheet.validating(sheet.css, against: LetterMarkup.vocabulary).css == sheet.css)
        #expect(try ValidatedStylesheet.validating(LetterStyle.source, against: LetterMarkup.vocabulary) == sheet)
    }

    @Test("it names only the letter's classes, and styles the letter itself")
    func namesOnlyTheLettersClasses() throws {
        let css = try LetterStyle.stylesheet().css
        let regex = try NSRegularExpression(pattern: #"\.([a-z][a-z-]*)"#)
        let ns = css as NSString
        let named = Set(regex.matches(in: css, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range(at: 1)) })
        // A class in a number such as "10.5pt" is not a selector: the numbers of the stylesheet are lengths.
        let selectors = named.filter { $0.hasPrefix("letter") || $0.hasPrefix("cv") }
        #expect(selectors.isSubset(of: LetterMarkup.classes) && selectors.contains("letter") && selectors.contains("letter-subject"))
    }

    @Test("it cannot be checked against the CV's vocabulary: its classes are not a design's to select")
    func notADesignsSelectors() {
        #expect(throws: CSSRejection.self) { _ = try ValidatedStylesheet.validating(LetterStyle.source, against: .cv) }
        #expect(designRejects(LetterStyle.source))
    }

    @Test("a letter rule that names a CV class, or any selector outside the letter's, is refused in the words of the letter's structure")
    func letterRejectionsNameTheLetter() {
        for css in [".cv-name{color:var(--color-text)}", "h3{color:var(--color-text)}", ".letter:first-child{color:var(--color-text)}", #".letter[data-schema="1"]{color:var(--color-text)}"#] {
            do {
                _ = try ValidatedStylesheet.validating(css, against: LetterMarkup.vocabulary)
                Issue.record("\(css) was accepted")
            } catch { #expect(error.reason.contains("the cover letter's structure") && !error.reason.contains("markup contract"), "\(css): \(error.reason)") }
        }
    }

    @Test("a design stylesheet that names a letter class, or any letter selector, is rejected", arguments: LetterMarkup.classes.sorted())
    func designsCannotSelectTheLetter(cls: String) {
        #expect(designRejects(".\(cls){color:var(--color-text)}"))
        #expect(designRejects(".cv .\(cls){color:var(--color-text)}"))
        #expect(designRejects("@media print{.\(cls){color:var(--color-text)}}"))
        #expect(designRejects("p.\(cls){color:var(--color-text)}"))
    }

    @Test("the letter's own colours are readable, by the palette rules that a design's colours obey")
    func fixedColoursAreReadable() throws {
        let primary = try #require(HexColor(LetterStyle.primary)), text = try #require(HexColor(LetterStyle.text))
        let background = try #require(HexColor(LetterStyle.background))
        let palette = try #require(Palette(primary: primary, text: text, background: background))
        // The same three variables, in the order of a palette's, followed by the fonts.
        #expect(LetterStyle.customProperties.hasPrefix(String(palette.customProperties.dropLast())))
        #expect(LetterStyle.customProperties.hasSuffix("}") && !LetterStyle.customProperties.contains("<"))
        #expect(LetterStyle.customProperties.contains("--font-body:\(LetterStyle.fonts)") && LetterStyle.customProperties.contains("--font-heading:\(LetterStyle.fonts)"))
    }

    @Test("the page carries the stylesheet and the fixed values, and no design reaches it: the builder takes the letter alone")
    func carriesIt() throws {
        let html = try render(letterFixture).html
        #expect(html.contains("<style>\(try LetterStyle.stylesheet().css)</style>") && html.contains("<style>\(LetterStyle.customProperties)</style>"))
        #expect(html.contains("<style>\(LetterHTMLBuilder.baseStyle)</style>"))
        #expect(html.components(separatedBy: "<style>").count == 4)
    }
}
