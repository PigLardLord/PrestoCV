import Foundation
@testable import CVGeneratorAI

/// The hand-written sets of the claim check (ADR 0028): sentences in the six languages, each with the personal items a draft could
/// keep and whether the writer claims each one. Accentless forms, wishes, conditionals, denials of basic and high levels, other
/// people's clauses, fronted forms and CV-style fragments. They are invented, generic sentences: no real person is in them.
enum AdversarialSet {
    struct Sentence {
        let id: String
        let language: String
        let description: String
        let items: [(candidate: ClaimCandidate, claimed: Bool)]
    }

    private static func s(_ id: String, _ language: String, _ description: String,
                          _ items: (ClaimCandidate.Kind, String, Bool)...) -> Sentence {
        Sentence(id: id, language: language, description: description,
                 items: items.map { (ClaimCandidate(kind: $0.0, value: $0.1), $0.2) })
    }

    static let sentences: [Sentence] = [
        // English
        s("en-d-like", "en", "I'd like to learn Spanish.", (.language, "Spanish", false)),
        s("en-fact-then-wish", "en", "I speak Spanish and I'd like to learn French.", (.language, "Spanish", true), (.language, "French", false)),
        s("en-not-expert", "en", "I am not an expert in Swift, but I use it every day.", (.skill, "Swift", true)),
        s("en-no-basic", "en", "I have no basic knowledge of German.", (.language, "German", false)),
        s("en-sister", "en", "My sister is a nurse in Turin and speaks French.",
          (.title, "nurse", false), (.place, "Turin", false), (.language, "French", false)),
        s("en-if", "en", "If I had time, I would play chess.", (.interest, "chess", false)),
        s("en-fragment-wish", "en", "Fluent in English, and I'd love to learn German.", (.language, "English", true), (.language, "German", false)),
        s("en-cannot-basic", "en", "I cannot speak German even at a basic level.", (.language, "German", false)),
        s("en-skills-list", "en", "Skills: Python, SQL, Docker.", (.skill, "Docker", true), (.skill, "Python", true)),
        s("en-nurse", "en", "I'm a nurse in Turin.", (.title, "nurse", true), (.place, "Turin", true)),
        s("en-never-used", "en", "I have never used Kotlin.", (.skill, "Kotlin", false)),
        s("en-free-time", "en", "In my free time I go hiking.", (.interest, "hiking", true)),
        s("en-would-work", "en", "I would work as a teacher in Berlin.", (.title, "teacher", false), (.place, "Berlin", false)),
        s("en-fronted-wish", "en", "Spanish, that's what I'd like to learn.", (.language, "Spanish", false)),
        s("en-can", "en", "I can teach chess and I mostly use Swift.", (.skill, "chess", true), (.skill, "Swift", true)),
        // German
        s("de-wurde-accentless", "de", "Am liebsten wurde ich Spanisch lernen.", (.language, "Spanisch", false)),
        s("de-wurde-umlaut", "de", "Am liebsten würde ich Spanisch lernen.", (.language, "Spanisch", false)),
        s("de-speaks", "de", "Ich spreche Spanisch und Englisch.", (.language, "Englisch", true), (.language, "Spanisch", true)),
        s("de-keine-grundkenntnisse", "de", "Ich habe keine Grundkenntnisse in Deutsch.", (.language, "Deutsch", false)),
        s("de-keine-expertin", "de", "Ich bin keine Expertin für Python, nutze es aber täglich.", (.skill, "Python", true)),
        s("de-gerne-accentless", "de", "Gerne wurde ich als Lehrerin in Berlin arbeiten.", (.title, "Lehrerin", false), (.place, "Berlin", false)),
        s("de-schwester", "de", "Meine Schwester arbeitet als Krankenschwester in München.",
          (.title, "Krankenschwester", false), (.place, "München", false)),
        s("de-befoerdert", "de", "Ich wurde 2019 zur Teamleiterin befördert.", (.title, "Teamleiterin", true)),
        s("de-traume", "de", "Ich träume davon, Japanisch zu lernen.", (.language, "Japanisch", false)),
        s("de-kenntnisse-list", "de", "Kenntnisse: SAP, Excel, Buchhaltung.", (.skill, "Excel", true)),
        s("de-nie", "de", "Ich habe nie mit Kotlin gearbeitet.", (.skill, "Kotlin", false)),
        s("de-hatte-wurde", "de", "Wenn ich mehr Zeit hätte, würde ich Gitarre spielen.", (.interest, "Gitarre", false)),
        s("de-fronted-traume", "de", "Spanisch zu lernen, davon träume ich.", (.language, "Spanisch", false)),
        // Italian
        s("it-vorrei", "it", "Vorrei imparare lo spagnolo.", (.language, "spagnolo", false)),
        s("it-parlo", "it", "Parlo inglese e francese.", (.language, "francese", true)),
        s("it-nessuna", "it", "Non ho nessuna conoscenza del tedesco.", (.language, "tedesco", false)),
        s("it-non-esperta", "it", "Non sono esperta di Excel, ma lo uso ogni giorno.", (.skill, "Excel", true)),
        s("it-sorella", "it", "Mia sorella è infermiera a Milano.", (.title, "infermiera", false), (.place, "Milano", false)),
        s("it-sarei", "it", "Sarei felice di lavorare come insegnante a Roma.", (.title, "insegnante", false), (.place, "Roma", false)),
        s("it-sogno", "it", "Sogno di imparare il giapponese.", (.language, "giapponese", false)),
        s("it-infermiera", "it", "Sono un'infermiera di Torino.", (.title, "infermiera", true), (.place, "Torino", true)),
        s("it-mai", "it", "Non ho mai usato Python.", (.skill, "Python", false)),
        s("it-tempo-libero", "it", "Nel tempo libero faccio escursioni.", (.interest, "escursioni", true)),
        s("it-se-avessi", "it", "Se avessi tempo suonerei la chitarra.", (.interest, "chitarra", false)),
        s("it-competenze", "it", "Competenze: Excel, Word, PowerPoint.", (.skill, "Excel", true)),
        s("it-fronted", "it", "Imparare lo spagnolo, è quello che vorrei.", (.language, "spagnolo", false)),
        // Spanish
        s("es-seria-accentless", "es", "Yo seria feliz aprendiendo aleman.", (.language, "alemán", false)),
        s("es-hablo", "es", "Hablo inglés y francés.", (.language, "francés", true)),
        s("es-gustaria", "es", "Me gustaría aprender italiano.", (.language, "italiano", false)),
        s("es-ningun", "es", "No tengo ningún conocimiento de alemán.", (.language, "alemán", false)),
        s("es-no-experta", "es", "No soy experta en Excel, pero lo uso a diario.", (.skill, "Excel", true)),
        s("es-hermana", "es", "Mi hermana es enfermera en Madrid.", (.title, "enfermera", false), (.place, "Madrid", false)),
        s("es-si-tuviera", "es", "Si tuviera tiempo, tocaría la guitarra.", (.interest, "guitarra", false)),
        s("es-enfermera", "es", "Soy enfermera en Sevilla.", (.title, "enfermera", true), (.place, "Sevilla", true)),
        s("es-nunca", "es", "Nunca he usado Python.", (.skill, "Python", false)),
        s("es-queria-accentless", "es", "Queria trabajar como profesora en Valencia.", (.title, "profesora", false), (.place, "Valencia", false)),
        s("es-tiempo-libre", "es", "En mi tiempo libre juego al ajedrez.", (.interest, "ajedrez", true)),
        s("es-idiomas", "es", "Idiomas: inglés (B2), portugués (A2).", (.language, "inglés", true), (.language, "portugués", true)),
        // French
        s("fr-aimerais", "fr", "J'aimerais apprendre l'espagnol.", (.language, "espagnol", false)),
        s("fr-parle", "fr", "Je parle anglais et italien.", (.language, "italien", true)),
        s("fr-aucune", "fr", "Je n'ai aucune notion d'allemand.", (.language, "allemand", false)),
        s("fr-pas-experte", "fr", "Je ne suis pas experte en Excel, mais je l'utilise tous les jours.", (.skill, "Excel", true)),
        s("fr-soeur", "fr", "Ma sœur est infirmière à Lyon.", (.title, "infirmière", false), (.place, "Lyon", false)),
        s("fr-si-accentless", "fr", "Si j'avais le temps, je jouerais aux echecs.", (.interest, "échecs", false)),
        s("fr-reve-accentless", "fr", "Je reve d'apprendre le japonais.", (.language, "japonais", false)),
        s("fr-infirmiere", "fr", "Je suis infirmière à Lille.", (.title, "infirmière", true), (.place, "Lille", true)),
        s("fr-jamais", "fr", "Je n'ai jamais utilisé Python.", (.skill, "Python", false)),
        s("fr-serais", "fr", "Je serais heureuse de travailler comme enseignante a Paris.",
          (.title, "enseignante", false), (.place, "Paris", false)),
        s("fr-temps-libre", "fr", "Pendant mon temps libre, je fais de la randonnée.", (.interest, "randonnée", true)),
        s("fr-langues", "fr", "Langues : anglais (C1), espagnol (B2).", (.language, "espagnol", true)),
        // Portuguese
        s("pt-gostaria-accentless", "pt", "Gostaria de aprender alemao.", (.language, "alemão", false)),
        s("pt-falo", "pt", "Falo inglês e espanhol.", (.language, "espanhol", true)),
        s("pt-nenhum", "pt", "Não tenho nenhum conhecimento de italiano.", (.language, "italiano", false)),
        s("pt-nao-especialista", "pt", "Nao sou especialista em Excel, mas uso todos os dias.", (.skill, "Excel", true)),
        s("pt-irma", "pt", "Minha irmã é enfermeira em Lisboa.", (.title, "enfermeira", false), (.place, "Lisboa", false)),
        s("pt-se-tivesse", "pt", "Se eu tivesse tempo, tocaria violao.", (.interest, "violão", false)),
        s("pt-sonho-accentless", "pt", "Sonho em aprender japones.", (.language, "japonês", false)),
        s("pt-enfermeira", "pt", "Sou enfermeira no Porto.", (.title, "enfermeira", true), (.place, "Porto", true)),
        s("pt-nunca", "pt", "Nunca usei Python.", (.skill, "Python", false)),
        s("pt-seria", "pt", "Seria feliz trabalhando como professora em Coimbra.", (.title, "professora", false), (.place, "Coimbra", false)),
        s("pt-tempo-livre", "pt", "No meu tempo livre, faço caminhadas.", (.interest, "caminhadas", true)),
        s("pt-idiomas", "pt", "Idiomas: inglês (C1), francês (B1).", (.language, "francês", true)),
        // The forms the last iteration of the instruction reads as facts (liking, "had to", lists, a question before a fact, a
        // wish to do better, a plain clause beside a wish), each beside forms that still claim nothing.
        s("en-love-would-love", "en", "I love hiking, and I would love to learn Japanese.",
          (.interest, "hiking", true), (.language, "Japanese", false)),
        s("en-sister-loves", "en", "My sister loves chess.", (.interest, "chess", false)),
        s("en-will-have-to", "en", "I will have to learn German for the new job.", (.language, "German", false)),
        s("en-question-sister", "en", "Do you need a translator? My sister speaks French.", (.language, "French", false)),
        s("en-improve", "en", "I speak German and Spanish, which I'd like to improve.",
          (.language, "German", true), (.language, "Spanish", true)),
        s("en-plain-beside-conditional", "en", "I play chess. If I had more time, I would play the piano.",
          (.interest, "chess", true), (.interest, "piano", false)),
        s("de-mag-moechte", "de", "Ich mag Schach, aber ich möchte Klavier lernen.", (.interest, "Schach", true), (.skill, "Klavier", false)),
        s("de-musste", "de", "Ich musste im Job Englisch sprechen.", (.language, "Englisch", true)),
        s("de-question-only", "de", "Suchen Sie jemanden, der Spanisch spricht?", (.language, "Spanisch", false)),
        s("de-list-of-the-sister", "de", "Kenntnisse meiner Schwester: Excel, SAP.", (.skill, "Excel", false), (.skill, "SAP", false)),
        s("de-plain-beside-wish", "de", "Ich spiele Schach. Ich möchte Gitarre lernen.", (.interest, "Schach", true), (.skill, "Gitarre", false)),
        s("it-piace-piacerebbe", "it", "Mi piace la fotografia; mi piacerebbe imparare il tedesco.",
          (.interest, "fotografia", true), (.language, "tedesco", false)),
        s("it-dovro", "it", "Dovrò imparare il francese.", (.language, "francese", false)),
        s("it-question-only", "it", "Parli tedesco?", (.language, "tedesco", false)),
        s("it-list", "it", "Competenze: Excel, SAP.", (.skill, "Excel", true), (.skill, "SAP", true)),
        s("it-fact-then-wish", "it", "Parlo inglese e vorrei imparare il russo.", (.language, "inglese", true), (.language, "russo", false)),
        s("es-gusta-gustaria-accentless", "es", "Me gusta el ajedrez y me gustaria aprender frances.",
          (.interest, "ajedrez", true), (.language, "francés", false)),
        s("es-tendre-que", "es", "Tendré que aprender alemán para el nuevo trabajo.", (.language, "alemán", false)),
        s("es-list-of-wishes", "es", "Habilidades que quiero aprender: Python, SQL.", (.skill, "Python", false), (.skill, "SQL", false)),
        s("fr-aime-aimerais", "fr", "J'aime la randonnée et j'aimerais apprendre le piano.",
          (.interest, "randonnée", true), (.skill, "piano", false)),
        s("fr-question-fact", "fr", "Vous cherchez une infirmière ? Je suis infirmière à Lyon.",
          (.title, "infirmière", true), (.place, "Lyon", true)),
        s("fr-list", "fr", "Compétences : Excel, Photoshop.", (.skill, "Photoshop", true)),
        s("pt-gosto-gostaria", "pt", "Gosto de xadrez e gostaria de aprender alemão.", (.interest, "xadrez", true), (.language, "alemão", false)),
        s("pt-teria-que", "pt", "Se eu fosse para Berlim, teria que aprender alemão.", (.language, "alemão", false)),
        s("pt-list-of-wishes", "pt", "Idiomas que gostaria de aprender: alemão, russo.",
          (.language, "alemão", false), (.language, "russo", false)),
    ]

