import Testing
import SwiftUI
@testable import PrestoCVNext

/// A language is named in the language the app shows: as it stands in a sentence, and with a capital when it stands
/// alone in a list.
@Suite("LanguageName")
struct LanguageNameTests {

    @Test("a language is named in the app's language, in the case a sentence of that language gives it")
    func namedInTheSentence() {
        #expect(LanguageName.inSentence("en", in: Locale(identifier: "it_IT")) == "inglese")
        #expect(LanguageName.inSentence("it", in: Locale(identifier: "en_US")) == "Italian")
        #expect(LanguageName.inSentence("fr", in: Locale(identifier: "de_DE")) == "Französisch")
    }

    @Test("a language alone in a list starts with a capital, and keeps the rest of its name as it is")
    func namedAlone() {
        #expect(LanguageName.alone("en", in: Locale(identifier: "it_IT")) == "Inglese")
        #expect(LanguageName.alone("es", in: Locale(identifier: "fr_FR")) == "Espagnol")
        #expect(LanguageName.alone("pt", in: Locale(identifier: "en_US")) == "Portuguese")
    }

    @Test("the app's own language is named in itself, as in a sentence")
    func appLanguage() {
        #expect(LanguageName.appLanguage(in: Locale(identifier: "it_IT")) == "italiano")
        #expect(LanguageName.appLanguage(in: Locale(identifier: "de_DE")) == "Deutsch")
        #expect(LanguageName.appLanguage(in: Locale(identifier: "en_US")) == "English")
    }

    @Test("a tag the locale has no name for is shown in capitals")
    func unknownTag() {
        #expect(LanguageName.inSentence("qqq", in: Locale(identifier: "en_US")) == "QQQ")
        #expect(LanguageName.alone("qqq", in: Locale(identifier: "en_US")) == "QQQ")
    }
}
