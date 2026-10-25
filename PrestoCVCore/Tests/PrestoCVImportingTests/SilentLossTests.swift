import Foundation
import Testing
@testable import PrestoCVImporting

/// Coverage of the source text, counted outside the readers (ADR 0027): every letter and digit of the document is in a
/// value of the CV, in the text not imported, in the text left out, in a heading, or is part of the structure of a
/// layout (the labels of a form, the word between a role and its employer).
enum Coverage {

    /// The spans a value holds, found by walking it: no list of fields to keep up to date.
    static func spans(in value: Any) -> [SourceSpan] {
        if let span = value as? SourceSpan { return [span] }
        return Mirror(reflecting: value).children.flatMap { spans(in: $0.value) }
    }

    /// The spans that account for text: the CV's values, the text not imported, the text left out and the headings.
    static func accounted(for result: ImportResult) -> [SourceSpan] {
        var spans = Self.spans(in: result.cv)
        spans += result.unplaced.map(\.span)
        spans += result.leftOut.compactMap(\.span)
        spans += headings(of: result.document)
        return spans
    }

    /// A section's heading: its block, or, in a row of cells, its first cell.
    static func headings(of document: SourceDocument) -> [SourceSpan] {
        SectionSegmenter.sections(of: document).compactMap(\.headingSpan)
    }

    /// What the person wrote that no value, no text not imported, no text left out and no heading holds, and that is no
    /// structure: the labels and the connectors of a layout are not content, a line of text is.
    static func lost(in document: SourceDocument, by spans: [SourceSpan]) -> [Piece] {
        Remainder.lost(in: document, by: spans)
    }

    static func lost(_ result: ImportResult) -> [Piece] {
        lost(in: result.document, by: accounted(for: result))
    }

    /// A short description of what was lost, for a failure.
    static func describe(_ pieces: [Piece]) -> [String] {
        pieces.map { "«\($0.text)»" }
    }

    /// The passages of the text not imported that share some of their text with the one before: the list is a set of
    /// separate passages, and nothing the person wrote is shown twice.
    static func overlaps(_ unplaced: [UnplacedText]) -> [String] {
        var found: [String] = []
        var previous: UnplacedText?
        for item in unplaced.sorted(by: { $0.span < $1.span }) {
            if let before = previous, item.span.lowerBound < before.span.upperBound {
                found.append("«\(before.text)» and «\(item.text)»")
            }
            if previous.map({ item.span.upperBound > $0.span.upperBound }) ?? true { previous = item }
        }
        return found
    }
}

/// A repeatable shuffle: the same entry is shuffled the same way on every run and on every machine.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed text: String) {
        state = text.utf8.reduce(14_695_981_039_346_656_037) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 }
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

@Suite("Nothing the person wrote goes without a trace")
struct SilentLossTests {

    private func importText(_ text: String) throws -> ImportResult {
        try ImportCV(pdfReader: ScriptedPDFReader(), limits: .standard).importText(text)
    }

    // MARK: The corpus

    @Test("Every line of every fixture is in a value, in the text not imported, in the text left out or in a heading")
    func corpus() throws {
        for entry in try Corpus.entries() {
            let result = try Corpus.importResult(of: entry)
            let lost = Coverage.lost(result)
            #expect(lost.isEmpty, "\(entry.id): lost \(Coverage.describe(lost))")
            #expect(Coverage.overlaps(result.unplaced).isEmpty, "\(entry.id): shown twice \(Coverage.overlaps(result.unplaced))")
        }
    }

    @Test("The readers place or unplace the corpus themselves: nothing waits for the final sweep")
    func readersAlone() throws {
        for entry in try Corpus.entries() {
            let result = try Corpus.importResult(of: entry)
            let found = try CVReader.readSections(result.document, leftOut: result.leftOut.filter { $0.span == nil }, work: .standard)
            var spans = Coverage.spans(in: found.findings.cv)
            spans += found.findings.unplaced.map(\.span)
            spans += found.findings.leftOut.compactMap(\.span)
            spans += Coverage.headings(of: result.document)
            let lost = Coverage.lost(in: result.document, by: spans)
            #expect(lost.isEmpty, "\(entry.id): the readers lost \(Coverage.describe(lost))")
        }
    }