    /// The held-out set of the spike of #249: written after its instruction was frozen. The instruction of ADR 0028 was tuned
    /// with it in view, so it is now a regression set.
    static let heldOut: [Sentence] = [
        s("ho-en-lisbon", "en", "Ideally I'd move to Lisbon and teach yoga.", (.place, "Lisbon", false), (.skill, "yoga", false)),
        s("ho-en-pilot", "en", "I hope to become a pilot one day.", (.title, "pilot", false)),
        s("ho-en-figma", "en", "Proficient in Figma; basic knowledge of Blender.", (.skill, "Figma", true), (.skill, "Blender", true)),
        s("ho-en-colleague", "en", "My colleague handles the SAP migration.", (.skill, "SAP", false)),
        s("ho-en-rust", "en", "I don't really know Rust.", (.skill, "Rust", false)),
        s("ho-en-portuguese", "en", "Learning Portuguese is on my list for next year.", (.language, "Portuguese", false)),
        s("ho-en-piano", "en", "I've been teaching piano since 2015.", (.skill, "piano", true)),
        s("ho-de-pilotin", "de", "Ich wurde gerne Pilotin werden.", (.title, "Pilotin", false)),
        s("ho-de-mann", "de", "Mein Mann spricht fließend Russisch.", (.language, "Russisch", false)),
        s("ho-de-fragment", "de", "Fließend Englisch, Grundkenntnisse in Spanisch.", (.language, "Englisch", true), (.language, "Spanisch", true)),
        s("ho-de-java", "de", "Ich hatte nie Gelegenheit, Java zu lernen.", (.skill, "Java", false)),
        s("ho-de-wien", "de", "Irgendwann möchte ich in Wien leben.", (.place, "Wien", false)),
        s("ho-de-graz", "de", "Seit 2018 arbeite ich als Pflegerin in Graz.", (.title, "Pflegerin", true), (.place, "Graz", true)),
        s("ho-de-zeichnen", "de", "Ich konnte nie gut zeichnen.", (.interest, "zeichnen", false)),
        s("ho-it-napoli", "it", "Mi piacerebbe vivere a Napoli.", (.place, "Napoli", false)),
        s("ho-it-fratello", "it", "Mio fratello lavora come cuoco a Bari.", (.title, "cuoco", false), (.place, "Bari", false)),
        s("ho-it-fragment", "it", "Ottimo inglese, francese scolastico.", (.language, "inglese", true), (.language, "francese", true)),
        s("ho-it-russo", "it", "Non conosco affatto il russo.", (.language, "russo", false)),
        s("ho-it-yoga", "it", "Un giorno vorrei insegnare yoga.", (.skill, "yoga", false)),
        s("ho-it-verona", "it", "Dal 2019 gestisco un team di vendita a Verona.", (.place, "Verona", true)),
        s("ho-it-medicina", "it", "Avrei voluto studiare medicina.", (.skill, "medicina", false)),
        s("ho-es-barcelona", "es", "Me encantaria vivir en Barcelona.", (.place, "Barcelona", false)),
        s("ho-es-marido", "es", "Mi marido habla ruso con fluidez.", (.language, "ruso", false)),
        s("ho-es-fragment", "es", "Inglés fluido, francés básico.", (.language, "inglés", true), (.language, "francés", true)),
        s("ho-es-java", "es", "No sé nada de Java.", (.skill, "Java", false)),
        s("ho-es-piloto", "es", "Algún día quiero ser piloto.", (.title, "piloto", false)),
        s("ho-es-bilbao", "es", "Trabajo como cocinera en Bilbao desde 2017.", (.title, "cocinera", true), (.place, "Bilbao", true)),
        s("ho-es-piano", "es", "Tocaria el piano si tuviera tiempo.", (.interest, "piano", false)),
        s("ho-fr-montreal", "fr", "J'adorerais vivre a Montreal.", (.place, "Montréal", false)),
        s("ho-fr-frere", "fr", "Mon frère est boulanger à Nantes.", (.title, "boulanger", false), (.place, "Nantes", false)),
        s("ho-fr-fragment", "fr", "Anglais courant, notions d'italien.", (.language, "anglais", true), (.language, "italien", true)),
        s("ho-fr-russe", "fr", "Je ne connais pas du tout le russe.", (.language, "russe", false)),
        s("ho-fr-pilote", "fr", "Un jour, je voudrais devenir pilote.", (.title, "pilote", false)),
        s("ho-fr-bordeaux", "fr", "Je travaille comme cuisinière à Bordeaux depuis 2016.", (.title, "cuisinière", true), (.place, "Bordeaux", true)),
        s("ho-fr-piano", "fr", "Je ferais du piano si j'avais le temps.", (.interest, "piano", false)),
        s("ho-pt-floripa", "pt", "Adoraria morar em Florianopolis.", (.place, "Florianópolis", false)),
        s("ho-pt-irmao", "pt", "Meu irmão é padeiro em Recife.", (.title, "padeiro", false), (.place, "Recife", false)),
        s("ho-pt-fragment", "pt", "Inglês fluente, noções de italiano.", (.language, "inglês", true), (.language, "italiano", true)),
        s("ho-pt-java", "pt", "Não sei nada de Java.", (.skill, "Java", false)),
        s("ho-pt-piloto", "pt", "Um dia quero ser piloto.", (.title, "piloto", false)),
        s("ho-pt-belem", "pt", "Trabalho como cozinheira em Belém desde 2015.", (.title, "cozinheira", true), (.place, "Belém", true)),
        s("ho-pt-piano", "pt", "Tocaria piano se tivesse tempo.", (.interest, "piano", false)),
    ]

