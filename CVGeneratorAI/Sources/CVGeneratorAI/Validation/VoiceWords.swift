import Foundation

/// The words `Voice` reads a subject by, one list of each in the app's six languages. They are closed and written by hand: a word that is
/// in none of them is a noun or a name, and a noun or a name is never the person.
extension Voice {
    struct Words {
        /// The pronouns of the first person, which are the person as the subject of a clause, as `Word.accented` writes them.
        let firstPerson: Set<String>
        /// The pronouns of the third person: someone else. The pronouns of the third person are no word of the closed vocabulary either.
        let thirdPerson: Set<String>
        /// The pronouns of a third person, as the subject or the object of a clause ("he", "him", "lui", "ihm"), as `Word.accented`
        /// writes them: a clause that holds one names another person, and gives no contact (see `Voice.namesAnotherPerson`). No
        /// pronoun of a thing ("it") is among them.
        let otherPeople: Set<String>
        /// The pronouns that address the reader ("you"): someone else, unless the clause is about the person (see `Voice`).
        let reader: Set<String>
        /// The forms of the first person that an object takes ("me", "mich", "moi"), as the reader's clause says "reach me".
        let objects: Set<String>
        /// The forms of the verbs by which the reader contacts or finds someone ("reach", "contact", "write", "call", "email", "find";
        /// "contattare", "scrivete"; "erreichen", "du erreichst"; "contactez"; "contactar"; "contate"), written without accents: an
        /// infinitive, an imperative or a form of the reader, no form the person says of themselves.
        let contactVerbs: Set<String>
        /// The forms of those verbs that hold the person as their object ("contattarmi", "scrivimi", "contáctame"), written without
        /// accents.
        let contactingThePerson: Set<String>
        /// The words of the reader's lead-in to a verb of contacting, besides the pronouns of the reader and the function words, written
        /// without accents: a modal of the reader and the words of an invitation ("feel free to", "don't hesitate to"; "puoi", "non
        /// esitate a"; "du kannst", "zögern Sie nicht"; "vous pouvez", "n'hésitez pas à"; "puedes", "no dudes en"; "pode", "não hesite").
        let leadIns: Set<String>
        /// The words that may stand between a verb of contacting and its object, as `Word.accented` writes them: the particle and the
        /// preposition the verb takes ("reach out to me", "scrivere al mio responsabile", "contactar a mi jefe", "ligue para mim") and,
        /// in German, the reader of an imperative ("Erreichen Sie mich").
        let beforeTheObject: Set<String>
        /// The possessives of the first person, singular and plural: "my sister" is someone else.
        let possessives: Set<String>
        /// The possessives of the third person ("her email", "su hermana"): someone else's, whatever they own.
        let otherPossessives: Set<String>
        /// The articles, which may stand before a possessive that starts a clause: "il mio responsabile".
        let articles: Set<String>
        /// What a noun follows, in the languages whose verbs the device does not tag (Italian, Spanish, French and Portuguese): an article,
        /// a possessive or a simple preposition. A form of a verb after one of them is a noun ("do ensino", "il mio lavoro", "au travail"),
        /// not a verb. English and German, whose verbs the device tags, have no simple prepositions in this list.
        let nounSigns: Set<String>
        /// The prepositions and the like that open a phrase of time or place ("in Rome", "dal 2016", "seit 2016", "as a nurse"): what
        /// follows is the phrase's own, and no subject.
        let prepositions: Set<String>
        /// The fields of the person that a possessive may own ("my email", "il mio inglese", "meine E-Mail"), written without accents:
        /// what a contact, a profile, a language, a skill, an interest or a part of the CV (experience, education, a job) is called, the
        /// names of languages, and the words that qualify them ("personal", "current", "e" of "e-mail"). No word for a person is among
        /// them: a possession of a person is never one.
        let fields: Set<String>
        /// The words that name a contact ("email", "phone", "portfolio", "linkedin", "contact details"), written without accents: the
        /// person's possession of one that is a field gives the person's contact ("My email is me@example.com"), and a label made of them
        /// gives it too ("Email: me@example.com"). "Contact" and "details" are no fields: "my contact" is a person.
        let contactFields: Set<String>
        /// The words of a references section ("reference", "referee", "recommendation"; "referente", "Referenz", "référence"...), written
        /// without accents: from the first sentence that holds one, no contact is the person's (see `Grounding`).
        let references: Set<String>
        /// The forms by which the person is reachable ("reached", "contacted", "reachable"; "raggiungibile", "erreichbar", "joignable"),
        /// written without accents: with the person as their subject they give the person's contact ("I can be reached at ...").
        let reachable: Set<String>
        /// The words that make the word before them its owner, as `Word.accented` writes them: the "s" of English "Anna's email".
        let genitives: Set<String>

