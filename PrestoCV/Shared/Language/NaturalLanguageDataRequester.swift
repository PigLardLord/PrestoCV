import NaturalLanguage

/// Asks the NaturalLanguage framework to download a language's data. Whether the download succeeded is read again at the next draft
/// (`CVDataSanitizer.requireLanguageData`), so its outcome is not kept here.
struct NaturalLanguageDataRequester: LanguageDataRequesting {
    func requestLexicalClassData(forLanguage language: String) {
        NLTagger.requestAssets(for: NLLanguage(rawValue: language), tagScheme: .lexicalClass) { _, _ in }
    }
}
