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
        return hasPostalCode(text) || hasRegionTail(text)
    }

    /// Whether a piece reads as a place and as nothing else: a postal code, a city with its region, a mode of work, or only
    /// words of known places ("Berlin Germany", "New York"). A name with a word that is also a city, "Thomas Kiel" or
    /// "Jack London", is not: the word before it is no place.
    static func isPlaceOnly(_ text: String) -> Bool {
        if hasPostalCode(text) || hasRegionTail(text) { return true }
        let words = text.words.map { $0.folded }
        guard !words.isEmpty else { return false }
        if workModePhrases.contains(where: { contains($0, in: words) }) { return true }
        var index = 0
        while index < words.count {
            let length = (1...3).reversed().first { count in
                index + count <= words.count && known.contains(words[index..<(index + count)].joined(separator: " "))
            }
            guard let length else { return false }
            index += length
        }
        return true
    }

    private static func contains(_ phrase: [String], in words: [String]) -> Bool {
        guard !phrase.isEmpty, phrase.count <= words.count else { return false }
        return (0...(words.count - phrase.count)).contains { words[$0..<($0 + phrase.count)].elementsEqual(phrase) }
    }

    /// Whether a piece names an area by its form, not by its name: "West Yorkshire", "Orange County", "Provincia di Torino".
    static func isArea(_ text: String) -> Bool {
        let words = text.words.map { $0.folded }
        guard let last = words.last else { return false }
        return (last.hasSuffix("shire") && last.count > 5) || words.contains { areaWords.contains($0) }
    }

    private static let areaWords: Set<String> = [
        "county", "province", "provincia", "provinz", "region", "regione", "district", "distrito", "canton", "kanton",
        "department", "departement", "prefecture", "oblast", "kreis", "landkreis", "contea", "condado", "comte", "comarca",
    ]

    /// Whether a piece names a country or a region, as the last part of "Leeds, United Kingdom" or "Akron, OH" does.
    static func isCountryOrRegion(_ text: String) -> Bool {
        let words = text.words
        if words.count == 1, let code = words.first, regionCodes.contains(String(code)) { return true }
        return regions.contains(words.map { $0.folded }.joined(separator: " "))
    }

    /// A city of one to three words, then a state, a province or a country: "Akron, OH", "Austin, Texas", "Calgary, Alberta".
    /// The states are no places by themselves: "Virginia Woolf" and "Denzel Washington" are names.
    private static func hasRegionTail(_ text: String) -> Bool {
        guard !text.contains(where: \.isNumber) else { return false }
        let cuts = (text.ranges(of: ", ") + text.ranges(of: " - ")).sorted { $0.lowerBound < $1.lowerBound }
        guard let cut = cuts.last else { return false }
        let city = text[text.startIndex..<cut.lowerBound].trimmingSpaces()
        let region = text[cut.upperBound...].trimmingSpaces()
        let cityWords = city.split(separator: " ")
        guard (1...3).contains(cityWords.count), cityWords.allSatisfy({ $0.first?.isUppercase == true }),
              city.allSatisfy({ $0.isLetter || " -'’.".contains($0) }) else { return false }
        return isCountryOrRegion(String(region))
    }

    private static let regions: Set<String> = Set((countries + others + stateNames + provinces + nations + laender).map { $0.words.map { $0.folded }.joined(separator: " ") })

    /// The codes of the states of the United States, the provinces of Canada and a few states of Brazil, as in "Boston, MA".
    /// A code is read only in capitals: "ma" and "or" are words.
    private static let regionCodes: Set<String> = [
        "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA", "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD", "MA",
        "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ", "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC", "SD", "TN",
        "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY", "DC",
        "ON", "QC", "BC", "AB", "MB", "SK", "NS", "NB", "NL", "PE", "NT", "NU", "YT",
        "SP", "RJ", "MG", "RS", "PR", "DF", "GO",
    ]

    private static let stateNames = [
        "alabama", "alaska", "arizona", "arkansas", "california", "colorado", "connecticut", "delaware", "florida", "georgia", "hawaii",
        "idaho", "illinois", "indiana", "iowa", "kansas", "kentucky", "louisiana", "maine", "maryland", "massachusetts", "michigan",
        "minnesota", "mississippi", "missouri", "montana", "nebraska", "nevada", "new hampshire", "new jersey", "new mexico", "new york",
        "north carolina", "north dakota", "ohio", "oklahoma", "oregon", "pennsylvania", "rhode island", "south carolina", "south dakota",
        "tennessee", "texas", "utah", "vermont", "virginia", "washington", "west virginia", "wisconsin", "wyoming", "district of columbia",
    ]

    private static let provinces = [
        "ontario", "quebec", "québec", "british columbia", "alberta", "manitoba", "saskatchewan", "nova scotia", "new brunswick",
        "newfoundland and labrador", "prince edward island",
    ]

    private static let nations = ["england", "scotland", "wales", "northern ireland", "inghilterra", "scozia", "galles", "angleterre", "écosse"]

    private static let laender = [
        "baden-württemberg", "brandenburg", "hessen", "mecklenburg-vorpommern", "niedersachsen", "nordrhein-westfalen",
        "rheinland-pfalz", "saarland", "sachsen-anhalt", "schleswig-holstein", "thüringen", "hesse", "lower saxony",
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

    // MARK: Street addresses

    /// A street and number, or a postal code: "Musterstraße 5", "123 Main Street", "Via Roma 1", "04109 Leipzig".
    static func isAddress(_ text: String) -> Bool {
        if hasPostalCode(text) { return true }
        guard text.contains(where: \.isNumber) else { return false }
        return text.words.map { $0.folded }.contains { word in
            streetWords.contains(word) || streetSuffixes.contains { word.hasSuffix($0) && word.count > $0.count }
        }
    }

    private static let streetSuffixes = ["strasse", "str", "weg", "platz", "allee", "gasse"]

    private static let streetWords: Set<String> = Set(["via", "viale", "piazza", "corso", "largo", "str", "strasse", "weg", "platz", "allee",
        "calle", "avenida", "av", "plaza", "paseo", "rua", "avenue", "ave", "rue", "boulevard", "blvd", "bd", "street", "st", "road", "rd",
        "lane", "travessa"].map(\.folded))

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
        "los angeles", "seattle", "philadelphia", "pittsburgh", "minneapolis", "atlanta", "miami", "akron", "san diego", "san jose",
        "las vegas", "vancouver", "ottawa", "calgary", "reims", "bielefeld", "duisburg", "wuppertal", "augsburg", "kiel",
        "lübeck", "rostock", "erfurt", "mainz", "wiesbaden", "kassel", "münster", "aachen", "toulon", "dijon",
        "orléans", "amiens", "limoges", "perpignan", "saint-étienne", "le havre",
    ]

    private static let others = workModes + areas

    private static let workModes = [
        "remote", "da remoto", "in remoto", "smart working", "remoto", "homeoffice", "home office", "télétravail", "à distance",
        "hybrid", "ibrido", "híbrido", "hybride",
    ]

    private static let workModePhrases: [[String]] = workModes.map { $0.words.map { $0.folded } }

    private static let areas = [
        "metropolitan area",
        "lombardia", "lombardy", "piemonte", "piedmont", "lazio", "veneto", "toscana", "tuscany", "emilia-romagna", "sachsen", "saxony",
        "bayern", "bavaria", "baviera", "berlin-brandenburg", "île-de-france", "catalunya", "cataluña", "catalonia", "andalucía",
        "comunidad de madrid", "lisbon area", "grande lisboa", "área metropolitana de lisboa",
    ]
}
