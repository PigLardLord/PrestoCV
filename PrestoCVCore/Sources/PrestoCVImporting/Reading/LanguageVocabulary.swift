// MARK: - The words of the languages of a CV

/// The words the import knows about the languages a CV lists, as data: one list per language of the vocabulary. A list
/// is read whatever the language of the CV, as the heading lists are: a CV in English lists "Italiano" as often as
/// "Italian". The lists name a language, a statement of a native speaker, the words of a level, or a label that is no
/// language. They never decide alone where a level belongs: that is the place of a statement beside a name
/// (`LanguageEvidence`, ADR 0027).
enum LanguageVocabulary {

    // MARK: Lookups

    /// Whether a word is the name of a language the lists know.
    static func isName(_ word: String) -> Bool { foldedNames.contains(word.folded) }

    /// The words of a native speaker, in the form `SectionVocabulary.key` gives, to be compared with a key.
    static let nativeKeys: [String] = nativeStatements.values.flatMap { $0 }.map(SectionVocabulary.key)

    /// The words of a level that are no CEFR level, in the form `SectionVocabulary.key` gives.
    static let levelKeys: [String] = levelWords.values.flatMap { $0 }.map(SectionVocabulary.key)

    /// Whether a text is a statement that a language is native, and nothing else: "Native", "Madrelingua".
    static func isNativeStatement(_ text: String) -> Bool {
        nativeKeys.contains(SectionVocabulary.key(text))
    }

    /// Whether a word, or one of the parts of a hyphenated word, is a word of a label that stands beside a level: of a
    /// level, a skill, a certificate or an exam. A name made of such words is no language.
    static func isLabelWord(_ word: String) -> Bool {
        word.folded.split(separator: "-").contains { labelKeys.contains(String($0)) }
    }

    // MARK: Names