    /// Sentences written before their first run and never used to choose the instruction of ADR 0028: they measure it on wordings
    /// it was not tuned on. Likings and their denials in every language, wishes with other verbs, other people's clauses, past jobs
    /// and CV-style lists.
    static let frozenHeldOut: [Sentence] = [
        // English
        s("fh-en-enjoy", "en", "I enjoy painting and I love cooking.", (.interest, "painting", true), (.interest, "cooking", true)),
        s("fh-en-keen", "en", "I'm keen to learn Italian next year.", (.language, "Italian", false)),
        s("fh-en-manager", "en", "My manager speaks fluent Japanese.", (.language, "Japanese", false)),
        s("fh-en-dont-like", "en", "I don't like golf, but I play tennis every week.", (.interest, "golf", false), (.interest, "tennis", true)),
        s("fh-en-used-to", "en", "I used to work as a chef in Leeds.", (.title, "chef", true), (.place, "Leeds", true)),
        s("fh-en-should", "en", "Should the role require it, I would learn SQL.", (.skill, "SQL", false)),
        s("fh-en-cv", "en", "Tools: Jira, Confluence. Hobbies: climbing.", (.skill, "Jira", true), (.interest, "climbing", true)),
        // German
        s("fh-de-mag", "de", "Ich mag Schach und lese gern Krimis.", (.interest, "Schach", true), (.interest, "Krimis", true)),
        s("fh-de-wurde-gern", "de", "Ich wurde gern segeln lernen.", (.interest, "segeln", false)),
        s("fh-de-kollegin", "de", "Meine Kollegin unterrichtet Französisch in Bremen.",
          (.language, "Französisch", false), (.place, "Bremen", false)),
        s("fh-de-kein-wort", "de", "Ich spreche kein Wort Italienisch.", (.language, "Italienisch", false)),
        s("fh-de-will", "de", "Ich will nächstes Jahr als Erzieherin in Leipzig arbeiten.",
          (.title, "Erzieherin", false), (.place, "Leipzig", false)),
        s("fh-de-seit", "de", "Seit 2016 lebe ich in Kassel und arbeite als Elektrikerin.", (.place, "Kassel", true), (.title, "Elektrikerin", true)),
        s("fh-de-sprachen", "de", "Sprachen: Deutsch (Muttersprache), Englisch (B1).", (.language, "Englisch", true)),
        // Italian
        s("fh-it-piace", "it", "Mi piace il nuoto e adoro la fotografia.", (.interest, "nuoto", true), (.interest, "fotografia", true)),
        s("fh-it-piacerebbe", "it", "Mi piacerebbe imparare il tedesco.", (.language, "tedesco", false)),
        s("fh-it-collega", "it", "Il mio collega usa AutoCAD ogni giorno.", (.skill, "AutoCAD", false)),
        s("fh-it-non-parlo", "it", "Non parlo spagnolo.", (.language, "spagnolo", false)),
        s("fh-it-voglio", "it", "Voglio diventare architetta e trasferirmi a Bologna.", (.title, "architetta", false), (.place, "Bologna", false)),
        s("fh-it-lavoro", "it", "Lavoro come cameriera a Firenze dal 2020.", (.title, "cameriera", true), (.place, "Firenze", true)),
        s("fh-it-se-potessi", "it", "Se potessi, vivrei a Genova.", (.place, "Genova", false)),
        // Spanish
        s("fh-es-encanta", "es", "Me encanta la fotografía y me gusta el ciclismo.",
          (.interest, "fotografía", true), (.interest, "ciclismo", true)),
        s("fh-es-gustaria-accentless", "es", "Me gustaria aprender a bucear.", (.interest, "bucear", false)),
        s("fh-es-jefe", "es", "Mi jefe habla alemán y vive en Bilbao.", (.language, "alemán", false), (.place, "Bilbao", false)),
        s("fh-es-no-hablo", "es", "No hablo francés.", (.language, "francés", false)),
        s("fh-es-quiero", "es", "Quiero trabajar como enfermera en Málaga.", (.title, "enfermera", false), (.place, "Málaga", false)),
        s("fh-es-desde", "es", "Desde 2018 trabajo como electricista en Zaragoza.", (.title, "electricista", true), (.place, "Zaragoza", true)),
        s("fh-es-cv", "es", "Habilidades: Excel, SAP. Aficiones: lectura.", (.skill, "SAP", true), (.interest, "lectura", true)),
        // French
        s("fh-fr-adore", "fr", "J'adore la lecture et j'aime le vélo.", (.interest, "lecture", true), (.interest, "vélo", true)),
        s("fh-fr-voudrais", "fr", "Je voudrais apprendre le chinois.", (.language, "chinois", false)),
        s("fh-fr-collegue", "fr", "Mon collègue parle couramment l'arabe.", (.language, "arabe", false)),
        s("fh-fr-aime-pas", "fr", "Je n'aime pas le football, mais je joue au tennis.", (.interest, "football", false), (.interest, "tennis", true)),
        s("fh-fr-aimerais-accentless", "fr", "J'aimerais travailler comme infirmiere a Toulouse.",
          (.title, "infirmière", false), (.place, "Toulouse", false)),
        s("fh-fr-depuis", "fr", "Depuis 2017, je suis comptable à Rennes.", (.title, "comptable", true), (.place, "Rennes", true)),
        s("fh-fr-jamais", "fr", "Je n'ai jamais travaillé avec Photoshop.", (.skill, "Photoshop", false)),
        // Portuguese
        s("fh-pt-gosto", "pt", "Gosto de fotografia e adoro ciclismo.", (.interest, "fotografia", true), (.interest, "ciclismo", true)),
        s("fh-pt-gostaria", "pt", "Gostaria de morar em Curitiba.", (.place, "Curitiba", false)),
        s("fh-pt-marido", "pt", "O meu marido é engenheiro em Braga.", (.title, "engenheiro", false), (.place, "Braga", false)),
        s("fh-pt-nao-falo-accentless", "pt", "Nao falo alemao.", (.language, "alemão", false)),
        s("fh-pt-quero", "pt", "Quero aprender Python no próximo ano.", (.skill, "Python", false)),
        s("fh-pt-ha", "pt", "Sou contadora em Fortaleza há cinco anos.", (.title, "contadora", true), (.place, "Fortaleza", true)),
        s("fh-pt-nao-gosto", "pt", "Não gosto de futebol, mas jogo xadrez.", (.interest, "futebol", false), (.interest, "xadrez", true)),
    ]

