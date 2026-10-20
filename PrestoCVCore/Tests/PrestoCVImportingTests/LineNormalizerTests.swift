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

    @Test("A heading's closing hashes go; a hash at the end of a word stays, as in C#")
    func closingHashes() {
        #expect(LineNormalizer.normalize("# Skills ##").text == "Skills")
        #expect(LineNormalizer.normalize("## Experience with C#").text == "Experience with C#")
        #expect(LineNormalizer.normalize("### F# and C# ###").text == "F# and C#")
    }

    @Test("A day or a month before a date is the date's, not a numbered item's")
    func dayBeforeADate() {
        for raw in ["1. April 2020 – heute", "3. März 2019", "12. 2019 – 3. 2020"] {
            let line = LineNormalizer.normalize(raw)
            #expect(line.markup == .none, "\(raw)")
            #expect(line.text == raw)
        }
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

    @Test("Only Markdown's escapes lose their backslash; any other backslash is the person's text")
    func escapes() {
        #expect(LineNormalizer.normalize("C\\# and F\\# on C:\\Users\\lena").text == "C# and F# on C:\\Users\\lena")
    }

    @Test("A star or a quote's mark that is the person's text stays")
    func contentMarks() {
        #expect(LineNormalizer.normalize("Hotel 4* e 5* a Rimini, *Acme*.").text == "Hotel 4* e 5* a Rimini, Acme.")
        #expect(LineNormalizer.normalize(">5 years in C++").text == ">5 years in C++")
        #expect(LineNormalizer.normalize("> Quoted").text == "Quoted")
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

    @Test("A hyphen right after a letter at the end marks a word broken across lines; a soft one is told from a visible one")
    func hyphenAtTheEnd() {
        #expect(LineNormalizer.normalize("Verantwortung als Projekt\u{AD}").text == "Verantwortung als Projekt")
        #expect(LineNormalizer.normalize("Verantwortung als Projekt").lineEnd == .plain)
        #expect(LineNormalizer.normalize("Verantwortung als Projekt-").lineEnd == .hyphen)
        #expect(LineNormalizer.normalize("Verantwortung als Projekt\u{AD}").lineEnd == .softHyphen)
        #expect(LineNormalizer.normalize("2019 -").lineEnd == .plain)
    }
}
