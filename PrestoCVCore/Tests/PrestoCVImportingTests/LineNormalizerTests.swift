import Testing
@testable import PrestoCVImporting

@Suite("Normalising a line")
struct LineNormalizerTests {

    @Test("Ligatures become their letters")
    func ligatures() {
        #expect(LineNormalizer.normalize("Certiﬁed Proﬁle Oﬃce ﬂow").text == "Certified Profile Office flow")
    }

    @Test("Soft hyphens, zero-width characters and icon glyphs of the private-use area go")
    func invisibleAndIconCharacters() {
        #expect(LineNormalizer.normalize("Pro\u{AD}jekt\u{200B}leiter").text == "Projektleiter")
        #expect(LineNormalizer.normalize("\u{F095} +49 341 0000000 \u{F0E0} lena@example.com").text == "+49 341 0000000 lena@example.com")
    }

    @Test("Every kind of space becomes a space, and runs of two collapse")
    func spaces() {
        #expect(LineNormalizer.normalize("Giulia\u{00A0}Bianchi  Rossi").text == "Giulia Bianchi Rossi")
    }

    @Test("Markdown headings give their level and lose their hashes")
    func headings() {
        let line = LineNormalizer.normalize("## Esperienza professionale")
        #expect(line.markup == .heading(level: 2))
        #expect(line.text == "Esperienza professionale")
        #expect(LineNormalizer.normalize("#hashtag").markup == .none)
    }

    @Test("List markers of chat answers, Word and plain text make a list item")
    func listItems() {
        for raw in ["- Led a team", "* Led a team", "• Led a team", "▪ Led a team", "– Led a team", "1. Led a team", "o\tLed a team", "\u{F0B7}\tLed a team"] {
            let line = LineNormalizer.normalize(raw)
            #expect(line.markup == .listItem, "\(raw)")
            #expect(line.text == "Led a team", "\(raw)")
        }
        #expect(LineNormalizer.normalize("-2019").markup == .none)
        #expect(LineNormalizer.normalize("**Acme**").markup == .none)
    }

    @Test("Emphasis, code and escapes are removed; underscores inside words and addresses stay")
    func inlineMarkup() {
        #expect(LineNormalizer.normalize("**Senior iOS Developer** — *Acme S.p.A.*").text == "Senior iOS Developer — Acme S.p.A.")
        #expect(LineNormalizer.normalize("Built `SwiftUI` apps \\- fast").text == "Built SwiftUI apps - fast")
        #expect(LineNormalizer.normalize("mario_rossi@example.com and _italic_").text == "mario_rossi@example.com and italic")
        #expect(LineNormalizer.normalize("5 * 3 = 15").text == "5 * 3 = 15")
    }

    @Test("A line wholly in bold is marked bold")
    func boldLine() {
        #expect(LineNormalizer.normalize("**Esperienza**").isBold)
        #expect(LineNormalizer.normalize("**Acme** — Milano").isBold == false)
    }

    @Test("Markdown links keep their text and address")
    func links() {
        #expect(LineNormalizer.normalize("[LinkedIn](https://www.linkedin.com/in/example)").text == "LinkedIn https://www.linkedin.com/in/example")
        #expect(LineNormalizer.normalize("[https://example.com](https://example.com)").text == "https://example.com")
    }

    @Test("Horizontal rules and table separators are markup only")
    func rules() {
        #expect(LineNormalizer.normalize("---").markup == .rule)
        #expect(LineNormalizer.normalize("* * *").markup == .rule)
        #expect(LineNormalizer.normalize("|---|:---:|").markup == .tableSeparator)
    }

    @Test("A Markdown table row, tabs and runs of three spaces give cells")
    func cells() {
        #expect(LineNormalizer.normalize("| Inglese | **C1** |").cells == ["Inglese", "C1"])
        #expect(LineNormalizer.normalize("03/2019 – heute\tProjektleiterin").cells == ["03/2019 – heute", "Projektleiterin"])
        #expect(LineNormalizer.normalize("2016 – 2020     Laurea in Infermieristica").cells == ["2016 – 2020", "Laurea in Infermieristica"])
        #expect(LineNormalizer.normalize("Torino, Italia  ·  +39").cells == ["Torino, Italia · +39"])
    }

    @Test("A hyphen right after a letter at the end marks a word broken across lines")
    func hyphenAtTheEnd() {
        #expect(LineNormalizer.normalize("Verantwortung als Projekt-").endsWithHyphen)
        #expect(LineNormalizer.normalize("Verantwortung als Projekt\u{AD}").endsWithHyphen)
        #expect(LineNormalizer.normalize("2019 -").endsWithHyphen == false)
    }
}
