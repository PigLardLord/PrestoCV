import Foundation

/// The words that make a sentence the model writes around the facts state a fact of its own (ADR 0031), language by language, as
/// `DescriptionText.normalized` writes them: lower case, without accents. The articles that are also the number one ("un", "uno",
/// "una", "ein", "um", "une") are on no list.
struct WrittenTextWords: Sendable {
    /// Numbers written as words: "five", "cinque", "fünf". A sentence that holds one counts something the person never counted.
    let numbers: Set<String>
    /// The months: a sentence that holds one dates something. English "may" is a verb as often, and is on no list.
    let months: Set<String>
    /// Words of experience, duration and seniority ("experience", "years", "senior"): a sentence that holds one the description does
    /// not write claims a length, a rank or a field of experience ("a nurse with experience in healthcare administration").
    let seniority: Set<String>
    /// Words of negation: a sentence that holds one denies something, which the person never said.
    let negations: Set<String>
    /// Words that name a qualification ("certified", "degree", "abilitazione"): a skill the model writes holds none.
    let qualifications: Set<String>
    /// What a number written as one word is made of besides the numbers themselves: "uno" and the elided tens of "ventuno", the "und"
    /// of "einundzwanzig", the "cientos" of "doscientos".
    private let joiningParts: Set<String>

    init(numbers: String, months: String, seniority: String, negations: String, qualifications: String, joiningParts: String = "") {
        self.numbers = Self.set(of: numbers)
        self.joiningParts = Self.set(of: joiningParts)
        self.months = Self.set(of: months)
        self.seniority = Self.set(of: seniority)
        self.negations = Self.set(of: negations)
        self.qualifications = Self.set(of: qualifications)
    }

    /// The words of `language`, or the English ones when it is not known.
    static func of(_ language: Vocabulary.Language?) -> WrittenTextWords {
        switch language {
        case .italian: italian
        case .german: german
        case .spanish: spanish
        case .french: french
        case .portuguese: portuguese
        case .english, nil: english
        }
    }

    /// Whether `word` is a number written in words: one of the list, or a compound of them ("ventuno", "einundzwanzig",
    /// "doscientos", "twentyone"). A compound is two parts or more and nothing else: "tone" is no number.
    func isNumber(_ word: String) -> Bool {
        numbers.contains(word) || isCompound(Array(word), from: 0, parts: 0)
    }

    private func isCompound(_ characters: [Character], from start: Int, parts: Int) -> Bool {
        guard start < characters.count else { return parts >= 2 }
        for end in stride(from: characters.count, to: start, by: -1) {
            let part = String(characters[start..<end])
            guard numbers.contains(part) || joiningParts.contains(part) else { continue }
            if isCompound(characters, from: end, parts: parts + 1) { return true }
        }
        return false
    }

    private static func set(of blob: String) -> Set<String> {
        Set(blob.split(whereSeparator: { $0.isWhitespace }).map(String.init))
    }

    static let english = WrittenTextWords(
        numbers: """
        one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen
        nineteen twenty thirty forty fifty sixty seventy eighty ninety hundred hundreds thousand thousands million millions
        billion billions dozen dozens
        """,
        months: "january february march april june july august september october november december",
        seniority: """
        experience experiences year years month months week weeks decade decades experienced senior junior seasoned veteran
        principal chief head
        longtime lengthy extensive
        """,
        negations: "not no never nor neither none nothing nobody cannot",
        qualifications: """
        degree degrees diploma diplomas bachelor bachelors master masters mba phd doctorate certificate certificates certified
        certification certifications license licensed licence licenced accredited accreditation qualification qualifications
        qualified chartered registered
        """
    )

    static let italian = WrittenTextWords(
        numbers: """
        due tre quattro cinque sei sette otto nove dieci undici dodici tredici quattordici quindici sedici diciassette
        diciotto diciannove venti trenta quaranta cinquanta sessanta settanta ottanta novanta cento mille mila milione
        milioni miliardo miliardi dozzina dozzine decina decine centinaia migliaia
        """,
        months: "gennaio febbraio marzo aprile maggio giugno luglio agosto settembre ottobre novembre dicembre",
        seniority: """
        esperienza esperienze anno anni mese mesi settimana settimane decennio decenni esperto esperta esperti esperte senior
        junior pluriennale
        pluriennali decennale ventennale veterano veterana
        """,
        negations: "non mai nessuno nessuna nessun niente nulla",
        qualifications: """
        laurea lauree diploma diplomi master dottorato certificato certificata certificati certificazione certificazioni
        abilitazione abilitato abilitata patente iscritto iscritta albo qualifica qualifiche
        """,
        joiningParts: "uno vent trent quarant cinquant sessant settant ottant novant cent"
    )