        init(
            firstPerson: String, thirdPerson: String, otherPeople: String, reader: String, objects: String, leadIns: String, contactVerbs: String,
            contactingThePerson: String,
            beforeTheObject: String, possessives: String, otherPossessives: String, articles: String, prepositions: String,
            simplePrepositions: String, fields: String, contactFields: String, references: String, reachable: String, genitives: String = ""
        ) {
            self.firstPerson = Self.accented(firstPerson)
            self.thirdPerson = Self.accented(thirdPerson)
            self.otherPeople = Self.accented(otherPeople)
            self.reader = Self.accented(reader)
            self.objects = Self.accented(objects)
            self.leadIns = Self.folded(leadIns)
            self.contactVerbs = Self.folded(contactVerbs)
            self.contactingThePerson = Self.folded(contactingThePerson)
            self.beforeTheObject = Self.accented(beforeTheObject)
            self.possessives = Self.accented(possessives)
            self.otherPossessives = Self.accented(otherPossessives)
            self.articles = Self.accented(articles)
            self.prepositions = Self.accented(prepositions)
            nounSigns = self.articles.union(self.possessives).union(Self.accented(simplePrepositions))
            self.fields = Self.folded(fields)
            self.contactFields = Self.folded(contactFields)
            self.references = Self.folded(references)
            self.reachable = Self.folded(reachable)
            self.genitives = Self.accented(genitives)
        }

        private static func accented(_ blob: String) -> Set<String> {
            Set(blob.split(whereSeparator: { $0.isWhitespace }).map { DescriptionText.normalized(String($0), foldingAccents: false) })
        }

        private static func folded(_ blob: String) -> Set<String> {
            Set(blob.split(whereSeparator: { $0.isWhitespace }).map { DescriptionText.normalized(String($0)) })
        }
    }