    @Test("The same lines in another order are still all there: shuffled, reversed and rotated")
    func reordered() throws {
        for entry in try Corpus.entries() where entry.kind == "text" {
            let lines = try Corpus.text(of: entry).split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            var generator = SeededGenerator(seed: entry.id)
            let variants: [(String, [String])] = [
                ("shuffled", lines.shuffled(using: &generator)),
                ("shuffled again", lines.shuffled(using: &generator)),
                ("reversed", Array(lines.reversed())),
                ("rotated", Array(lines.dropFirst(lines.count / 3)) + Array(lines.prefix(lines.count / 3))),
            ]
            for (name, variant) in variants {
                guard let result = try? importText(variant.joined(separator: "\n")) else { continue }
                let lost = Coverage.lost(result)
                #expect(lost.isEmpty, "\(entry.id) \(name): lost \(Coverage.describe(lost))")
                #expect(Coverage.overlaps(result.unplaced).isEmpty, "\(entry.id) \(name): shown twice \(Coverage.overlaps(result.unplaced))")
            }
        }
    }

    @Test("The spans a CV holds are all found by its own list, which a new field must join")
    func sourceSpansAreComplete() throws {
        for entry in try Corpus.entries() {
            let cv = try Corpus.importResult(of: entry).cv
            #expect(Set(cv.sourceSpans) == Set(Coverage.spans(in: cv)), "\(entry.id): the list of spans differs from the spans the CV holds")
        }
    }

    // MARK: Passages of the text not imported

    @Test("Passages that share text are one passage; passages that only touch stay two")
    func mergedPassages() throws {
        let document = try importText("alpha beta gamma delta epsilon zeta").document
        func passage(_ lower: Int, _ upper: Int, _ section: SectionKind = .unknown) -> UnplacedText {
            let span = SourceSpan(lower, upper)
            return UnplacedText(section: section, heading: nil, text: document.text(of: span), span: span)
        }
        // One inside another, one that shares the end of the second, then two that touch at 30
        let merged = Remainder.merged([
            passage(12, 22), passage(30, 35), passage(6, 10), passage(0, 16, .languages), passage(0, 3), passage(23, 30),
        ], in: document)
        #expect(merged.map(\.span) == [SourceSpan(0, 22), SourceSpan(23, 30), SourceSpan(30, 35)])
        #expect(merged.first?.text == document.text(of: SourceSpan(0, 22)))
        #expect(merged.first?.section == .languages, "the section of the first passage that has one")
        #expect(Coverage.overlaps(merged).isEmpty)
    }

    // MARK: A second place of an entry

    @Test("A second place line of an experience or an education is text not imported; the first stays its place")
    func secondPlace() throws {
        let found = try importText("""
        Elena Marini
        elena.marini@example.com

        Esperienza professionale
        Responsabile di progetto
        Regione Esempio
        03/2018 - 12/2020
        Venezia, Italia
        Padova, Italia
        - Coordinamento dei fornitori

        Istruzione
        Master in gestione dei progetti
        Scuola Esempio, Bologna
        2016
        Milano, Italia
        """)
        #expect(found.cv.experience.first?.location?.value == "Venezia, Italia")
        #expect(found.cv.education.first?.location?.value == "Bologna")
        #expect(found.unplaced.map(\.text).contains("Padova, Italia"))
        #expect(found.unplaced.map(\.text).contains("Milano, Italia"))
        #expect(Coverage.lost(found).isEmpty)
    }

    @Test("A place the entry has no other value to hold is not lost with it")
    func placeOfAnEntryWithNoOtherValue() throws {
        let found = try importText("""
        Experience
        Venezia, Italia
        """)
        #expect(found.unplaced.map(\.text).contains("Venezia, Italia") || found.cv.experience.first?.location?.value == "Venezia, Italia")
        #expect(Coverage.lost(found).isEmpty)
    }

    // MARK: The note after a language level

    @Test("What a language's level is followed by is text not imported, and the level stays")
    func languageNote() throws {
        let found = try importText("""
        Languages
        English: B2 (school grade 2, trip to London 2019)
        Deutsch: C1
        """)
        #expect(found.cv.languages.map(\.name.value) == ["English", "Deutsch"])
        #expect(found.cv.languages.map { $0.level?.value } == [.b2, .c1])
        #expect(found.unplaced.map(\.text) == ["English: B2 (school grade 2, trip to London 2019)"])
        #expect(found.unplaced.first?.section == .languages)
        #expect(Coverage.lost(found).isEmpty)
    }

    @Test("A level in words and the note after it are both kept")
    func languageNoteAfterWords() throws {
        let found = try importText("""
        Languages
        French: fluent (lived in Lyon for two years)
        Spanish: A2 – school
        """)
        #expect(found.cv.languages.map(\.name.value) == ["French", "Spanish"])
        #expect(found.cv.languages[1].level?.value == .a2)
        #expect(Coverage.lost(found).isEmpty)
        #expect(found.unplaced.map(\.text) == ["French: fluent (lived in Lyon for two years)", "Spanish: A2 – school"])
    }

