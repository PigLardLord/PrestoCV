import Foundation
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

/// The language a description is mostly written in, for the words that mean one thing in one language and another in another
/// ("no" is a denial in Spanish and English, and "in the" in Portuguese). The sanitiser's detector says it when the app gives
/// one; this tells when it does not, where the NaturalLanguage framework is there.
enum LanguageGuess {
    /// The BCP 47 tag of the language of `text`, or nil when the framework cannot tell.
    static func tag(of text: String) -> String? {
        #if canImport(NaturalLanguage)
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage?.rawValue
        #else
        return nil
        #endif
    }
}
