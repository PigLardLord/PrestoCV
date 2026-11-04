/// The closed vocabulary of English (ADR 0023), written as `DescriptionText.normalized` writes a word: lower case,
/// without accents, an elided article as a word of its own; but for the forms of to be and the auxiliaries, which keep them.
extension Vocabulary {
    static let english = Words(
        /// Articles, prepositions, pronouns, auxiliaries, conjunctions and subordinators.
        function: """
        a across after again against all along already also although am among an and another any are as at be because
        been before being between beyond both but by d did do does doing done during each either even ever every for
        from had has have having here how i in inside into is it its itself just m me mine my myself of on once one
        ones onto or other our ours ourselves out outside own per quite re s same since so some still such that the then
        there these this those though through throughout till to too toward towards until upon us ve very via was we
        were what whatever when whenever where whereas wherever which while who whoever whom whose why with within you
        your yours yourself
        """,
        /// Verbs of a CV: their inflected forms, the infinitives set apart.
        verbs: """
        advise advised advises advising analyse analysed analyses analysing analyze analyzed analyzes analyzing answer
        answered answering answers approve approved approves approving assist assisted assisting assists attend
        attended attending attends became become becomes becoming began begin beginning begins begun build building
        builds built chair chaired chairing chairs check checked checking checks coach coached coaches coaching
        collaborate collaborated collaborates collaborating complete completed completes completing contribute
        contributed contributes contributing control controled controling controls cook cooked cooking cooks
        coordinate coordinated coordinates coordinating create created creates creating deliver delivered delivering
        delivers design designed designing designs develop developed developing develops direct directed directing
        directs earn earned earning earns educate educated educates educating employ employed employing employs end
        ended ending ends ensure ensured ensures ensuring finish finished finishes finishing focus focused focuses
        focusing found founded founding founds get gets getting got gotten graduate graduated graduates graduating
        guide guided guides guiding handle handled handles handling held help helped helping helps hire hired hires
        hiring hold holding holds implement implemented implementing implements improve improved improves improving
        increase increased increases increasing inspect inspected inspecting inspects install installed installing
        installs instruct instructed instructing instructs introduce introduced introduces introducing join joined
        joining joins launch launched launches launching lead leading leads leave leaves leaving led left made
        maintain maintained maintaining maintains make makes making manage managed manages managing mentor mentored
        mentoring mentors monitor monitored monitoring monitors move moved moves moving negotiate negotiated
        negotiates negotiating obtain obtained obtaining obtains offer offered offering offers open opened opening
        opens operate operated operates operating organise organised organises organising organize organized organizes
        organizing oversaw oversee overseeing overseen oversees participate participated participates participating
        perform performed performing performs prepare prepared prepares preparing produce produced produces producing
        promote promoted promotes promoting provide provided provides providing qualified qualifies qualify qualifying
        ran receive received receives receiving reduce reduced reduces reducing repair repaired repairing repairs
        replace replaced replaces replacing report reported reporting reports respond responded responding responds
        review reviewed reviewing reviews run running runs sell selling sells serve served serves serving sold speak
        speaking speaks spoke spoken start started starting starts studied studies study studying supervise supervised
        supervises supervising support supported supporting supports take taken takes taking taught teach teaches
        teaching test tested testing tests took train trained training trains treat treated treating treats tutor
        tutored tutoring tutors use used uses using volunteer volunteered volunteering volunteers work worked working
        works write writes writing written wrote
        """,
        /// The infinitives of the verbs of a CV: no present or past, so they explain nothing and say nothing done.
        infinitives: """

        """,
        /// Words of time, period and unit, and the months.
        time: """
        ago apr april aug august autumn current currently day days dec december earlier early fall feb february first
        former formerly full fulltime hour hours jan january jul july jun june last late later mar march month months
        next nov november now oct october ongoing part parttime present presently previous previously recently season
        second sep sept september spring summer third time today week weeks winter year years
        """,
        /// Words of level, and the CEFR codes.
        level: """
        a1 a2 advanced b1 b2 basic beginner bilingual c1 c2 elementary expert fluent fluently intermediate level
        mother native proficient tongue upper
        """,
        /// Words of studying and graduating.
        studying: """
        academy bachelor class classes college course courses degree degrees diploma doctorate exam exams graduate
        graduated graduating graduation institute lesson lessons master phd primary school schools secondary student
        students studied studies study studying thesis universities university
        """,
        /// Prepositions and adverbs of time, and the conjunctions that join them: what a pure time phrase is made of, with years.
        timePhrase: """
        after ago and before between by currently during earlier formerly from in later now ongoing or present
        presently previously since still then till to today until
        """,
        /// Words of graduating: a time phrase that holds one joins an education entry and gives its end date.
        graduating: """
        completed finished graduate graduated graduating graduation
        """,
        /// Words that go with them in a graduation phrase.
        graduationFrame: """
        had have i my
        """,
        /// The present and past of to be, as written with accents: a verb that says something done on its own.
        beForms: """
        am are be been being is m re was were
        """,
        /// The auxiliaries of the perfect, as written with accents: a verb that says something done when a listed form follows it.
        auxiliaries: """
        did do does had has have having ve
        """,
        /// The forms of a verb that say another person than I, as written with accents, in the languages that drop the pronoun.
        otherPersons: """

        """,
        /// The forms of a verb that a noun can be the subject of, as written with accents, in the languages that drop the pronoun.
        thirdPersons: """

        """,
        /// Everyday verbs in the third person, as written with accents: no CV verbs, but the ones a noun before them is the subject of.
        everydayVerbs: """
        came collected collects comes cooked cooks danced dances drives drove enjoyed enjoys fished fishes gave gets
        gives goes got hated hates hiked hikes knew knows liked likes lived lives loved loves moved moves needed needs
        owned owns painted paints played plays practiced practices practised practises preferred prefers reads rides
        rode sang saw says sees sings skied skis stayed stays swam swims takes took traveled travelled travels went
        writes wrote
        """,
        /// Words of negation, doubt or degree, wish or intention, future and condition: in no other list.
        modality: """
        aim aimed aims almost barely can cannot could dream dreams gonna hardly hope hoped hopes if intend intended
        intention_of intention_to intends ll may maybe might mostly must nearly neither never no nobody none nor not
        nothing nowhere otherwise partially partly perhaps plan planned planning plans possibly probably scarcely shall
        should slightly somewhat unless want wanted wants whether will wish wished wishes without would
        """
    )
}