    @Test("The words of a level that a level replaces and the note after it are one text not imported, not two")
    func languageWordsReplacedByLevel() throws {
        let found = try importText("""
        Languages
        English: fluent, B2 (certificate)
        Deutsch: C1
        """)
        #expect(found.cv.languages.map { $0.level?.value } == [.b2, .c1])
        #expect(found.cv.languages[0].levelWords == nil)
        #expect(found.unplaced.map(\.text) == ["English: fluent, B2 (certificate)"])
        #expect(Coverage.overlaps(found.unplaced).isEmpty)
        #expect(Coverage.lost(found).isEmpty)
    }

    @Test("A note that a comma parts into several items is one text not imported, with its language")
    func languageNoteInSeveralItems() throws {
        let found = try importText("""
        Languages
        English: good (B1) – reading manuals, software, datasheets
        Deutsch: C1
        """)
        #expect(found.cv.languages.map { $0.level?.value } == [.b1, .c1])
        #expect(found.unplaced.map(\.text) == ["English: good (B1) – reading manuals, software, datasheets"])
        #expect(Coverage.lost(found).isEmpty)
    }

    // MARK: A surname

    @Test("A name given by label and a surname given by label are one name, with both spans")
    func surnameByLabel() throws {
        let found = try importText("""
        Nome: Maria
        Cognome: Rossi
        Email: maria.rossi@example.com

        Esperienza
        Segretaria presso Studio Esempio
        2019 - 2022
        """)
        #expect(found.cv.person.name?.value == "Maria Rossi")
        #expect(found.cv.person.name?.spans.map { found.document.text(of: $0) } == ["Maria", "Rossi"])
        #expect(!found.unplaced.map(\.text).contains { $0.contains("Rossi") })
        #expect(Coverage.lost(found).isEmpty)
    }

    @Test("The surname before the name is still one name, the name first")
    func surnameBeforeName() throws {
        let found = try importText("""
        Cognome: Rossi
        Nome: Maria
        Email: maria.rossi@example.com
        """)
        #expect(found.cv.person.name?.value == "Maria Rossi")
        #expect(Coverage.lost(found).isEmpty)
    }

    @Test("A first name and a last name by label are the name; a name that holds the surname is not doubled")
    func firstAndLastName() throws {
        let both = try importText("""
        Vorname: Anja
        Nachname: Beispiel
        E-Mail: anja.beispiel@example.com
        """)
        #expect(both.cv.person.name?.value == "Anja Beispiel")
        #expect(Coverage.lost(both).isEmpty)

        let doubled = try importText("""
        Name: Anja Beispiel
        Nachname: Beispiel
        E-Mail: anja.beispiel@example.com
        """)
        #expect(doubled.cv.person.name?.value == "Anja Beispiel")
        #expect(Coverage.lost(doubled).isEmpty)
    }

    @Test("A last name with no name beside it is not lost")
    func lastNameAlone() throws {
        let found = try importText("""
        Cognome: Rossi
        Email: maria.rossi@example.com
        """)
        let kept = (found.cv.person.name.map { [$0.value] } ?? []) + found.unplaced.map(\.text)
        #expect(kept.contains { $0.contains("Rossi") })
        #expect(Coverage.lost(found).isEmpty)
    }

    // MARK: Consent and courses

    private static let consents: [(language: String, text: String)] = [
        ("it", "Autorizzo il trattamento dei miei dati personali ai sensi del D.Lgs. 196/2003 e del GDPR."),
        ("de", "Ich willige in die Verarbeitung meiner personenbezogenen Daten gemäß DSGVO ein."),
        ("de", "Hiermit erkläre ich mein Einverständnis zur Verarbeitung meiner Daten nach der Datenschutzgrundverordnung."),
        ("es", "Autorizo el tratamiento de mis datos personales conforme a la normativa de protección de datos."),
        ("es", "Doy mi consentimiento para el tratamiento de mis datos según el RGPD y la LOPD."),
        ("fr", "J'autorise le traitement de mes données personnelles conformément au RGPD."),
        ("fr", "Je donne mon consentement au traitement de mes données selon la protection des données en vigueur."),
        ("pt", "Autorizo o tratamento dos meus dados pessoais, nos termos do RGPD."),
        ("en", "I consent to the processing of my personal data under the GDPR."),
    ]

