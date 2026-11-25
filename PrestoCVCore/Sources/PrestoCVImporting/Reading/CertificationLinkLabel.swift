/// The labels of a certification's web address: "Credential URL: https://…", "Verifica online https://…" (#283). Only
/// these explicit labels count: a bare noun such as "Certificate", "Badge" or "Zertifikat" names a certification as well
/// as its link, so a line of such a noun with an address is a certification of its own (split rather than merge).
enum CertificationLinkLabel {

    /// The labels of the six languages, compared as headings are: case, accents and punctuation do not count.
    private static let labels = Set([
        "link", "url", "credential url", "credential link", "certificate link", "certificate url", "verify", "verify at",
        "verification", "verification link", "verification url", "view credential", "view certificate", "see credential",
        "show credential", "more info", "more information",
        "collegamento", "verifica", "verifica online", "maggiori informazioni",
        "verknüpfung", "zertifikatslink", "verifizieren", "überprüfen", "überprüfung", "weitere informationen",
        "enlace", "verificar", "verificación", "más información",
        "lien", "vérifier", "vérification", "plus d'informations",
        "ligação", "verificação", "mais informações",
    ].map(SectionVocabulary.key))

    /// Whether the text is only the label of a link.
    static func isLabel(_ text: String) -> Bool { labels.contains(SectionVocabulary.key(text)) }
}
