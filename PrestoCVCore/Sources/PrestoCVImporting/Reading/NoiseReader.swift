/// Finds the blocks that are no part of the CV and leaves them out with their reason: the consent to the processing of
/// data, a template's explanations and footers, page numbers, and the place, date and name of a signature.
enum NoiseReader {

    static func read(into findings: inout Findings) {
        let document = findings.document
        for block in document.blocks {
            let text = document.text(of: block.span)
            let folded = text.folded
            if isConsent(text) {
                findings.leaveOut(block, .consent)
            } else if templateMarkers.contains(where: { folded.hasPrefix($0) || folded.contains($0) }) {
                findings.leaveOut(block, .templateText)
            } else if isPageNumber(text) {
                findings.leaveOut(block, .pageNumber)
            }
        }
        readSignature(into: &findings)
    }

    // MARK: Consent

    /// A sentence of six words or more in which the person authorises the processing of their data: an act of consent
    /// in the first person and the data it is about. A course on data protection has the subject and no act, and a
    /// course on consent names the act as a noun: both stay in the CV.
    static func isConsent(_ text: String) -> Bool {
        guard text.words.count >= 6 else { return false }
        let folded = text.folded
        if ownData.contains(where: { folded.contains($0) }) { return true }
        let spoken = spaced(folded)
        return acts.contains { spoken.contains($0) } && subjects.contains { folded.contains($0) }
    }

    /// The words of a text between single spaces, so that a phrase is found only as whole words.
    private static func spaced(_ folded: String) -> String {
        " " + folded.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).joined(separator: " ") + " "
    }

    // MARK: Page numbers

    /// "Page 2 of 3", "Seite 2 von 3", "Pagina 2 di 3", "2 / 3", "- 2 -", or a number alone. Two numbers with no word
    /// between them are a page of a count of pages only when each is one digit: "12/96" is a month and a year.
    static func isPageNumber(_ text: String) -> Bool {
        let words = text.folded.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        guard !words.isEmpty, words.count <= 5 else { return false }
        let numbers = words.filter { $0.allSatisfy(\.isNumber) }
        guard (1...2).contains(numbers.count), numbers.allSatisfy({ $0.count <= 3 }) else { return false }
        let others = words.filter { !$0.allSatisfy(\.isNumber) }
        if others.isEmpty, numbers.count == 2, numbers.contains(where: { $0.count > 1 }) { return false }
        return others.allSatisfy { pageWords.contains($0) }
    }

    private static let pageWords: Set<String> = ["page", "pages", "of", "pagina", "di", "seite", "von", "pagina", "de", "sur", "p", "pag", "s", "pg"]

    // MARK: Signature

    /// Among the last blocks of the main column, a line of a place and a full date ("Berlin, 12.03.2026"), the labels of
    /// a signature, and the name signed under them.
    private static func readSignature(into findings: inout Findings) {
        let document = findings.document
        let main = document.blocks.filter { ($0.column ?? 0) == 0 && !findings.consumedBlocks.contains($0.index) }
        let last = Array(main.suffix(4))
        var signed = false
        for block in last {
            let text = document.text(of: block.span)
            let key = SectionVocabulary.key(text)
            if signatureLabels.contains(key) || signatureLabels.contains(where: { key.hasPrefix($0 + " ") }) && text.words.count <= 6 {
                findings.leaveOut(block, .signature)
                signed = true
            } else if isPlaceAndDate(text) {
                findings.leaveOut(block, .signature)
                signed = true
            } else if signed, HeaderReader.looksLikeName(text) {
                // Strict on purpose: a name with a word of a list ("Thomas Kiel") stays visible, which loses nothing
                findings.leaveOut(block, .signature)
            }
        }
    }

    /// A short line with one full date and at most a place before it.
    static func isPlaceAndDate(_ text: String) -> Bool {
        guard text.words.count <= 7 else { return false }
        let dates = DateReader.periods(in: text)
        guard dates.count == 1, let date = dates.first, date.period.end == nil, date.period.start.month != nil else { return false }
        let dateText = text[date.range]
        let numbers = dateText.split(whereSeparator: { !$0.isNumber })
        let hasDay = numbers.count >= 3 || text[..<date.range.lowerBound].last.map(\.isNumber) == true
            || text[..<date.range.lowerBound].trimmingSpaces().split(separator: " ").last.map { $0.allSatisfy { $0.isNumber || $0 == "." } } == true
        let before = text[..<date.range.lowerBound]
        let beforeWords = before.words.filter { !$0.allSatisfy(\.isNumber) }
        return hasDay && beforeWords.count <= 3 && text[date.range.upperBound...].trimmingSpaces().isEmpty
    }

    private static let signatureLabels: Set<String> = Set([
        "ort datum", "ort und datum", "luogo e data", "luogo data", "lugar y fecha", "lugar fecha", "lieu et date", "lieu date",
        "local e data", "local data", "place and date", "place date", "firma", "unterschrift", "signature", "assinatura",
        "in fede", "fait à", "fait a",
    ].map(SectionVocabulary.key))

    // MARK: Markers

    /// The act of consent, in the first person and as whole words ("I consent", "autorizzo", "willige ... ein"): the noun
    /// of the act ("consent", "consenso", "Einwilligung") is also the subject of a course.
    private static let acts = [
        "autorizzo", "autorizza", "acconsento", "acconsente", "consento", "mio consenso",
        "i consent", "hereby consent", "i authorise", "i authorize", "hereby authorise", "hereby authorize", "i agree", "my consent",
        "willige", "stimme zu", "bin einverstanden", "erklare mich", "mein einverstandnis",
        "autorizo", "acepto", "consiento", "mi consentimiento", "aceito", "consinto", "meu consentimento",
        "autorise", "accepte", "consens", "mon consentement",
    ].map { spaced($0.folded) }

    /// What the consent is about: the data of the person and the law that protects it.
    private static let subjects = [
        "dati personali", "trattamento dei dati", "d.lgs. 196", "d. lgs. 196", "dlgs 196", "196/2003", "regolamento ue 2016/679",
        "reg. ue 2016/679", "ai sensi del gdpr", "gdpr 679/16", "dsgvo", "datenschutz", "personenbezogene", "protección de datos", "datos personales", "lopd",
        "rgpd", "protection des données", "données personnelles", "dados pessoais", "personal data", "tratamento dos meus dados",
    ].map(\.folded)

    /// A sentence in the first person about one's own data is a consent with no other word.
    private static let ownData = [
        "trattamento dei miei dati", "tratamento dos meus dados", "tratamiento de mis datos", "verarbeitung meiner",
        "traitement de mes données", "processing of my personal data",
    ].map(\.folded)

    private static let templateMarkers = [
        "acquisite nel corso della vita e della carriera", "[ indicare", "[indicare", "indicare la madrelingua",
        "descrivere tali competenze", "inserire qui ogni altra informazione", "se pertinente, enumerare", "per ulteriori informazioni sul cedefop",
        "pagina - curriculum vitae di", "europass.cedefop.europa.eu", "© unione europea", "© european union", "© union européenne",
        "© europäische union", "© unión europea", "© união europeia", "acquired in the course of life and career",
        "pour plus d'informations sur europass", "per maggiori informazioni su europass",
    ].map(\.folded)
}