    static let words: [Vocabulary.Language: Words] = [
        .english: Words(
            firstPerson: "i we",
            thirdPerson: "he she they it",
            otherPeople: "he she they him her them",
            reader: "you",
            objects: "me myself",
            leadIns: "feel free please hesitate don t do not can could may",
            contactVerbs: "reach contact write call email phone text find",
            contactingThePerson: "",
            beforeTheObject: "out to",
            possessives: "my our",
            otherPossessives: "her his their its",
            articles: "a an the",
            prepositions: """
            about above across after against along among around as at before behind below beside between beyond by during for from in
            inside into near of off on onto out outside over since through throughout till to toward towards under until upon with within
            """,
            simplePrepositions: "",
            fields: """
            name email e mail address phone mobile cell telephone number website site page homepage portfolio blog profile github linkedin
            pages profiles emails addresses numbers phones websites sites link links url urls
            location city town title profession language languages skills interests hobbies personal professional main own
            native english italian german spanish french portuguese dutch russian chinese japanese arabic polish romanian turkish
            experience education studies degree career background strengths qualifications training role position job duties responsibilities
            achievements work projects goals objectives cv resume summary current first last previous latest recent
            """,
            contactFields: """
            email e mail address phone mobile cell telephone number website site page homepage portfolio blog profile github linkedin
            pages profiles emails addresses numbers phones websites sites link links url urls contact contacts details info information
            """,
            references: "reference references referee referees recommendation recommendations",
            reachable: "reached contacted reachable contactable",
            genitives: "s"
        ),
        .italian: Words(
            firstPerson: "io noi",
            thirdPerson: "lui lei loro egli ella essi esse",
            otherPeople: "lui lei loro egli ella essi esse",
            reader: "tu voi",
            objects: "me mi",
            leadIns: "puoi potete può possono non esitate esitare esiti pure",
            contactVerbs: """
            contattare contatta contattate raggiungere raggiungi raggiungete scrivere scrivi scrivete chiamare chiama chiamate telefonare
            telefona telefonate trovare trovate
            """,
            contactingThePerson: """
            contattarmi contattami contattatemi raggiungermi raggiungimi raggiungetemi scrivermi scrivimi scrivetemi chiamarmi chiamami
            chiamatemi telefonarmi telefonami telefonatemi trovarmi trovami trovatemi
            """,
            beforeTheObject: "a al allo alla ai agli alle all",
            possessives: "mio mia miei mie nostro nostra nostri nostre",
            otherPossessives: "suo sua suoi sue loro",
            articles: "il lo la i gli le l un uno una",
            prepositions: """
            a ad agli ai al all alla alle allo come da dagli dai dal dall dalla dalle dallo degli dei del dell della delle dello di dopo
            durante entro fino fra in negli nei nel nell nella nelle nello per presso prima sugli sui sul sull sulla sulle sullo su tra verso
            """,
            simplePrepositions: "di a da in con su per tra fra del dello della dei degli delle dell al allo alla ai agli alle all dal dallo dalla dai dagli dalle dall nel nello nella nei negli nelle nell sul sullo sulla sui sugli sulle sull",
            fields: """
            nome email e mail indirizzo telefono telefonino cellulare numero sito pagina portfolio blog profilo github linkedin citta residenza titolo
            professione lingue competenze interessi hobby personale professionale principale
            pagine profili indirizzi numeri siti link lingua madrelingua materna nativa
            inglese italiano tedesco spagnolo francese portoghese olandese russo cinese giapponese arabo polacco rumeno turco
            esperienza esperienze formazione studi laurea diploma carriera background punti forza qualifiche ruolo posizione lavoro incarichi mansioni
            responsabilita risultati progetti obiettivi cv curriculum riepilogo attuale primo prima ultimo ultima precedente recente
            """,
            contactFields: """
            email e mail indirizzo telefono telefonino cellulare numero sito pagina portfolio blog profilo github linkedin pagine profili
            indirizzi numeri siti link contatti contatto recapito recapiti
            """,
            references: "referente referenti referenza referenze raccomandazione raccomandazioni",
            reachable: "raggiungibile raggiungibili reperibile reperibili contattabile contattabili"
        ),
        .german: Words(
            firstPerson: "ich wir",
            thirdPerson: "er sie",
            otherPeople: "er sie ihn ihm ihnen",
            reader: "du",
            objects: "mich mir",
            leadIns: "kannst könnt können gerne gern zögern zögere nicht bitte",
            contactVerbs: "erreichen erreichst kontaktieren kontaktierst schreiben schreibst schreib anrufen rufen rufst ruf mailen finden findest",
            contactingThePerson: "",
            beforeTheObject: "sie an",
            possessives: "mein meine meinen meinem meiner meines unser unsere unseren unserem unserer unseres",
            otherPossessives: "sein seine seinen seinem seiner seines ihr ihre ihren ihrem ihrer ihres",
            articles: "der die das den dem des ein eine einen einem einer eines",
            prepositions: """
            ab als am an auf aus bei beim bis durch für gegen im in mit nach seit über um unter von vom vor während zu zum zur
            """,
            simplePrepositions: "",
            fields: """
            name email emailadresse mailadresse e mail adresse anschrift telefon telefonnummer rufnummer handy handynummer mobiltelefon nummer website webseite seite homepage portfolio blog profil
            github linkedin wohnort ort stadt titel beruf berufsbezeichnung sprachen kenntnisse fähigkeiten interessen hobbys hobbies
            persönliche berufliche haupt
            seiten profile adressen nummern link links url muttersprache erstsprache sprache
            englisch italienisch deutsch spanisch französisch portugiesisch niederländisch russisch chinesisch japanisch arabisch polnisch
            rumänisch türkisch
            erfahrung erfahrungen ausbildung studium abschluss karriere hintergrund stärken qualifikationen weiterbildung rolle position
            tätigkeit aufgaben verantwortung erfolge arbeit projekte ziele lebenslauf aktuelle aktueller erste erster letzte letzter frühere
            """,
            contactFields: """
            email emailadresse mailadresse e mail adresse anschrift telefon telefonnummer rufnummer handy handynummer mobiltelefon nummer
            website webseite seite homepage portfolio blog profil github linkedin seiten profile adressen nummern link links url kontakt
            kontakte kontaktdaten
            """,
            references: "referenz referenzen referenzperson referenzpersonen empfehlung empfehlungen",
            reachable: "erreichbar"
        ),
        .spanish: Words(
            firstPerson: "yo nosotros nosotras",
            thirdPerson: "él ella ellos ellas",
            otherPeople: "él ella ellos ellas",
            reader: "tú usted ustedes vosotros vosotras",
            objects: "me mí",
            leadIns: "puedes puede pueden podéis no dudes dude duden dudar",
            contactVerbs: """
            contactar contacta contacte contactad contacten escribir escribe escriba escribid escriban llamar llama llame llamad llamen
            localizar encontrar
            """,
            contactingThePerson: """
            contactarme contáctame contácteme contactadme contáctenme escribirme escríbeme escríbame escribidme escríbanme llamarme
            llámame llámeme llamadme llámenme localizarme encontrarme encuéntrame encuéntreme
            """,
            beforeTheObject: "a al",
            possessives: "mi mis nuestro nuestra nuestros nuestras",
            otherPossessives: "su sus",
            articles: "el la los las un una unos unas",
            prepositions: """
            a al ante bajo con como de del desde durante en entre hacia hasta para por sobre tras
            """,
            simplePrepositions: "de del a al en con por para sin sobre entre desde hasta",
            fields: """
            nombre email e mail correo electrónico dirección teléfono móvil celular número sitio web página portfolio blog perfil
            github linkedin ubicación ciudad título profesión idiomas habilidades competencias intereses aficiones personal profesional
            principal
            páginas perfiles direcciones números sitios enlace enlaces link lengua materna idioma nativo
            inglés italiano alemán español francés portugués neerlandés ruso chino japonés árabe polaco rumano turco
            experiencia formación estudios título carrera trayectoria fortalezas cualificaciones capacitación rol puesto trabajo empleo funciones
            responsabilidades logros proyectos objetivos currículum resumen actual primer primera último última anterior reciente
            """,
            contactFields: """
            email e mail correo electrónico dirección teléfono móvil celular número sitio web página portfolio blog perfil github linkedin
            páginas perfiles direcciones números sitios enlace enlaces link contacto contactos datos
            """,
            references: "referencia referencias recomendación recomendaciones",
            reachable: "localizable localizables contactable contactables"
        ),
        .french: Words(
            firstPerson: "je j nous",
            thirdPerson: "il elle ils elles",
            otherPeople: "il elle ils elles lui eux",
            reader: "tu vous",
            objects: "me m moi",
            leadIns: "pouvez peux peut n ne pas hésitez hésite hésiter",
            contactVerbs: "contacter contactez contacte joindre joignez écrire écrivez écris appeler appelez téléphoner téléphonez trouver trouvez",
            contactingThePerson: "",
            beforeTheObject: "à au aux",
            possessives: "ma mon mes notre nos",
            otherPossessives: "sa son ses leur leurs",
            articles: "le la les l un une des",
            prepositions: """
            après avant avec chez comme d dans de depuis des du en entre jusqu par pendant pour sous sur vers à au aux
            """,
            simplePrepositions: "de d du des à au aux en dans avec pour sur par chez",
            fields: """
            nom email e mail courriel électronique adresse téléphone portable mobile numéro site web page portfolio blog profil github linkedin
            ville titre profession langues compétences intérêts loisirs personnel professionnel principal
            pages profils adresses numéros sites lien liens langue maternelle
            anglais italien allemand espagnol français portugais néerlandais russe chinois japonais arabe polonais roumain turc
            expérience formation études diplôme carrière parcours points forts qualifications rôle poste travail emploi missions responsabilités
            réalisations projets objectifs cv résumé actuel actuelle premier première dernier dernière précédent précédente récent
            """,
            contactFields: """
            email e mail courriel électronique adresse téléphone portable mobile numéro site web page portfolio blog profil github linkedin
            pages profils adresses numéros sites lien liens contact contacts coordonnées
            """,
            references: "référence références recommandation recommandations",
            reachable: "joignable joignables contactable contactables"
        ),
        .portuguese: Words(
            firstPerson: "eu nós",
            thirdPerson: "ele ela eles elas",
            otherPeople: "ele ela eles elas",
            reader: "você vocês tu",
            objects: "me mim",
            leadIns: "pode podem podes não hesite hesitem hesitar",
            contactVerbs: """
            contatar contactar contate contacte contatem contactem contata contacta escrever escreva escrevam escreve ligar ligue liguem
            chamar chame chamem encontrar encontre
            """,
            contactingThePerson: "",
            beforeTheObject: "a ao à para",
            possessives: "meu minha meus minhas nosso nossa nossos nossas",
            otherPossessives: "seu sua seus suas dele dela deles delas",
            articles: "o a os as um uma uns umas",
            prepositions: """
            ao aos após até com como da das de desde do dos durante em entre na nas no nos pela pelas pelo pelos para por sobre à às
            """,
            simplePrepositions: "de do da dos das em no na nos nas com por para ao aos à às pelo pela pelos pelas",
            fields: """
            nome email e mail eletrônico correio endereço telefone telemóvel telemovel celular número site página portfolio blog perfil github linkedin
            localização cidade título profissão idiomas habilidades competências interesses hobbies pessoal profissional principal
            páginas perfis endereços números sites link links língua materna idioma nativo
            inglês italiano alemão espanhol francês português holandês russo chinês japonês árabe polonês romeno turco
            experiência formação estudos diploma carreira trajetória pontos fortes qualificações cargo função trabalho emprego atribuições
            responsabilidades conquistas projetos objetivos currículo resumo atual primeiro primeira último última anterior recente
            """,
            contactFields: """
            email e mail eletrônico correio endereço telefone telemóvel telemovel celular número site página portfolio blog perfil github
            linkedin páginas perfis endereços números sites link links contato contatos contacto contactos dados
            """,
            references: "referência referências recomendação recomendações",
            reachable: "contactável contactáveis contatável contatáveis"
        ),
    ]