    /// The languages a CV lists, by the language they are written in. Only names that are no other common word: a
    /// language that is not here is still read when a level stands next to its name.
    static let names: [CVLanguage: [String]] = [
        .en: [
            "english", "italian", "german", "spanish", "french", "portuguese", "dutch", "chinese", "mandarin", "japanese",
            "arabic", "russian", "polish", "romanian", "greek", "turkish", "catalan", "swedish", "ukrainian", "albanian",
            "korean", "hindi", "galician", "valencian", "basque", "danish", "norwegian", "finnish", "hungarian", "czech",
            "croatian", "serbian", "slovenian", "slovene", "slovak", "bulgarian", "thai", "hebrew", "vietnamese", "indonesian",
            "malay", "persian", "farsi", "urdu", "bengali", "tamil", "punjabi", "swahili", "latvian", "lithuanian", "estonian",
            "icelandic", "irish", "maltese", "esperanto", "afrikaans", "macedonian", "bosnian", "georgian", "armenian",
            "azerbaijani", "kazakh", "uzbek", "mongolian", "nepali", "filipino", "tagalog", "amharic", "somali", "hausa",
            "yoruba", "zulu", "xhosa", "belarusian", "luxembourgish", "kurdish", "pashto", "telugu", "marathi", "gujarati",
            "malayalam", "kannada", "burmese", "khmer", "sinhala", "cantonese", "yiddish", "sanskrit",
        ],
        .it: [
            "inglese", "italiano", "italiana", "tedesco", "spagnolo", "francese", "portoghese", "olandese", "cinese", "mandarino",
            "giapponese", "arabo", "russo", "polacco", "rumeno", "greco", "turco", "catalano", "svedese", "ucraino", "albanese",
            "coreano", "galiziano", "valenciano", "basco", "danese", "norvegese", "finlandese", "ungherese", "ceco", "croato",
            "serbo", "sloveno", "slovacco", "bulgaro", "tailandese", "thai", "ebraico", "vietnamita", "indonesiano", "malese",
            "persiano", "farsi", "urdu", "bengalese", "tamil", "punjabi", "swahili", "lettone", "lituano", "estone", "islandese",
            "irlandese", "gallese", "maltese", "esperanto", "afrikaans", "macedone", "bosniaco", "georgiano", "armeno", "azero",
            "kazako", "uzbeco", "mongolo", "nepalese", "filippino", "tagalog", "amarico", "somalo", "hausa", "yoruba", "zulu",
            "xhosa", "bielorusso", "lussemburghese", "curdo", "pashto", "telugu", "marathi", "gujarati", "malayalam", "kannada",
            "birmano", "khmer", "singalese", "cantonese", "yiddish", "sanscrito",
        ],
        .de: [
            "englisch", "italienisch", "deutsch", "spanisch", "französisch", "portugiesisch", "niederländisch", "chinesisch",
            "japanisch", "arabisch", "russisch", "polnisch", "rumänisch", "griechisch", "türkisch", "katalanisch", "schwedisch",
            "ukrainisch", "albanisch", "koreanisch", "baskisch", "dänisch", "norwegisch", "finnisch", "ungarisch", "tschechisch",
            "kroatisch", "serbisch", "slowenisch", "slowakisch", "bulgarisch", "thailändisch", "thai", "hebräisch", "vietnamesisch",
            "indonesisch", "malaiisch", "persisch", "farsi", "urdu", "bengalisch", "tamil", "punjabi", "suaheli", "lettisch",
            "litauisch", "estnisch", "isländisch", "irisch", "walisisch", "maltesisch", "esperanto", "afrikaans", "mazedonisch",
            "bosnisch", "georgisch", "armenisch", "aserbaidschanisch", "kasachisch", "usbekisch", "mongolisch", "nepalesisch",
            "filipino", "tagalog", "amharisch", "somali", "haussa", "yoruba", "zulu", "xhosa", "belarussisch", "weißrussisch",
            "luxemburgisch", "kurdisch", "paschtu", "telugu", "marathi", "gujarati", "malayalam", "kannada", "birmanisch", "khmer",
            "singhalesisch", "kantonesisch", "jiddisch", "sanskrit",
        ],
        .es: [
            "inglés", "alemán", "español", "castellano", "francés", "portugués", "neerlandés", "chino", "mandarín", "japonés",
            "árabe", "ruso", "polaco", "rumano", "griego", "catalán", "sueco", "ucraniano", "albanés", "coreano", "gallego",
            "valenciano", "català", "valencià", "euskera", "danés", "noruego", "finlandés", "húngaro", "checo", "croata", "serbio", "esloveno",
            "eslovaco", "búlgaro", "tailandés", "hebreo", "vietnamita", "indonesio", "malayo", "persa", "farsi", "urdu",
            "bengalí", "tamil", "punyabí", "suajili", "letón", "lituano", "estonio", "islandés", "irlandés", "galés", "maltés",
            "esperanto", "afrikáans", "macedonio", "bosnio", "georgiano", "armenio", "azerí", "kazajo", "uzbeko", "mongol",
            "nepalí", "filipino", "tagalo", "amárico", "somalí", "hausa", "yoruba", "zulú", "xhosa", "bielorruso", "luxemburgués",
            "kurdo", "pastún", "telugu", "maratí", "guyaratí", "malayalam", "canarés", "birmano", "jemer", "cingalés", "cantonés",
            "yidis", "sánscrito",
        ],
        .fr: [
            "anglais", "italien", "allemand", "espagnol", "français", "portugais", "néerlandais", "chinois", "japonais", "arabe",
            "russe", "polonais", "roumain", "grec", "turc", "catalan", "suédois", "ukrainien", "albanais", "coréen",
            "basque", "danois", "norvégien", "finnois", "hongrois", "tchèque", "croate", "serbe", "slovène", "slovaque",
            "bulgare", "thaï", "thaïlandais", "hébreu", "vietnamien", "indonésien", "malais", "persan", "farsi", "ourdou",
            "bengali", "tamoul", "pendjabi", "swahili", "letton", "lituanien", "estonien", "islandais", "irlandais", "maltais",
            "espéranto", "afrikaans", "macédonien", "bosniaque", "géorgien", "arménien", "azerbaïdjanais", "kazakh", "ouzbek",
            "mongol", "népalais", "tagalog", "amharique", "somali", "haoussa", "yoruba", "zoulou", "xhosa", "biélorusse",
            "luxembourgeois", "kurde", "pachto", "télougou", "marathi", "goujarati", "malayalam", "kannada", "birman", "khmer",
            "cinghalais", "cantonais", "yiddish", "sanskrit",
        ],
        .pt: [
            "inglês", "italiano", "alemão", "espanhol", "francês", "português", "holandês", "neerlandês", "chinês", "japonês",
            "árabe", "russo", "polaco", "polonês", "romeno", "grego", "turco", "catalão", "sueco", "ucraniano", "albanês",
            "coreano", "galego", "basco", "dinamarquês", "norueguês", "finlandês", "húngaro", "checo", "tcheco", "croata",
            "sérvio", "esloveno", "eslovaco", "búlgaro", "tailandês", "hebraico", "vietnamita", "indonésio", "malaio", "persa",
            "farsi", "urdu", "bengali", "tâmil", "punjabi", "suaíli", "letão", "lituano", "estónio", "estoniano", "islandês",
            "irlandês", "galês", "maltês", "esperanto", "afrikaans", "macedónio", "macedônio", "bósnio", "georgiano", "arménio",
            "armênio", "azerbaijano", "cazaque", "usbeque", "mongol", "nepalês", "filipino", "tagalo", "amárico", "somali",
            "hauçá", "iorubá", "zulu", "xhosa", "bielorrusso", "luxemburguês", "curdo", "pachto", "telugu", "marata", "guzerate",
            "malaiala", "canarim", "birmanês", "khmer", "cingalês", "cantonês", "iídiche", "sânscrito",
        ],
    ]