    private static let courses: [(language: String, heading: String, text: String, subject: String)] = [
        ("de", "Weiterbildung", "05/2024 DSGVO-Grundlagen für die kommunale Praxis (1 Tag)", "DSGVO"),
        ("es", "Formación complementaria", "Curso de protección de datos para administraciones públicas (20 horas)", "protección de datos"),
        ("fr", "Formations complémentaires", "Formation RGPD pour les responsables de traitement (2 jours)", "RGPD"),
        ("it", "Corsi", "Corso sul trattamento dei dati personali in ambito sanitario (8 ore)", "trattamento dei dati personali"),
        ("pt", "Cursos", "Curso de RGPD para gestores de equipas (16 horas)", "RGPD"),
        ("en", "Courses", "GDPR essentials for team leads (2 days)", "GDPR"),
        // The words of a consent in the title of a course: the course is about consent, the person gives none
        ("en", "Courses", "Training on consent to process personal data lawfully", "consent to process"),
        ("it", "Corsi", "Corso su consenso e autorizzazione al trattamento dei dati personali (4 ore)", "autorizzazione"),
        ("de", "Weiterbildung", "Schulung zu Einwilligung und Einverständnis nach der DSGVO für Vereine", "Einwilligung"),
        ("es", "Formación complementaria", "Curso sobre consentimiento y protección de datos personales en la empresa", "consentimiento"),
        ("fr", "Formations complémentaires", "Formation au consentement et à la protection des données personnelles (2 jours)", "consentement"),
        ("pt", "Cursos", "Curso sobre consentimento e proteção de dados pessoais na empresa", "consentimento"),
    ]

    @Test("The consent to data processing is left out, in every language")
    func consentIsLeftOut() throws {
        for consent in Self.consents {
            let found = try importText("Esempio Nome\n\n\(consent.text)")
            #expect(found.leftOut.contains { $0.reason == .consent && $0.text == consent.text }, "\(consent.language): \(consent.text)")
        }
    }

    @Test("A course on data protection is a course, not a consent, in every language")
    func courseIsNotConsent() throws {
        for course in Self.courses {
            let found = try importText("\(course.heading)\n\(course.text)\n")
            #expect(!found.leftOut.contains { $0.reason == .consent }, "\(course.language): left out as a consent: \(course.text)")
            let kept = found.cv.certifications.map(\.name.value) + found.unplaced.map(\.text)
            #expect(kept.contains { $0.contains(course.subject) }, "\(course.language): the course is not shown: \(course.text)")
            #expect(Coverage.lost(found).isEmpty, "\(course.language): \(Coverage.describe(Coverage.lost(found)))")
        }
    }

    @Test("A consent is left out and a course next to it is kept")
    func consentNextToCourse() throws {
        for consent in Self.consents {
            guard let course = Self.courses.first(where: { $0.language == consent.language }) else { continue }
            let found = try importText("\(course.heading)\n\(course.text)\n\n\(consent.text)")
            #expect(found.leftOut.filter { $0.reason == .consent }.map(\.text) == [consent.text], "\(course.language): \(consent.text)")
            #expect(Coverage.lost(found).isEmpty, "\(course.language)")
        }
    }

    // MARK: Dates and page numbers

    @Test("A month and a two-digit year are no page numbers; a page of a count of pages still is")
    func pageNumbers() {
        for text in ["08/92 –", "12/96", "09/89", "06/92", "03/18", "10/12", "01/02", "12/95 –"] {
            #expect(!NoiseReader.isPageNumber(text), "«\(text)» is a date")
        }
        for text in ["2/3", "2 / 3", "1/2", "Page 2 of 3", "Page 1 of 12", "Seite 1 von 2", "Pagina 2 di 3", "Página 2 de 3", "1", "- 2 -", "12"] {
            #expect(NoiseReader.isPageNumber(text), "«\(text)» is a page number")
        }
    }

    @Test("Dates of two numbers are not left out as page numbers")
    func shortDatesAreVisible() throws {
        let found = try importText("""
        Berufserfahrung
        Sachbearbeiterin
        Beispiel GmbH, Kassel
        08/92 –
        12/96
        - Auftragsbearbeitung

        Ausbildung
        Bürokauffrau
        Beispiel AG, Fulda
        09/89
        06/92
        """)
        #expect(!found.leftOut.contains { $0.reason == .pageNumber })
        let kept = found.unplaced.map(\.text) + Coverage.spans(in: found.cv).map { found.document.text(of: $0) }
        for date in ["08/92", "12/96", "09/89", "06/92"] {
            #expect(kept.contains { $0.contains(date) }, "\(date) is nowhere")
        }
        #expect(Coverage.lost(found).isEmpty)
    }
}