    /// The words of every language, for a description whose language is not known: but for the words that mean something else in another
    /// language, which are left out, as they are in `Vocabulary`: English "I" is the Italian plural article, and Italian "mi" (me) the
    /// Spanish "my".
    static let everyWord = Words(
        firstPerson: union(\.firstPerson, without: ["i"]), thirdPerson: union(\.thirdPerson), otherPeople: union(\.otherPeople),
        reader: union(\.reader),
        objects: union(\.objects, without: every(\.possessives)), leadIns: union(\.leadIns),
        contactVerbs: union(\.contactVerbs), contactingThePerson: union(\.contactingThePerson), beforeTheObject: union(\.beforeTheObject),
        possessives: union(\.possessives), otherPossessives: union(\.otherPossessives), articles: union(\.articles), prepositions: union(\.prepositions),
        simplePrepositions: "", fields: union(\.fields), contactFields: union(\.contactFields), references: union(\.references),
        reachable: union(\.reachable), genitives: union(\.genitives)
    )

    private static func union(_ list: KeyPath<Words, Set<String>>, without excluded: Set<String> = []) -> String {
        every(list).subtracting(excluded).joined(separator: " ")
    }

    private static func every(_ list: KeyPath<Words, Set<String>>) -> Set<String> {
        words.values.reduce(into: Set<String>()) { $0.formUnion($1[keyPath: list]) }
    }
}