    // MARK: - Long drafts

    /// Drafts of 22, 32 and 42 personal items, as a long CV has: a list of skills, three languages, three interests, a title and a
    /// place the writer claims, and the items of someone else, a wish, a denial and a condition that the check must withdraw.
    static let longDrafts: [Sentence] = [22, 32, 42].map(longDraft(items:))

    private static let skillPool = [
        "Python", "SQL", "Docker", "Kubernetes", "Swift", "Kotlin", "Excel", "Figma", "Photoshop", "Terraform", "Ansible", "Jenkins",
        "Git", "Linux", "Bash", "Rust", "Scala", "Haskell", "Elixir", "Ruby", "TypeScript", "React", "Django", "Flask", "Redis",
        "Kafka", "Grafana", "Prometheus",
    ]

    private static func longDraft(items count: Int) -> Sentence {
        let claimedSkills = Array(skillPool.prefix(count - 14))
        let description = """
            I'm a nurse in Turin.
            Skills: \(claimedSkills.joined(separator: ", ")).
            I speak English, German and Italian.
            In my free time I like chess, hiking and cooking.
            I'd like to learn Korean.
            My sister speaks Japanese.
            I have never used COBOL.
            My colleague uses Fortran and Perl every day.
            If I had time, I would play golf.
            """
        return s("long-\(count)", "en", description,
                 (.title, "nurse", true), (.place, "Turin", true),
                 (.language, "English", true), (.language, "German", true), (.language, "Italian", true),
                 (.interest, "chess", true), (.interest, "hiking", true), (.interest, "cooking", true),
                 (.language, "Korean", false), (.language, "Japanese", false), (.skill, "COBOL", false),
                 (.skill, "Fortran", false), (.skill, "Perl", false), (.interest, "golf", false))
            .adding(claimedSkills.map { ClaimCandidate(kind: .skill, value: $0) })
    }
}

private extension AdversarialSet.Sentence {
    /// The same sentence with more items the writer claims.
    func adding(_ claimed: [ClaimCandidate]) -> AdversarialSet.Sentence {
        AdversarialSet.Sentence(id: id, language: language, description: description, items: items + claimed.map { ($0, true) })
    }
}