    private static let foldedNames: Set<String> = Set(names.values.flatMap { $0 }.map(\.folded))

    // MARK: Statements and levels

    /// How a CV says that a language is native, by the language it is written in.
    static let nativeStatements: [CVLanguage: [String]] = [
        .en: ["native", "native speaker", "native or bilingual", "mother tongue", "mother tongues", "native language"],
        .it: ["madrelingua", "lingua madre", "nativo", "nativa"],
        .de: ["muttersprache", "muttersprachlich", "muttersprachler", "muttersprachlerin"],
        .es: ["lengua materna", "nativo", "nativa"],
        .fr: ["langue maternelle", "maternelle", "natif"],
        .pt: ["língua materna", "nativo", "nativa"],
    ]

    /// The words of a level that are no CEFR level, by the language they are written in.
    static let levelWords: [CVLanguage: [String]] = [
        .en: [
            "fluent", "fluently", "bilingual", "business fluent", "professional working", "full professional", "limited working",
            "elementary", "conversational", "working knowledge", "basic knowledge", "good", "very good", "proficiency",
            "proficient", "listening", "reading", "writing", "speaking", "spoken interaction", "spoken production",
        ],
        .it: [
            "scolastico", "fluente", "ottimo", "buono", "discreto", "sufficiente", "elementare", "base", "bilingue", "eccellente",
            "capacità di lettura", "capacità di scrittura", "capacità di espressione orale", "comprensione", "parlato", "scritto",
        ],
        .de: [
            "fließend", "verhandlungssicher", "gute kenntnisse", "sehr gute kenntnisse", "grundkenntnisse", "fortgeschritten",
            "konversationssicher",
        ],
        .es: ["fluido", "nivel alto", "nivel medio", "nivel básico", "avanzado", "intermedio", "básico"],
        .fr: ["courant", "bilingue", "notions", "intermédiaire", "avancé", "scolaire", "professionnel", "excellent"],
        .pt: ["fluente", "avançado", "intermédio", "básico"],
    ]

    // MARK: Labels

    /// The words of the labels that stand beside a level and name no language: of a level, a skill, a certificate or an
    /// exam. The words of a native statement and of a level are labels too.
    static let labelWords: [CVLanguage: [String]] = [
        .en: [
            "level", "levels", "skill", "skills", "language", "languages", "grade", "score", "certificate", "certification",
            "diploma", "exam", "test", "course", "class", "cambridge", "ielts", "toefl", "toeic", "cefr", "europass", "overall",
            "total", "written", "oral", "understanding", "comprehension", "interaction", "production", "other", "mother", "tongue",
            "tongues", "speaker", "basic", "intermediate", "advanced", "beginner", "expert", "excellent",
        ],
        .it: [
            "livello", "livelli", "competenza", "competenze", "lingua", "lingue", "voto", "punteggio", "certificato",
            "certificazione", "esame", "corso", "lettura", "scrittura", "ascolto", "orale", "interazione", "produzione", "altre",
            "altra", "madre", "parlante", "intermedio", "avanzato", "esperto",
        ],
        .de: [
            "niveau", "sprachniveau", "stufe", "kenntnisse", "sprache", "sprachen", "sprachkenntnisse", "note", "zertifikat",
            "zertifizierung", "diplom", "prüfung", "kurs", "goethe", "telc", "testdaf", "dsh", "lesen", "schreiben", "sprechen",
            "hören", "verstehen", "mündlich", "schriftlich", "zweisprachig", "gut", "sehr", "ausgezeichnet", "andere", "weitere",
            "experte",
        ],
        .es: [
            "nivel", "niveles", "competencia", "idioma", "idiomas", "lengua", "lenguas", "nota", "puntuación", "certificado",
            "certificación", "examen", "prueba", "curso", "dele", "comprensión", "lectura", "escritura", "expresión", "escrito",
            "hablado", "interacción", "producción", "materna", "bilingüe", "bueno", "otros", "otras", "alto", "medio", "experto",
        ],
        .fr: [
            "niveau", "niveaux", "compétence", "langue", "langues", "note", "certificat", "diplôme", "examen", "cours", "delf",
            "dalf", "compréhension", "lecture", "écriture", "expression", "écrit", "parlé", "maternelle", "bon", "autres",
            "expert",
        ],
        .pt: [
            "nível", "níveis", "competência", "língua", "línguas", "idioma", "idiomas", "nota", "pontuação", "certificado",
            "certificação", "exame", "teste", "curso", "compreensão", "leitura", "escrita", "expressão", "escrito", "falado",
            "interação", "produção", "materna", "bilíngue", "bom", "outras", "outros", "especialista",
        ],
    ]

    private static let labelKeys: Set<String> = Set(
        (labelWords.values.flatMap { $0 } + nativeKeys + levelKeys).flatMap { $0.folded.split(separator: " ").map(String.init) }
    )
}
