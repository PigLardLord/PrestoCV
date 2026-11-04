/// The closed vocabulary of German (ADR 0023), written as `DescriptionText.normalized` writes a word: lower case,
/// without accents, an elided article as a word of its own; but for the forms of to be and the auxiliaries, which keep them.
extension Vocabulary {
    static let german = Words(
        /// Articles, prepositions, pronouns, auxiliaries, conjunctions and subordinators.
        function: """
        aber alle alles als am an andere anderen anderer anderes ans auch auf aus ausserdem ausserhalb bei beim bevor
        bin bis bist da dabei dafuer dafur damals damit danach dann daran darauf daraus das dass davor dazu dein deine
        dem den denn der des dich die dir dort du durch ein eine einem einen einer eines einige es fuer fur ganz gegen
        gehabt gewesen geworden gut habe haben habt hast hat hatte hatten hattest hattet hier ich im immer in
        innerhalb ins ist jede jeden jeder jedes jetzt man manche mein meine meinem meinen meiner meines mich mir mit
        nach nachdem noch obwohl oder schon sehr sei seid seit sich sind so sobald solche solcher sondern sowie sowohl
        um und uns unser unsere unserem unseren unserer unter viele vom von vor waehrend wahrend war waren warst wart
        was weil welche welchem welchen welcher welches wem wen wer wessen wie wieder wir wo wobei wofuer wofur worden
        wurde wurden wurdest wurdet zu zudem zum zur zwischen
        """,
        /// Verbs of a CV: their inflected forms, the infinitives set apart.
        verbs: """
        abgeschliesst abgeschlossen absolviere absolvierend absolviert absolvierte absolvierten angestellt arbeite
        arbeitend arbeitet arbeitete arbeiteten arbeitte arbeitten aufgebaut ausbildete ausgebildet baue bauend baut
        baute bauten begann beginne beginnend beginnt beginnte beginnten begonnen beschaeftigt beschaftigt betreue
        betreuend betreut betreute betreuten bilde bildend bildet bildete bildeten bildte bildten bleibe bleibt blieb
        eingearbeitet eingefuehrt eingefuhrt eingestellt entwickele entwickelend entwickelt entwickelte entwickelten
        erhalte erhielt erlangt erreicht erwarb erwerbe erworben fuehre fuehrend fuehrt fuehrte fuehrten fuhre fuhrend
        fuhrt fuhrte fuhrten gearbeitet geblieben gefuehrt gefuhrt gegangen gegruendet gegrundet gehe geht gekocht
        gekommen gelehrt geleitet gelernt gemacht gepflegt gesprochen gestalte gestaltend gestaltet gestaltete
        gestalteten gestaltte gestaltten gewechselt ging kam koche kochend kocht kochte kochten komme kommt
        koordiniere koordinierend koordiniert koordinierte koordinierten lehre lehrt lehrte leite leitend leitet
        leitete leiteten leitte leitten lerne lernt lernte mache macht machte nehme nehmend nehmt nehmte nehmten
        organisiere organisierend organisiert organisierte organisierten pflege pflegend pflegt pflegte pflegten
        realisiere realisierend realisiert realisierte realisierten reduziere reduzierend reduziert reduzierte
        reduzierten schliesse schliessend schliesst schliesste schliessten schloss sprach spreche spricht stelle
        stellend stellt stellte stellten studiere studierend studiert studierte studierten taetig tatig teilgenehmt
        ubernahm ubernehme ubernommen uberwache uberwachend uberwacht uberwachte uberwachten uebernahm uebernehme
        uebernommen ueberwache ueberwachend ueberwacht ueberwachte ueberwachten unterrichte unterrichtend unterrichtet
        unterrichtete unterrichteten unterrichtte unterrichtten unterstuetze unterstuetzend unterstuetzt unterstuetzte
        unterstuetzten unterstutze unterstutzend unterstutzt unterstutzte unterstutzten verantworte verantwortend
        verantwortet verantwortete verantworteten verantwortlich verantwortte verantwortten verbessere verbesserend
        verbessert verbesserte verbesserten verkaufe verkaufend verkauft verkaufte verkauften verlasse verliess
        verwalte verwaltend verwaltet verwaltete verwalteten verwaltte verwaltten wechsele wechselend wechselt
        wechselte wechselten zustaendig zustandig
        """,
        /// The infinitives of the verbs of a CV: no present or past, so they explain nothing and say nothing done.
        infinitives: """
        abschliessen absolvieren abzuschliessen arbeiten aufbauen aufzubauen ausbilden auszubilden bauen beginnen
        betreuen bilden einarbeiten einfuehren einfuhren einstellen einzuarbeiten einzufuehren einzufuhren
        einzustellen entwickelen erhalten erlangen erreichen erwerben fuehren fuhren gehen gestalten gruenden grunden
        kochen kommen koordinieren lehren leiten lernen machen nehmen organisieren pflegen realisieren reduzieren
        schliessen sprechen stellen studieren teilzunehmen ubernehmen uberwachen uebernehmen ueberwachen unterrichten
        unterstuetzen unterstutzen verantworten verbesseren verkaufen verlassen verwalten wechselen
        """,
        /// Words of time, period and unit, and the months.
        time: """
        aktuell april august derzeit dezember ehemalige ehemaliger februar frueher fruehling fruher fruhling
        gegenwaertig gegenwartig herbst heute jahr jahre jahren jahres jahrzehnt januar juli juni maerz mai marz
        momentan monat monate monaten nachher november oktober september sommer spaeter spater stunde stunden tag tage
        tagen teilzeit vollzeit vorher vorherige vorherigen winter woche wochen zuerst zuletzt zurzeit
        """,
        /// Words of level, and the CEFR codes.
        level: """
        a1 a2 anfaenger anfanger b1 b2 c1 c2 experte expertin fliessend fortgeschritten fortgeschrittene
        grundkenntnisse grundlagen mittelstufe muttersprache muttersprachlich niveau stufe zweisprachig
        """,
        /// Words of studying and graduating.
        studying: """
        abschluesse abschluss abschlusse akademie ausbildung bachelor diplom dissertation fachhochschule hochschule
        institut kurs kurse master promotion pruefung pruefungen prufung prufungen schule schulen student studenten
        studentin studien studieren studium universitaet universitaeten universitat universitaten
        """,
        /// Prepositions and adverbs of time, and the conjunctions that join them: what a pure time phrase is made of, with years.
        timePhrase: """
        aktuell am bis damals danach davor derzeit frueher im in jetzt momentan nach oder seit spaeter und vom von vor
        zwischen
        """,
        /// Words of graduating: a time phrase that holds one joins an education entry and gives its end date.
        graduating: """
        abgeschlossen abschliessen abschluss absolviert beendet
        """,
        /// Words that go with them in a graduation phrase.
        graduationFrame: """
        ausbildung gemacht habe ich lehre mein meine meinem meinen meiner meines studium
        """,
        /// The present and past of to be, as written with accents: a verb that says something done on its own.
        beForms: """
        bin bist gewesen ist seid sind war waren warst wart
        """,
        /// The auxiliaries of the perfect, as written with accents: a verb that says something done when a listed form follows it.
        auxiliaries: """
        gehabt geworden habe haben habt hast hat hatte hatten hattest hattet worden wurde wurden wurdest wurdet
        """,
        /// The forms of a verb that say another person than I, as written with accents, in the languages that drop the pronoun.
        otherPersons: """

        """,
        /// The forms of a verb that a noun can be the subject of, as written with accents, in the languages that drop the pronoun.
        thirdPersons: """

        """,
        /// Everyday verbs in the third person, as written with accents: no CV verbs, but the ones a noun before them is the subject of.
        everydayVerbs: """

        """,
        /// Words of negation, doubt or degree, wish or intention, future and condition: in no other list.
        modality: """
        würde würdest würden würdet wäre wärest wärst wären wäret wärt hätte hättest hätten hättet müsste müsstest müssten
        müsstet dürfte dürftest dürften dürftet
        wurde~gern wurde~gerne wurde~lieber traume~davon traume~von
        plane beabsichtige beinahe darf duerfen durfen etwa eventuell falls fast hoffe hoffen kann kannst kaum kein keine
        keinem keinen keiner keines koennen koennte konnen konnte konnten mochte mochten moechte moechten
        moeglicherweise moglicherweise muessen muss mussen musst nicht nichts nie niemals niemand ob ohne sofern soll
        sollen sollte teilweise ungefaehr ungefahr vielleicht wahrscheinlich weder wenn werde werden werdet will
        willst wird wirst wollen wollte wuensche wunsche
        """
    )
}
