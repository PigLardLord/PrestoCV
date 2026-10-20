/// Places the rules know: countries in the six languages and large cities. A place a CV states without a label is
/// still read without them; knowing it only spares the person a check.
enum Places {

    /// Whether a piece of text names a known place, has a postal code, or reads "Remote".
    static func isKnownPlace(_ text: String) -> Bool {
        let words = text.words.map { $0.folded }
        if words.contains(where: { known.contains($0) }) { return true }
        for count in 2...3 where words.count >= count {
            for start in 0...(words.count - count) where known.contains(words[start..<(start + count)].joined(separator: " ")) {
                return true
            }
        }
        return hasPostalCode(text)
    }

    /// Whether a piece names a country or a region, as the last part of "Leeds, United Kingdom" does.
    static func isCountryOrRegion(_ text: String) -> Bool {
        let key = text.words.map { $0.folded }.joined(separator: " ")
        return regions.contains(key)
    }

    private static let regions: Set<String> = Set((countries + others + states).map { $0.words.map { $0.folded }.joined(separator: " ") })

    /// The codes of the states of the United States, as in "Boston, MA".
    private static let states = [
        "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA", "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD", "MA",
        "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ", "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC", "SD", "TN",
        "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY", "DC",
    ]

    /// A postal code: four or five digits next to a word, as in "04109 Leipzig", "10121 Torino", "1000-001 Lisboa".
    static func hasPostalCode(_ text: String) -> Bool {
        let words = text.split(whereSeparator: { $0 == " " || $0 == "," })
        for (index, word) in words.enumerated() {
            let digits = word.filter(\.isNumber)
            let isCode = (4...5).contains(digits.count) && word.allSatisfy { $0.isNumber || $0 == "-" } || (word.count == 8 && word.contains("-") && digits.count == 7)
            guard isCode else { continue }
            let neighbours = [index > 0 ? words[index - 1] : nil, index + 1 < words.count ? words[index + 1] : nil].compactMap { $0 }
            if neighbours.contains(where: { $0.first?.isLetter == true }) { return true }
        }
        return false
    }

    private static let known: Set<String> = Set((countries + cities + others).map(\.folded))

    private static let countries = [
        "italy", "italia", "italien", "italie", "itália", "germany", "deutschland", "germania", "alemania", "allemagne", "alemanha",
        "spain", "spagna", "spanien", "españa", "espagne", "espanha", "france", "francia", "frankreich", "frança",
        "portugal", "portogallo", "switzerland", "schweiz", "svizzera", "suiza", "suisse", "suíça", "austria", "österreich",
        "autriche", "áustria", "belgium", "belgio", "belgien", "bélgica", "belgique", "netherlands", "paesi bassi", "niederlande",
        "países bajos", "pays-bas", "países baixos", "united kingdom", "uk", "regno unito", "vereinigtes königreich", "reino unido",
        "royaume-uni", "ireland", "irlanda", "irland", "irlande", "united states", "usa", "stati uniti", "brazil", "brasile",
        "brasilien", "brasil", "brésil", "luxembourg", "lussemburgo", "luxemburg", "luxemburgo", "poland", "polonia", "polen",
        "pologne", "polónia", "romania", "rumänien", "rumania", "roumanie", "roménia", "greece", "grecia", "griechenland", "grèce",
        "grécia", "sweden", "svezia", "schweden", "suecia", "suède", "suécia", "denmark", "danimarca", "dänemark", "dinamarca",
        "danemark", "norway", "norvegia", "norwegen", "noruega", "norvège", "angola", "mozambique", "moçambique", "mexico", "méxico",
        "argentina", "argentinien", "argentine", "chile", "colombia", "kolumbien", "colombie", "peru", "perú", "canada", "kanada",
        "canadá", "cape verde", "cabo verde",
    ]

    private static let cities = [
        "milano", "milan", "mailand", "torino", "turin", "roma", "rome", "rom", "napoli", "naples", "neapel", "bologna", "firenze",
        "florence", "florenz", "genova", "genoa", "venezia", "venice", "venedig", "verona", "padova", "padua", "palermo", "bari",
        "catania", "trieste", "brescia", "bergamo", "parma", "modena", "pisa", "trento", "bolzano", "perugia", "cagliari",
        "berlin", "berlino", "hamburg", "amburgo", "hamburgo", "münchen", "munich", "monaco di baviera", "múnich", "köln", "cologne",
        "colonia", "frankfurt", "francoforte", "stuttgart", "stoccarda", "düsseldorf", "leipzig", "lipsia", "dresden", "dresda",
        "hannover", "nürnberg", "nuremberg", "bremen", "dortmund", "bonn", "mannheim", "karlsruhe", "freiburg", "heidelberg",
        "madrid", "barcelona", "barcellona", "barcelone", "valencia", "valence", "sevilla", "seville", "siviglia", "séville",
        "zaragoza", "málaga", "bilbao", "murcia", "palma", "granada", "alicante", "valladolid", "vigo", "salamanca",
        "paris", "parigi", "parís", "lyon", "lione", "marseille", "marsiglia", "marsella", "toulouse", "tolosa", "nizza",
        "niza", "nantes", "strasbourg", "strasburgo", "bordeaux", "lille", "rennes", "montpellier", "grenoble",
        "lisboa", "lisbon", "lisbona", "lissabon", "lisbonne", "porto", "oporto", "braga", "coimbra", "faro", "aveiro", "setúbal",
        "funchal", "são paulo", "rio de janeiro", "london", "londra", "londres", "manchester", "edinburgh", "dublin", "zürich",
        "zurich", "zurigo", "genf", "geneva", "ginevra", "genève", "basel", "bern", "lausanne", "lugano", "wien", "vienna", "viena",
        "vienne", "graz", "salzburg", "innsbruck", "linz", "brussels", "bruxelles", "brüssel", "bruselas", "bruxelas", "amsterdam",
        "rotterdam", "new york", "san francisco", "boston", "chicago", "toronto", "montreal", "luxembourg",
    ]

    private static let others = [
        "remote", "da remoto", "in remoto", "smart working", "remoto", "homeoffice", "home office", "télétravail", "à distance",
        "hybrid", "ibrido", "híbrido", "hybride", "metropolitan area",
        "lombardia", "lombardy", "piemonte", "piedmont", "lazio", "veneto", "toscana", "tuscany", "emilia-romagna", "sachsen", "saxony",
        "bayern", "bavaria", "baviera", "berlin-brandenburg", "île-de-france", "catalunya", "cataluña", "catalonia", "andalucía",
        "comunidad de madrid", "lisbon area", "grande lisboa", "área metropolitana de lisboa",
    ]
}
