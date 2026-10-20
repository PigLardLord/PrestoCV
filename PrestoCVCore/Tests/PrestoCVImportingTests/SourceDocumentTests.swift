import Testing
@testable import PrestoCVImporting

@Suite("Building the source document from pasted text")
struct SourceDocumentTests {

    private func build(_ text: String) -> (SourceDocument, [LeftOutText]) {
        DocumentBuilder.build(lines: PlainTextReader.lines(of: text).map { RawLine(text: $0) }, format: .pastedText)
    }

    private func texts(_ document: SourceDocument) -> [String] {
        document.blocks.map { document.text(of: $0.span) }
    }

    @Test("Every line break of every platform splits lines")
    func lineBreaks() {
        #expect(PlainTextReader.lines(of: "a\r\nb\rc\nd\u{2028}e") == ["a", "b", "c", "d", "e"])
    }

    @Test("Blocks keep their text, and the canonical text joins them with line breaks and their cells with tabs")
    func canonicalText() {
        let (document, _) = build("Giulia Bianchi\n\nEsperienza\n2019 – oggi\tInfermiera")
        #expect(texts(document) == ["Giulia Bianchi", "Esperienza", "2019 – oggi\tInfermiera"])
        #expect(document.text == "Giulia Bianchi\nEsperienza\n2019 – oggi\tInfermiera")
        #expect(document.blocks[2].cells.map { document.text(of: $0) } == ["2019 – oggi", "Infermiera"])
        #expect(document.blocks[1].followsGap)
        #expect(document.blocks[2].followsGap == false)
    }

    @Test("Spans count Unicode scalars, so accents and emoji take what they take on every platform")
    func spansCountScalars() {
        let (document, _) = build("Città: Torino 📍\nRésumé")
        #expect(document.blocks[1].span == SourceSpan(16, 22))
        #expect(document.text(of: document.blocks[1].span) == "Résumé")
    }

    @Test("Markdown headings, list items and bold lines are told apart")
    func kinds() {
        let (document, _) = build("# Giulia Bianchi\n**Esperienza**\n- Assistenza ai pazienti")
        #expect(document.blocks.map(\.kind) == [.heading(level: 1), .line, .listItem])
        #expect(document.blocks[1].isEmphasized)
    }

    @Test("A word broken by a hyphen at the end of a line is joined when the next line goes on in lower case")
    func hyphenation() {
        let (document, _) = build("- Verantwortung als Projekt-\nleiter für drei Teams\n- Schulung von Mitarbei-\nTern")
        #expect(texts(document) == ["Verantwortung als Projektleiter für drei Teams", "Schulung von Mitarbei-", "Tern"])
    }

    @Test("A wrapped line of a list item or of prose goes on in the same block")
    func wrappedLines() {
        let (document, _) = build("- Led the migration of the app to SwiftUI and\nshipped it to 2 million people\nSkills\nswift")
        #expect(texts(document) == ["Led the migration of the app to SwiftUI and shipped it to 2 million people", "Skills", "swift"])
    }

    @Test("Rules and table separators are left out as markup, and the row above a separator is a table header")
    func tables() {
        let (document, leftOut) = build("| Lingua | Livello |\n|---|---|\n| Inglese | C1 |\n---")
        #expect(document.blocks.map(\.kind) == [.tableHeader, .line])
        #expect(leftOut.map(\.reason) == [.markup, .markup])
    }

    @Test("A chat assistant's opening and closing sentences are left out, and nothing else")
    func chatter() {
        let answer = """
        Certo! Ecco il tuo CV in formato professionale:

        # Giulia Bianchi
        Infermiera

        ## Esperienza
        - Assistenza ai pazienti

        Fammi sapere se vuoi una versione più breve o in inglese!
        """
        let (document, leftOut) = build(answer)
        #expect(texts(document) == ["Giulia Bianchi", "Infermiera", "Esperienza", "Assistenza ai pazienti"])
        #expect(leftOut.filter { $0.reason == .chatter }.map(\.text) == [
            "Certo! Ecco il tuo CV in formato professionale:", "Fammi sapere se vuoi una versione più breve o in inglese!",
        ])
    }

    @Test("A first line that is the CV itself is not chatter")
    func noChatter() {
        let (document, leftOut) = build("Sure Tanaka\nSoftware engineer")
        #expect(texts(document) == ["Sure Tanaka", "Software engineer"])
        #expect(leftOut.isEmpty)
    }
}
