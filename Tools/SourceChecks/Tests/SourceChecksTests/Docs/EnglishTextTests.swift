import Foundation
import Testing

// MARK: - English Text Tests

/// `EnglishText` tells the language of a document by the share of common function words in it. The documents are checked
/// with it (`DocsAreEnglishTests`), so it has to tell English from the five other languages the app is translated into,
/// including English written as notes and lists, and has to leave code, links and short texts out of the count.
@Suite("Telling English text from other languages")
struct EnglishTextTests {

    /// A text in one language, written for this suite.
    struct Sample: CustomTestStringConvertible, Sendable {
        let language: EnglishText.Language
        let text: String

        var testDescription: String { language.rawValue }
    }

    static let english = Sample(language: .english, text: """
        The app keeps every CV on the device and does not send it to a server. A person who wants to share a CV exports it \
        as a PDF, and the file is then handled by the share sheet of the system. Nothing in the app needs an account, and \
        the settings of a design are kept with the CV that uses it.
        """)

    /// English as the legacy notes of the repository write it: headings, short bullets and a tree of names.
    static let notes = Sample(language: .english, text: """
        # Roadmap and recovery plan

        ## Core principles
        1. **Apple-first**: use the native frameworks, PDFKit and WebKit
        2. **Small commits**: each commit is one atomic change
        3. **Easy recovery**: each sprint has checkpoints

        ## Structure
        Domain: UseCases, Entities, Protocols
        Application: Services, Adapters
        Infrastructure: Renderers (needs completion), Storage
        Sprint one: 9 tests passing, file system template management
        """)

    static let others: [Sample] = [
        Sample(language: .german, text: """
            Die App speichert jeden Lebenslauf auf dem Gerät und sendet ihn nicht an einen Server. Wer einen Lebenslauf \
            teilen möchte, exportiert ihn als PDF, und die Datei wird danach vom Dialog des Systems zum Teilen übernommen. \
            Für nichts in der App ist ein Konto nötig, und die Einstellungen eines Designs werden mit dem Lebenslauf gespeichert.
            """),
        Sample(language: .italian, text: """
            L'app conserva ogni curriculum sul dispositivo e non lo invia a un server. Chi vuole condividere un curriculum \
            lo esporta come PDF, e il file viene poi gestito dal foglio di condivisione del sistema. Per nulla nell'app \
            serve un account, e le impostazioni di un modello vengono conservate insieme al curriculum che lo usa.
            """),
        Sample(language: .french, text: """
            L'application garde chaque CV sur l'appareil et ne l'envoie pas à un serveur. Une personne qui veut partager \
            un CV l'exporte en PDF, et le fichier est ensuite pris en charge par la feuille de partage du système. Rien \
            dans l'application ne demande un compte, et les réglages d'un modèle sont conservés avec le CV qui l'utilise.
            """),
        Sample(language: .spanish, text: """
            La aplicación guarda cada currículum en el dispositivo y no lo envía a un servidor. Una persona que quiere \
            compartir un currículum lo exporta como PDF, y el archivo pasa después a la hoja de compartir del sistema. \
            Nada en la aplicación necesita una cuenta, y los ajustes de un diseño se guardan con el currículum que lo usa.
            """),
        Sample(language: .portuguese, text: """
            O aplicativo guarda cada currículo no dispositivo e não o envia para um servidor. Uma pessoa que quer \
            compartilhar um currículo o exporta como PDF, e o arquivo passa depois para a folha de compartilhamento do \
            sistema. Nada no aplicativo precisa de uma conta, e os ajustes de um modelo são guardados com o currículo que o usa.
            """),
    ]

    @Test("English prose and English notes are English", arguments: [english, notes])
    func englishIsEnglish(sample: Sample) {
        #expect(EnglishText.language(of: sample.text) == .english)
    }

    @Test("Prose in another language is told from English, and from the other languages", arguments: others)
    func otherLanguagesAreTold(sample: Sample) {
        #expect(EnglishText.language(of: sample.text) == sample.language)
    }

    @Test("A text of fewer than twenty words is not judged")
    func shortTextsAreNotJudged() {
        #expect(EnglishText.language(of: "Die App speichert jeden Lebenslauf.") == nil)
        #expect(EnglishText.language(of: "") == nil)
    }

    @Test("A text of code and names says no language")
    func codeSaysNoLanguage() {
        let names = Array(repeating: "PDFExportUseCase TemplateSelectionUseCase ExportConfiguration", count: 10).joined(separator: "\n")

        #expect(EnglishText.language(of: names) == nil)
    }

    @Test("A word that two languages share counts for neither")
    func sharedWordsCountForNone() {
        let shared = String(repeating: "a in no as ", count: 8)

        #expect(EnglishText.language(of: shared) == nil)
    }

    @Test("Code, inline code and link targets are not counted as words")
    func codeAndLinkTargetsAreLeftOut() {
        let markdown = """
            Read [the guide](docs/the-guide-of-the-and-to-for.md) and run `swift test --package-path the/and/of`.

            ```bash
            the and of to is are that this with for not be by it
            ```

            See https://example.com/the/and/of for more.
            """

        #expect(EnglishText.words(in: markdown) == ["read", "the", "guide", "and", "run", "see", "for", "more"])
    }

    @Test("Words keep their accents and are split at punctuation")
    func wordsKeepAccents() {
        #expect(EnglishText.words(in: "Schön, zurück — and l'été!") == ["schön", "zurück", "and", "l", "été"])
    }

    @Test("The sections of the store listing in a language other than English are left out, and nothing else")
    func translatedListingSectionsAreLeftOut() {
        let listing = """
            # App Store listing

            Intro that stays.

            ## English (U.S.), en-US

            The U.S. text stays.

            ## German, de-DE

            Der deutsche Text geht.

            ### A subsection of German

            Auch dieser Text geht.

            ## English (U.K.), en-GB

            The U.K. text stays.

            ## Portuguese (Brazil), pt-BR

            O texto portugues vai.
            """

        let kept = EnglishText.withoutTranslatedSections(listing)

        #expect(kept.contains("Intro that stays."))
        #expect(kept.contains("The U.S. text stays."))
        #expect(kept.contains("The U.K. text stays."))
        #expect(!kept.contains("deutsche"))
        #expect(!kept.contains("Auch dieser"))
        #expect(!kept.contains("portugues"))
        #expect(!kept.contains("## German"))
    }

    @Test("A heading that does not end in a language code starts no translated section")
    func plainHeadingsAreKept() {
        let markdown = """
            ## Settings for every localization

            Text that stays.

            ## Notes for App Review, in short

            More text that stays.
            """

        #expect(EnglishText.withoutTranslatedSections(markdown) == markdown)
    }
}
