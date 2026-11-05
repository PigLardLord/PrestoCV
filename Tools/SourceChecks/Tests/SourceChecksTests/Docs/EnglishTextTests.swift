import Foundation
import Testing

// MARK: - English Text Tests

/// `EnglishText` tells the language of a text by the common function words in it, and judges a document passage by passage.
/// The documents are checked with it (`DocsAreEnglishTests`), so it has to tell English from the five other languages the app
/// is translated into, including English written as notes and lists, to find the one passage in another language in a
/// document that is mostly English, to refuse another script, and to leave code, links and short texts out of the count.
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

    /// Sentences of one language, each with at least three of the function words of that language.
    static let englishSentences = [
        "The app keeps every CV on the device and does not send it to a server.",
        "A person who wants to share a CV exports it as a PDF, and the file is then handled by the system.",
        "Nothing in the app needs an account, and the settings of a design are kept with the CV that uses it.",
        "The draft is not sent to a server unless the person asks for it.",
        "You can change the font and the colors of a design, and the preview shows the result.",
        "Each export has the same layout as the preview, with the margins of the page.",
    ]

    static let germanSentences = [
        "Die App speichert jeden Lebenslauf auf dem Gerät.",
        "Wer einen Lebenslauf teilen will, exportiert ihn und die Datei wird vom System übernommen.",
        "Für den Export ist kein Konto nötig und die Daten bleiben auf dem Gerät.",
        "Der Entwurf wird nicht an einen Server gesendet, wenn die Person es nicht möchte.",
        "Mit dem Design kann man die Schrift und die Farben ändern.",
        "Auch die Vorschau zeigt den Lebenslauf so, wie er im PDF steht.",
    ]

    static let italianSentences = [
        "Chi vuole condividere un curriculum lo esporta come PDF, e il file viene poi gestito dal sistema della app.",
        "Per nulla nell'app serve un account, e le impostazioni di un modello vengono conservate che lo usa.",
        "Non è necessario un conto, ma l'app può anche funzionare senza rete, come descritto nella pagina.",
        "Il testo che non viene scritto dalla persona più di una volta resta nel documento.",
    ]

    /// `hits` words that only German uses, followed by `filler` words that belong to no language: the text holds `hits` German
    /// function words in `hits + filler` words.
    static func germanText(hits: Int, filler: Int) -> String {
        let functionWords = ["der", "die", "und", "nicht", "mit", "auf"]
        let hitWords = (0..<hits).map { functionWords[$0 % functionWords.count] }
        return (hitWords + Array(repeating: "zebra", count: filler)).joined(separator: " ")
    }

    // MARK: - Telling the language of a text

    @Test("English prose and English notes are English", arguments: [english, notes])
    func englishIsEnglish(sample: Sample) {
        #expect(EnglishText.language(of: sample.text) == .english)
    }

    @Test("Prose in another language is told from English, and from the other languages", arguments: others)
    func otherLanguagesAreTold(sample: Sample) {
        #expect(EnglishText.language(of: sample.text) == sample.language)
    }

    @Test("A text with fewer than three function words of a language is not judged")
    func shortTextsAreNotJudged() {
        #expect(EnglishText.language(of: "Die App speichert jeden Lebenslauf.") == nil)
        #expect(EnglishText.language(of: "Die App und Lebenslauf") == nil)
        #expect(EnglishText.language(of: "") == nil)
    }

    @Test("Three function words judge a text of any length, so a short German sentence is German")
    func fewWordsAreJudgedByTheirFunctionWords() {
        #expect(EnglishText.language(of: "Die App und der Lebenslauf") == .german)
        #expect(EnglishText.language(of: "Die App speichert den Lebenslauf und sendet ihn nicht.") == .german)
        #expect(EnglishText.language(of: "Exports are kept in the app.") == nil)
    }

    @Test("The least number of function words is three, and a text with two says nothing")
    func minimumHitsIsThree() {
        #expect(EnglishText.language(of: Self.germanText(hits: 2, filler: 0)) == nil)
        #expect(EnglishText.language(of: Self.germanText(hits: 3, filler: 0)) == .german)
    }

    @Test("The function words are at least three in a hundred words: three in a hundred judge, three in a hundred and one do not")
    func minimumShareIsThreeInAHundred() {
        #expect(EnglishText.language(of: Self.germanText(hits: 3, filler: 97)) == .german)
        #expect(EnglishText.language(of: Self.germanText(hits: 3, filler: 98)) == nil)
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

    @Test("A language wins only if it has half as many function words again as the next: a tie and a close call say no language")
    func aLanguageWinsByAMargin() {
        let englishHits = "the and of to is"  // five words that only English uses
        let germanHits = "der die und"  // three words that only German uses

        #expect(EnglishText.language(of: "the and of \(germanHits)") == nil, "three against three")
        #expect(EnglishText.language(of: "the and of to \(germanHits)") == nil, "four against three")
        #expect(EnglishText.language(of: "\(englishHits) \(germanHits)") == .english, "five against three")
        #expect(EnglishText.language(of: "\(germanHits) \(englishHits)") == .english, "the order of the words does not matter")
        #expect(EnglishText.language(of: "the and of der die") == .english, "three against two is exactly half as many again")
    }

    @Test("A list of locale codes is no Spanish text")
    func localeCodesAreNoLanguage() {
        #expect(EnglishText.language(of: "en, it, de, es, fr, pt, en, it, de, es, fr, pt") == nil)
    }

    // MARK: - A passage that is not English

    @Test("A passage that mixes two languages is the one that wins by the margin, and nothing when none does")
    func aMixedPassageIsToldByTheMargin() {
        #expect(EnglishText.verdict(of: "the and of to der die und") == nil, "four against three")
        #expect(EnglishText.verdict(of: "the and of to is der die und") == .language(.english), "five against three")
        #expect(EnglishText.verdict(of: "the and of der die und") == nil, "a tie")
        #expect(EnglishText.verdict(of: "the and der die") == nil, "two words of each language say nothing")
        #expect(EnglishText.verdict(of: "der die und nicht to") == .language(.german), "four against none")
    }

    /// The decision records quote examples in the languages of the app inside English sentences.
    @Test("A quotation in another language inside an English sentence or list item is no foreign passage")
    func aQuotationIsNoForeignPassage() {
        let sentence = """
            So "I work with a colleague who speaks French", "Io lavoro con un collega che parla francese" and \
            "Ich leite ein Team, das Kotlin und Swift nutzt" give no French, Kotlin or Swift.
            """
        let item = """
            - denied high levels and a past wish ("not an expert in Swift", "never been fluent in German", \
            "Ich spreche Spanisch, und davon träume ich nicht mehr"): 3;
            """

        #expect(EnglishText.firstNotEnglish(in: sentence) == nil)
        #expect(EnglishText.firstNotEnglish(in: item) == nil)
    }

    @Test("A sentence in another language without quotation marks is a foreign passage")
    func aSentenceInAnotherLanguageIsForeign() {
        let found = EnglishText.firstNotEnglish(in: "The app says it twice. Ich leite ein Team, das Kotlin und Swift nutzt. The end.")

        #expect(found?.verdict == .language(.german))
        #expect(found?.passage == "Ich leite ein Team, das Kotlin und Swift nutzt.")
    }

    @Test("A text in another script is not English, whatever its length", arguments: [
        "Приложение хранит каждое резюме на устройстве и не отправляет его на сервер.",
        "应用程序将每份简历保存在设备上，不会将其发送到服务器。",
        "يحفظ التطبيق كل سيرة ذاتية على الجهاز ولا يرسلها إلى أي خادم.",
    ])
    func otherScriptsAreNotEnglish(text: String) {
        #expect(EnglishText.verdict(of: text) == .otherScript)
        #expect(EnglishText.firstNotEnglish(in: text)?.verdict == .otherScript)
    }

    @Test("English with a Greek letter or two in it is still English")
    func aFewLettersOfAnotherScriptAreNoScript() {
        let text = "The angle α and the angle β add up to the angle of the corner, and the sum is the same for each of them."

        #expect(EnglishText.verdict(of: text) == .language(.english))
        #expect(EnglishText.firstNotEnglish(in: text) == nil)
    }

    @Test("Latin letters with accents are Latin, up to Latin Extended-B and in Latin Extended Additional; the next block is not", arguments: [
        ("été déjà où à là çà ñ ü é", nil),
        ("ɏɏɏɏ", nil),
        ("ḀḀḀḀ", nil),
        ("Phở bánh mì ế ề ể ễ ệ ỿ ỿ", nil),
        ("ɐɐɐɐ", EnglishText.Verdict.otherScript),
        ("ἀἀἀἀ", EnglishText.Verdict.otherScript),
    ] as [(String, EnglishText.Verdict?)])
    func accentedLettersAreLatin(text: String, verdict: EnglishText.Verdict?) {
        #expect(EnglishText.verdict(of: text) == verdict)
    }

    @Test("Another script is a tenth of the letters: ten in a hundred are, nine in a hundred are not")
    func otherScriptNeedsATenthOfTheLetters() {
        let latin = { (count: Int) in String(repeating: "x", count: count) }
        let greek = { (count: Int) in String(repeating: "α", count: count) }

        #expect(EnglishText.verdict(of: "\(latin(90)) \(greek(10))") == .otherScript)
        #expect(EnglishText.verdict(of: "\(latin(91)) \(greek(9))") == nil)
    }

    @Test("Another script needs at least three letters, so two Greek letters alone are no script")
    func otherScriptNeedsThreeLetters() {
        #expect(EnglishText.verdict(of: "α β") == nil)
        #expect(EnglishText.verdict(of: "α β γ") == .otherScript)
    }

    // MARK: - Words

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

    @Test("HTML tags and comments are not counted as words, nor are the words in their attributes")
    func tagsAndCommentsAreLeftOut() {
        let markdown = """
            Look at <img alt="der die und nicht mit auf" src="a.png"> now <!-- der die
            und nicht --> and then.
            """

        #expect(EnglishText.words(in: markdown) == ["look", "at", "now", "and", "then"])
    }

    @Test("Words keep their accents and are split at punctuation")
    func wordsKeepAccents() {
        #expect(EnglishText.words(in: "Schön, zurück — and l'été!") == ["schön", "zurück", "and", "l", "été"])
    }

    // MARK: - Passages

    @Test("A document is read in passages: headings, table rows, list items and sentences, with code and comments left out")
    func passagesAreSplit() {
        let markdown = """
            # Title of the page

            A wrapped paragraph that goes on
            over two lines. A second sentence follows!

            - First item
              continued here
            - Second item

            | Path | What it is |
            |---|---|
            | `x/` | A row. |

            ```swift
            let ignored = "the and of"
            ```

            <!-- hidden comment -->
            Last paragraph.
            """

        #expect(EnglishText.passages(in: markdown) == [
            "# Title of the page",
            "A wrapped paragraph that goes on over two lines.",
            "A second sentence follows!",
            "- First item continued here",
            "- Second item",
            "| Path | What it is |",
            "| | A row. |",
            "Last paragraph.",
        ])
    }

    @Test("A sentence ends at a mark and a space, unless a lowercase letter follows or there is no space", arguments: [
        ("One sentence. Another one! A third? The end.", ["One sentence.", "Another one!", "A third?", "The end."]),
        ("See e.g. the list. Next one.", ["See e.g. the list.", "Next one."]),
        ("It is U.S. text here. Next one.", ["It is U.S. text here.", "Next one."]),
        ("Version 3.5 is out. Next one.", ["Version 3.5 is out.", "Next one."]),
        ("A file.md is read. Next one.", ["A file.md is read.", "Next one."]),
        ("No end mark", ["No end mark"]),
    ] as [(String, [String])])
    func sentencesAreSplitAtTheirEnd(text: String, sentences: [String]) {
        #expect(EnglishText.passages(in: text) == sentences)
    }

    // MARK: - Quotations

    @Test("A short quotation does not count: one sentence of at most twenty words, between straight or curly marks")
    func shortQuotationsDoNotCount() {
        let straight = #"- "gern", "gerne" or "lieber" with a past "wurde" reads as a wish: "Gerne wurde ich in Python geschult" gives no Python."#
        let curly = "The test says \u{201C}Die App speichert jeden Lebenslauf auf dem Gerät.\u{201D} and passes with that."

        #expect(EnglishText.firstNotEnglish(in: straight) == nil)
        #expect(EnglishText.firstNotEnglish(in: curly) == nil)
        #expect(EnglishText.passages(in: curly) == ["The test says and passes with that."])
    }

    @Test("A quotation of more than one sentence is text: each of its sentences is a passage, after the text around it")
    func aQuotationOfSentencesIsText() {
        let curly = "The test says \u{201C}Die App speichert jeden Lebenslauf auf dem Gerät. Wer einen Lebenslauf teilen will, exportiert ihn.\u{201D} and passes with that."

        #expect(EnglishText.passages(in: curly) == [
            "The test says and passes with that.",
            "Die App speichert jeden Lebenslauf auf dem Gerät.",
            "Wer einen Lebenslauf teilen will, exportiert ihn.",
        ])
        #expect(EnglishText.firstNotEnglish(in: curly)?.verdict == .language(.german))
    }

    @Test("A quotation of more than twenty words is text: twenty words between quotation marks do not count, twenty-one do")
    func aLongQuotationIsText() {
        let twenty = "Die App speichert jeden Lebenslauf auf dem Gerät und sendet ihn nie an einen Server, auch nicht für die Sicherung"
        let twentyOne = "Die App speichert jeden Lebenslauf auf dem Gerät und sendet ihn nie an einen Server, auch nicht für die eigene Sicherung"

        #expect(EnglishText.words(in: twenty).count == EnglishText.maximumQuotationWords)
        #expect(EnglishText.firstNotEnglish(in: "The page quotes \"\(twenty)\" as it is.") == nil)
        #expect(EnglishText.firstNotEnglish(in: "The page quotes \"\(twentyOne)\" as it is.")?.passage == twentyOne)
    }

    @Test("A short quotation inside a long one does not count, with curly marks around straight ones or the other way round")
    func aShortQuotationInsideALongOneDoesNotCount() {
        let example = "Die App speichert jeden Lebenslauf auf dem Gerät und nicht auf einem Server."
        let curlyOutside = "The guide says: \u{201C}It shows one example. \"\(example)\" It goes on in English.\u{201D}"
        let straightOutside = "The guide says: \"It shows one example. \u{201C}\(example)\u{201D} It goes on in English.\""

        for markdown in [curlyOutside, straightOutside] {
            #expect(EnglishText.passages(in: markdown) == ["The guide says:", "It shows one example.", "It goes on in English."])
            #expect(EnglishText.firstNotEnglish(in: markdown) == nil)
        }
    }

    @Test("A long quotation inside a long one is text too, so its sentences in another language are found")
    func aLongQuotationInsideALongOneIsText() {
        let german = "Die App speichert jeden Lebenslauf auf dem Gerät. Wer einen Lebenslauf teilen will, exportiert ihn."
        let markdown = "The guide says: \u{201C}It quotes the page: \"\(german)\" The text around it goes on in English.\u{201D}"

        #expect(EnglishText.firstNotEnglish(in: markdown)?.passage == "Die App speichert jeden Lebenslauf auf dem Gerät.")
    }

    @Test("A paragraph in another language between quotation marks, in a document that is otherwise English, is found")
    func aQuotedParagraphIsFound() {
        let german = Self.germanSentences.joined(separator: " ")
        let markdown = "\(Self.english.text)\n\nThe page then says:\n\n\"\(german)\"\n\n\(Self.english.text)"

        let found = EnglishText.firstNotEnglish(in: markdown)

        #expect(found?.verdict == .language(.german))
        #expect(found?.passage == Self.germanSentences[0])
    }

    @Test("Backticks indented four spaces open no fence, so the text in another language after them is found")
    func anIndentedFenceHidesNothing() {
        let markdown = "The page starts in English.\n\n    ```\nDie App speichert jeden Lebenslauf auf dem Gerät.\n"

        #expect(EnglishText.firstNotEnglish(in: markdown)?.verdict == .language(.german))
    }

    @Test("A quotation is no cover: text outside the quotation marks is still judged, and so is text with a mark that has no partner")
    func textOutsideQuotationsIsJudged() {
        let outside = #"The page says "yes". Die App speichert jeden Lebenslauf auf dem Gerät."#
        let unpaired = #"A 5" screen. Die App speichert jeden Lebenslauf auf dem Gerät."#

        #expect(EnglishText.firstNotEnglish(in: outside)?.verdict == .language(.german))
        #expect(EnglishText.firstNotEnglish(in: unpaired)?.verdict == .language(.german))
    }

    @Test("A document in English has no passage in another language")
    func englishDocumentHasNoForeignPassage() {
        let paragraph = Self.englishSentences.joined(separator: " ")
        let list = Self.englishSentences.map { "- \($0)" }.joined(separator: "\n")

        #expect(EnglishText.firstNotEnglish(in: "\(paragraph)\n\n\(list)") == nil)
        #expect(EnglishText.firstNotEnglish(in: Self.english.text) == nil)
        #expect(EnglishText.firstNotEnglish(in: Self.notes.text) == nil)
    }

    @Test("Six English sentences and six German ones in one paragraph are not English: the first German sentence is named")
    func bilingualParagraphHasAForeignPassage() {
        var sentences: [String] = []
        for (en, de) in zip(Self.englishSentences, Self.germanSentences) { sentences += [en, de] }
        let paragraph = sentences.joined(separator: " ")

        let found = EnglishText.firstNotEnglish(in: paragraph)

        #expect(found?.verdict == .language(.german))
        #expect(found?.passage == Self.germanSentences[0])
    }

    @Test("A document that is four tenths Italian is not English: the first Italian paragraph is named")
    func partlyItalianDocumentHasAForeignPassage() {
        let markdown = (Self.englishSentences + Self.italianSentences).joined(separator: "\n\n")

        let found = EnglishText.firstNotEnglish(in: markdown)

        #expect(found?.verdict == .language(.italian))
        #expect(found?.passage == Self.italianSentences[0])
    }

    @Test("A list item in another language is found, and a heading and a table row too")
    func foreignListItemsRowsAndHeadingsAreFound() {
        let item = "- Il testo che non viene scritto dalla persona più di una volta"
        let row = "| `docs/` | Die App speichert den Lebenslauf und sendet ihn nicht. |"
        let heading = "## La app guarda cada currículum en el dispositivo y no lo envía"

        #expect(EnglishText.firstNotEnglish(in: "Fine text.\n\n\(item)")?.verdict == .language(.italian))
        #expect(EnglishText.firstNotEnglish(in: "| Path | What |\n|---|---|\n\(row)")?.verdict == .language(.german))
        #expect(EnglishText.firstNotEnglish(in: "\(heading)\n\nFine text.")?.verdict == .language(.spanish))
    }

    @Test("German inside a code block or a comment is not read")
    func foreignCodeAndCommentsAreNotRead() {
        let markdown = """
            Fine text.

            ```text
            \(Self.germanSentences.joined(separator: "\n"))
            ```

            <!-- \(Self.germanSentences.joined(separator: " ")) -->
            """

        #expect(EnglishText.firstNotEnglish(in: markdown) == nil)
    }

    // MARK: - Translated sections

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

    @Test("Only a heading of the form Language, code is a translated section", arguments: [
        ("## German, de-DE", true),
        ("## Italian, it", true),
        ("## Spanish (Mexico), es-MX", true),
        ("## Portuguese (Portugal), pt-PT", true),
        ("## French, fr-FR", true),
        ("## Chinese (Simplified), zh-Hans", true),
        ("## German, de-DE ", true),
        ("## German, de-DE\r", true),
        ("## Notes, now", false),
        ("## Order, then", false),
        ("## Notes, it", false),
        ("## German, it", false),
        ("## English (U.S.), en-US", false),
        ("## English, en", false),
        ("### German, de-DE", false),
        ("# German, de-DE", false),
        ("German, de-DE", false),
        ("## German de-DE", false),
        ("## German, de-DE and more", false),
    ])
    func translatedHeadings(heading: String, isTranslated: Bool) {
        #expect(EnglishText.isTranslatedHeading(heading) == isTranslated)
    }

    @Test("A section under a heading that names no language is read, so a German text under it is found")
    func germanUnderAPlainHeadingIsRead() {
        let listing = """
            ## English (U.S.), en-US

            The U.S. text stays.

            ## Notes, now

            \(Self.germanSentences.joined(separator: " "))
            """

        let kept = EnglishText.withoutTranslatedSections(listing)

        #expect(EnglishText.firstNotEnglish(in: kept)?.verdict == .language(.german))
    }

    @Test("A translated section ends at the next heading of level one or two, and not before")
    func translatedSectionEndsAtAnHeadingOfItsLevelOrAbove() {
        let markdown = """
            ## German, de-DE

            Deutscher Text.

            ### Subsection

            Mehr deutscher Text.

            # A title of level one

            Back in English.

            ## German, de-DE

            Noch mehr Deutsch.

            ## Last section

            The end.
            """

        let kept = EnglishText.withoutTranslatedSections(markdown)

        #expect(!kept.contains("Deutscher"))
        #expect(!kept.contains("Mehr deutscher"))
        #expect(!kept.contains("Noch mehr"))
        #expect(kept.contains("# A title of level one"))
        #expect(kept.contains("Back in English."))
        #expect(kept.contains("The end."))
    }

    @Test("A heading line inside a code fence starts and ends no section")
    func headingsInCodeFencesAreNotHeadings() {
        let markdown = """
            ## English (U.S.), en-US

            ```markdown
            ## German, de-DE
            ```

            Still English.

            ## German, de-DE

            ```markdown
            ## Another section
            ```

            Still German.
            """

        let kept = EnglishText.withoutTranslatedSections(markdown)

        #expect(kept.contains("Still English."))
        #expect(!kept.contains("Still German."))
    }

    @Test("A heading with a trailing space or a carriage return is recognised, so a file with Windows line endings is read as any other")
    func headingsWithTrailingSpacesAndCarriageReturns() {
        let markdown = "## English (U.S.), en-US \r\n\r\nThe U.S. text stays.\r\n\r\n## German, de-DE \r\n\r\nDer deutsche Text geht.\r\n"

        let kept = EnglishText.withoutTranslatedSections(markdown)

        #expect(kept.contains("The U.S. text stays."))
        #expect(!kept.contains("deutsche"))
    }
}
