import Foundation

/// The words with which a line names the issuer of the certification above it: "Issued by Red Cross, 2021" (#304). Only
/// these explicit leads count: a line that merely holds an organisation is an entry of its own (split rather than merge,
/// #283).
enum CertificationIssuerLead {

    /// The leads of the six languages, lower case; the match ignores case and accents.
    static let leads: [String] = [
        "issued by", "offered by", "provided by", "awarded by", "granted by",
        "rilasciato da", "rilasciata da", "emesso da", "emessa da", "offerto da", "offerta da", "fornito da", "erogato da", "conferito da",
        "rilasciato dal", "rilasciata dal", "rilasciato dalla", "rilasciata dalla", "rilasciato dallo", "rilasciata dallo",
        "rilasciato dall'", "rilasciata dall'", "rilasciato dall\u{2019}", "rilasciata dall\u{2019}",
        "emesso dal", "emessa dal", "emesso dalla", "emessa dalla", "emesso dallo", "emessa dallo",
        "emesso dall'", "emessa dall'", "emesso dall\u{2019}", "emessa dall\u{2019}",
        "offerto dal", "offerta dal", "offerto dalla", "offerta dalla", "offerto dallo", "offerta dallo",
        "offerto dall'", "offerta dall'", "offerto dall\u{2019}", "offerta dall\u{2019}",
        "ausgestellt von", "ausgestellt durch", "angeboten von", "bereitgestellt von", "verliehen von", "vergeben von",
        "ausgestellt vom", "angeboten vom", "verliehen vom",
        "emitido por", "emitida por", "expedido por", "expedida por", "ofrecido por", "ofrecida por", "proporcionado por", "otorgado por",
        "délivré par", "délivrée par", "émis par", "émise par", "offert par", "offerte par", "fourni par", "décerné par",
        "emitido pela", "emitido pelo", "emitida pela", "emitida pelo", "oferecido por", "oferecido pela", "oferecido pelo",
        "fornecido por", "fornecido pela", "concedido por",
    ]

    /// The most words an issuer is: a longer line is a sentence, and a sentence is not an organisation.
    static let mostWords = 6

    /// The part of the piece after its lead, when the piece starts with one followed by an organisation.
    static func issuer(in piece: Piece) -> Piece? {
        guard let issuer = afterLead(in: piece) else { return nil }
        return !issuer.isEmpty && issuer.words.count <= mostWords ? issuer : nil
    }

    /// Whether the piece starts with a lead, whatever follows it.
    static func startsWithLead(_ piece: Piece) -> Bool { afterLead(in: piece) != nil }

    /// The part of the piece after its lead. A lead ends at whitespace or a colon, or is itself closed by an apostrophe
    /// ("dall'").
    private static func afterLead(in piece: Piece) -> Piece? {
        let text = piece.text
        for lead in leads {
            guard let found = text.range(of: lead, options: [.anchored, .caseInsensitive, .diacriticInsensitive]) else { continue }
            let rest = text[found.upperBound...]
            let closed = lead.last == "'" || lead.last == "\u{2019}" || (rest.first.map { $0.isWhitespace || $0 == ":" } ?? false)
            guard closed else { continue }
            let start = rest.firstIndex { !$0.isWhitespace && $0 != ":" } ?? text.endIndex
            return piece.sub(start..<text.endIndex).trimmed()
        }
        return nil
    }
}
