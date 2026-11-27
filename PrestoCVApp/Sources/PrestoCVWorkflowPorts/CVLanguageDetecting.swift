import PrestoCVDomain

/// The language a CV's own words are written in, among the languages a PDF can be written in (#407). The export sheet
/// asks it once, for a CV that keeps no language yet, and keeps the answer in the CV: the headings then stay in that
/// language. Nil when the words do not tell one. Reading the words takes time, so the sheet awaits it off the main
/// actor (R19).
public protocol CVLanguageDetecting: Sendable {
    func language(of cv: CV, among languages: [DocumentLanguage]) async -> DocumentLanguage?
}