    static let german = WrittenTextWords(
        numbers: """
        eins zwei drei vier funf fuenf sechs sieben acht neun zehn elf zwolf zwoelf dreizehn vierzehn funfzehn sechzehn
        siebzehn achtzehn neunzehn zwanzig dreißig dreissig vierzig funfzig sechzig siebzig achtzig neunzig hundert
        hunderte tausend tausende million millionen milliarde milliarden dutzend dutzende
        """,
        months: "januar janner februar marz maerz april mai juni juli august september oktober november dezember",
        seniority: """
        erfahrung erfahrungen jahr jahre jahren monat monate monaten woche wochen jahrzehnt jahrzehnte jahrzehnten erfahren
        erfahrene erfahrener
        erfahrenen langjahrig langjahrige langjahriger langjahrigen senior junior leitend leitende leitender leitenden
        """,
        negations: "nicht nie niemals kein keine keinen keinem keiner keines nichts weder",
        qualifications: """
        abschluss bachelor master diplom promotion zertifikat zertifikate zertifiziert zertifizierte zertifizierter
        zertifizierung zertifizierungen lizenz lizenziert approbation approbiert staatlich examiniert examinierte
        qualifikation qualifikationen
        """,
        joiningParts: "ein eine und"
    )

    static let spanish = WrittenTextWords(
        numbers: """
        dos tres cuatro cinco seis siete ocho nueve diez once doce trece catorce quince dieciseis diecisiete dieciocho
        diecinueve veinte treinta cuarenta cincuenta sesenta setenta ochenta noventa cien ciento cientos cientas quinientos quinientas setecientos setecientas novecientos novecientas mil millon millones
        docena docenas decena decenas centenares
        """,
        months: "enero febrero marzo abril mayo junio julio agosto septiembre setiembre octubre noviembre diciembre",
        seniority: """
        experiencia experiencias ano anos mes meses semana semanas decada decadas experto experta expertos expertas
        experimentado experimentada
        experimentados experimentadas senior junior veterano veterana dilatada amplia
        """,
        negations: "no nunca jamas ningun ninguno ninguna nada ni tampoco",
        qualifications: """
        grado titulo licenciatura diploma master maestria doctorado certificado certificada certificados certificacion
        certificaciones licencia colegiado colegiada titulado titulada acreditado acreditada
        """,
        joiningParts: "uno un una veinti"
    )

    static let french = WrittenTextWords(
        numbers: """
        deux trois quatre cinq six sept huit neuf dix onze douze treize quatorze quinze seize vingt trente quarante
        cinquante soixante cent cents quatrevingt quatrevingts vingts mille million millions milliard milliards douzaine douzaines dizaine dizaines
        centaine centaines
        """,
        months: "janvier fevrier mars avril mai juin juillet aout septembre octobre novembre decembre",
        seniority: """
        experience experiences an ans annee annees mois semaine semaines decennie decennies expert experte experts expertes
        experimente experimentee
        experimentes experimentees senior junior chevronne chevronnee confirme confirmee
        """,
        negations: "ne n pas jamais aucun aucune rien ni nul nulle",
        qualifications: """
        diplome diplomee diplomes licence master doctorat certificat certificats certifie certifiee certification
        certifications agree agreee habilitation qualification qualifications
        """
    )

    static let portuguese = WrittenTextWords(
        numbers: """
        dois duas tres quatro cinco seis sete oito nove dez onze doze treze catorze quatorze quinze dezesseis dezasseis
        dezessete dezassete dezoito dezenove dezanove vinte trinta quarenta cinquenta sessenta setenta oitenta noventa cem
        cento duzentos duzentas trezentos trezentas quatrocentos quatrocentas quinhentos quinhentas seiscentos seiscentas setecentos
        setecentas oitocentos oitocentas novecentos novecentas centenas mil milhao milhoes dezena dezenas duzia duzias
        """,
        months: "janeiro fevereiro marco abril maio junho julho agosto setembro outubro novembro dezembro",
        seniority: """
        experiencia experiencias ano anos mes meses semana semanas decada decadas experiente experientes senior junior
        veterano veterana
        especialista vasta
        """,
        negations: "nao nunca jamais nenhum nenhuma nada nem",
        qualifications: """
        licenciatura bacharelado mestrado doutorado doutoramento diploma certificado certificada certificados certificacao
        certificacoes licenca habilitacao habilitado habilitada qualificacao
        """
    )
}
