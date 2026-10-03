import TailoringModel

/// What the English file holds, written out from cv-giovanni at commit 6e28147 by a one-off script that reads the source:
/// every list of at most 50 entries. The stopwords, which are longer, are pinned by a digest in `EnglishWordListsTests`.
/// The long lists are built step by step: the type checker of Swift 6.4 is slow on a long literal.
enum EnglishExpected {
    /// cv-giovanni 6e28147 domain/AdvertLexicon.js ADVERT.plainWords.en
    static let advertPlainWords: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["new", "time", "set", "use"])
        values.append(contentsOf: ["get", "make", "keep", "drive"])
        values.append(contentsOf: ["after", "knowledge"])
        return values
    }()

    /// cv-giovanni 6e28147 domain/AdvertLexicon.js ADVERT.dimensions.en
    static let advertDimensions: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["performance", "stability", "quality", "speed"])
        values.append(contentsOf: ["efficiency"])
        return values
    }()

    /// cv-giovanni 6e28147 domain/AdvertLexicon.js ADVERT.boilerplate.en
    static let advertBoilerplate: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["equal opportunity", "equal opportunities", "regardless of", "we offer"])
        values.append(contentsOf: ["what we offer", "benefits", "perks", "apply now"])
        values.append(contentsOf: ["send your cv", "full time", "full-time", "part time"])
        values.append(contentsOf: ["part-time", "permanent", "permanent position", "permanent contract"])
        values.append(contentsOf: ["competitive salary", "about us", "join us", "our mission"])
        values.append(contentsOf: ["diverse", "inclusive", "diverse team", "inclusive team"])
        values.append(contentsOf: ["diverse and inclusive", "inclusive workplace", "flexible hours", "remote friendly"])
        return values
    }()

    /// cv-giovanni 6e28147 domain/AdvertLexicon.js ADVERT.genderMarkers.en
    static let advertGenderMarkers: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["all genders", "any gender"])
        return values
    }()

    /// cv-giovanni 6e28147 domain/AdvertLexicon.js ADVERT.instructions.en
    static let advertInstructions: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["please state", "please indicate", "please let us know", "earliest start date"])
        values.append(contentsOf: ["earliest possible start date", "salary expectation", "salary expectations", "notice period"])
        return values
    }()

    /// cv-giovanni 6e28147 domain/AdvertLexicon.js ADVERT.streets.en, STREET_ORDER.en
    static let advertStreets: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["street", "st.", "road", "rd."])
        values.append(contentsOf: ["avenue", "ave.", "lane", "boulevard"])
        values.append(contentsOf: ["blvd."])
        return values
    }()

    /// cv-giovanni 6e28147 domain/AdvertLexicon.js ADVERT.names.en
    static let advertNames: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["github actions", "gitlab ci", "azure devops", "jetpack compose"])
        values.append(contentsOf: ["kotlin multiplatform", "kotlin coroutines", "react native", "firebase crashlytics"])
        values.append(contentsOf: ["new relic", "core data", "app store", "app store connect"])
        values.append(contentsOf: ["play store", "google play", "android studio", "time series"])
        values.append(contentsOf: ["use case", "use cases", "ui tests", "feature flags"])
        values.append(contentsOf: ["clean architecture", "design system", "dependency injection", "push notifications"])
        values.append(contentsOf: ["deep links"])
        return values
    }()

    /// cv-giovanni 6e28147 domain/AdvertLexicon.js ADVERT.synonyms (the English forms of each group)
    static let advertSynonyms: [[String]] = {
        var values: [[String]] = []
        values.append(contentsOf: [["mdm", "mobile device management"], ["ci/cd", "continuous integration", "continuous delivery", "continuous deployment"]])
        values.append(contentsOf: [["ml", "machine learning"], ["ui", "user interface"]])
        values.append(contentsOf: [["ux", "user experience"], ["qa", "quality assurance"]])
        values.append(contentsOf: [["spm", "swift package manager"], ["tdd", "test driven development", "test-driven development"]])
        values.append(contentsOf: [["api", "apis"], ["ios", "apple platform", "apple platforms"]])
        values.append(contentsOf: [["developer", "developers", "engineer", "engineers"], ["test automation", "automated testing", "automated tests"]])
        values.append(contentsOf: [["accessibility", "a11y"], ["code review", "code reviews", "code-review", "code-reviews"]])
        values.append(contentsOf: [["unit tests", "unit testing", "unit-tests", "unittests"], ["mobile development", "mobile app development"]])
        return values
    }()

    /// cv-giovanni 6e28147 domain/AdvertLexicon.js ADVERT.requirementHeadings.en
    static let advertRequirementHeadings: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["requirements", "required", "must have", "essential"])
        values.append(contentsOf: ["qualifications", "you have", "what you bring", "who you are"])
        values.append(contentsOf: ["ideal experiences", "we are looking for"])
        return values
    }()

    /// cv-giovanni 6e28147 domain/AdvertLexicon.js ADVERT.offerHeadings.en
    static let advertOfferHeadings: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["we offer", "what we offer", "benefits", "perks"])
        values.append(contentsOf: ["about us", "why join", "our culture", "how we work"])
        return values
    }()

    /// cv-giovanni 6e28147 domain/AdvertLexicon.js ADVERT.structuralHeadings.en
    static let advertStructuralHeadings: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["role", "the role", "about the role", "focus"])
        values.append(contentsOf: ["responsibilities", "outcomes", "tech stack", "our stack"])
        values.append(contentsOf: ["how we work", "interview process", "the team", "location"])
        return values
    }()

    /// cv-giovanni 6e28147 domain/DateRange.js MONTHS.en
    static let datesMonths: [MonthName] = {
        var values: [MonthName] = []
        values.append(contentsOf: [MonthName(name: "january", month: 1), MonthName(name: "jan", month: 1)])
        values.append(contentsOf: [MonthName(name: "february", month: 2), MonthName(name: "feb", month: 2)])
        values.append(contentsOf: [MonthName(name: "march", month: 3), MonthName(name: "mar", month: 3)])
        values.append(contentsOf: [MonthName(name: "april", month: 4), MonthName(name: "apr", month: 4)])
        values.append(contentsOf: [MonthName(name: "may", month: 5), MonthName(name: "june", month: 6)])
        values.append(contentsOf: [MonthName(name: "jun", month: 6), MonthName(name: "july", month: 7)])
        values.append(contentsOf: [MonthName(name: "jul", month: 7), MonthName(name: "august", month: 8)])
        values.append(contentsOf: [MonthName(name: "aug", month: 8), MonthName(name: "september", month: 9)])
        values.append(contentsOf: [MonthName(name: "sept", month: 9), MonthName(name: "sep", month: 9)])
        values.append(contentsOf: [MonthName(name: "october", month: 10), MonthName(name: "oct", month: 10)])
        values.append(contentsOf: [MonthName(name: "november", month: 11), MonthName(name: "nov", month: 11)])
        values.append(contentsOf: [MonthName(name: "december", month: 12), MonthName(name: "dec", month: 12)])
        return values
    }()

    /// cv-giovanni 6e28147 domain/DateRange.js PRESENT (the English words)
    static let datesPresentWords: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["present", "now", "current", "ongoing"])
        return values
    }()

    /// cv-giovanni 6e28147 domain/DateRange.js SINCE (the English word)
    static let datesSinceWords: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["since"])
        return values
    }()

    /// cv-giovanni 6e28147 domain/DateRange.js SEPARATOR (the English word between two dates)
    static let datesRangeSeparatorWords: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["to"])
        return values
    }()

    /// cv-giovanni 6e28147 domain/DateRange.js DateRange.parse, the unit after a length (the English forms, expanded)
    static let datesDurationUnitWords: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["year", "years", "yr", "yrs"])
        values.append(contentsOf: ["month", "months", "mo", "mos"])
        return values
    }()

    /// cv-giovanni 6e28147 core/ProvenanceCheck.js NUMBERS
    static let numbersWords: [NumberWord] = {
        var values: [NumberWord] = []
        values.append(contentsOf: [NumberWord(word: "two", value: 2), NumberWord(word: "three", value: 3)])
        values.append(contentsOf: [NumberWord(word: "four", value: 4), NumberWord(word: "five", value: 5)])
        values.append(contentsOf: [NumberWord(word: "six", value: 6), NumberWord(word: "seven", value: 7)])
        values.append(contentsOf: [NumberWord(word: "eight", value: 8), NumberWord(word: "nine", value: 9)])
        values.append(contentsOf: [NumberWord(word: "ten", value: 10), NumberWord(word: "eleven", value: 11)])
        values.append(contentsOf: [NumberWord(word: "twelve", value: 12), NumberWord(word: "thirteen", value: 13)])
        values.append(contentsOf: [NumberWord(word: "fourteen", value: 14), NumberWord(word: "fifteen", value: 15)])
        values.append(contentsOf: [NumberWord(word: "sixteen", value: 16), NumberWord(word: "seventeen", value: 17)])
        values.append(contentsOf: [NumberWord(word: "eighteen", value: 18), NumberWord(word: "nineteen", value: 19)])
        values.append(contentsOf: [NumberWord(word: "twenty", value: 20), NumberWord(word: "thirty", value: 30)])
        values.append(contentsOf: [NumberWord(word: "forty", value: 40), NumberWord(word: "fifty", value: 50)])
        values.append(contentsOf: [NumberWord(word: "sixty", value: 60), NumberWord(word: "seventy", value: 70)])
        values.append(contentsOf: [NumberWord(word: "eighty", value: 80), NumberWord(word: "ninety", value: 90)])
        values.append(contentsOf: [NumberWord(word: "dozen", value: 12), NumberWord(word: "hundred", value: 100)])
        values.append(contentsOf: [NumberWord(word: "thousand", value: 1000), NumberWord(word: "million", value: 1000000)])
        return values
    }()

    /// cv-giovanni 6e28147 domain/StatedSpans.js FLOOR (the English lead-ins)
    static let spansFloorLeadIns: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["over", "more than", "at least"])
        return values
    }()

    /// cv-giovanni 6e28147 domain/StatedSpans.js UNIT (the English forms of year)
    static let spansYearWords: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["year", "years"])
        return values
    }()

    /// cv-giovanni 6e28147 domain/StatedSpans.js UNIT (the English forms of month)
    static let spansMonthWords: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["month", "months"])
        return values
    }()

    /// cv-giovanni 6e28147 domain/StatedSpans.js WORDS (the English words)
    static let spansCountWords: [NumberWord] = {
        var values: [NumberWord] = []
        values.append(contentsOf: [NumberWord(word: "one", value: 1), NumberWord(word: "two", value: 2)])
        values.append(contentsOf: [NumberWord(word: "three", value: 3), NumberWord(word: "four", value: 4)])
        values.append(contentsOf: [NumberWord(word: "five", value: 5), NumberWord(word: "six", value: 6)])
        values.append(contentsOf: [NumberWord(word: "seven", value: 7), NumberWord(word: "eight", value: 8)])
        values.append(contentsOf: [NumberWord(word: "nine", value: 9), NumberWord(word: "ten", value: 10)])
        values.append(contentsOf: [NumberWord(word: "eleven", value: 11), NumberWord(word: "twelve", value: 12)])
        return values
    }()

    /// cv-giovanni 6e28147 domain/StatedSpans.js TIED (the English construction, as templates)
    static let spansTiedCounts: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["{count} of them at {employer}", "{count} of which at {employer}", "{count} of those at {employer}"])
        return values
    }()

    /// cv-giovanni 6e28147 domain/StatedSpans.js EMPLOYER, the English word
    static let spansEmployerEndWords: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["and"])
        return values
    }()

    /// cv-giovanni 6e28147 core/ProvenanceCheck.js GREETING (the English words)
    static let letterGreetings: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["dear", "hello", "hi"])
        return values
    }()

    /// cv-giovanni 6e28147 core/ProvenanceCheck.js SALUTATION (the English salutation that stands alone)
    static let letterSalutations: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["to whom it may concern"])
        return values
    }()

    /// cv-giovanni 6e28147 core/ProvenanceCheck.js WHOM (the English words that follow a greeting)
    static let letterAddressees: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["ms", "mrs", "mr", "dr"])
        values.append(contentsOf: ["prof", "sir", "madam", "all"])
        values.append(contentsOf: ["everyone", "friends", "recruiter", "recruiters"])
        values.append(contentsOf: ["colleagues"])
        return values
    }()

    /// cv-giovanni 6e28147 core/ProvenanceCheck.js WHOM (the English word read only before a comma, a bang or the end)
    static let letterAddresseesAtClauseEnd: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["there"])
        return values
    }()

    /// cv-giovanni 6e28147 core/ProvenanceCheck.js WHOM (the English nouns an addressee ends in)
    static let letterAddresseeNouns: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["team", "manager", "committee", "department"])
        return values
    }()

    /// cv-giovanni 6e28147 core/ProvenanceCheck.js CLOSING (the English forms, expanded)
    static let letterValedictions: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["kind regards", "best regards", "warm regards", "warmest regards"])
        values.append(contentsOf: ["with kind regards", "with best regards", "with warm regards", "with warmest regards"])
        values.append(contentsOf: ["best wishes", "yours sincerely", "yours faithfully", "yours truly"])
        values.append(contentsOf: ["sincerely", "sincerely yours"])
        return values
    }()

    /// cv-giovanni 6e28147 core/Tailor.js ASKS.salaryExpectation (the English phrases, expanded)
    static let letterSalaryExpectationAsks: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["salary expectation", "salary expectations", "salary requirement", "salary requirements"])
        values.append(contentsOf: ["expected salary", "desired salary"])
        return values
    }()

    /// cv-giovanni 6e28147 core/Tailor.js ASKS.startDate (the English phrases, expanded)
    static let letterStartDateAsks: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["earliest start date", "earliest starting date", "earliest possible start date", "earliest possible starting date"])
        values.append(contentsOf: ["earliest start", "earliest possible start", "earliest availability", "earliest possible availability"])
        values.append(contentsOf: ["start date", "starting date", "availability date", "notice period"])
        values.append(contentsOf: ["when you could start"])
        return values
    }()

    /// cv-giovanni 6e28147 core/Tailor.js ASKS (the English words after which an advert states its own term)
    static let letterStatedTermWords: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["is", "of", "range", "applies"])
        return values
    }()

    /// cv-giovanni 6e28147 core/ProvenanceCheck.js letterFailures, the words of recipient.form (the English words)
    static let letterFormsOfAddress: [FormOfAddressWord] = {
        var values: [FormOfAddressWord] = []
        values.append(contentsOf: [FormOfAddressWord(form: .ms, word: "ms"), FormOfAddressWord(form: .ms, word: "mrs")])
        values.append(contentsOf: [FormOfAddressWord(form: .mr, word: "mr")])
        return values
    }()

    /// cv-giovanni 6e28147 core/ProvenanceCheck.js letterFailures, the titles between a form of address and a name
    static let letterAcademicTitles: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["dr", "prof"])
        return values
    }()

    /// cv-giovanni 6e28147 core/ProvenanceCheck.js letterFailures, the words that are no given name (the English words)
    static let letterNotGivenNames: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["ms", "mrs", "miss", "mr"])
        values.append(contentsOf: ["and", "or"])
        return values
    }()

    /// cv-giovanni 6e28147 core/ProvenanceCheck.js RANKS (the English words)
    static let provenanceRanks: [RankWord] = {
        var values: [RankWord] = []
        values.append(contentsOf: [RankWord(word: "senior", ranks: [.senior]), RankWord(word: "lead", ranks: [.lead])])
        values.append(contentsOf: [RankWord(word: "leading", ranks: [.lead]), RankWord(word: "principal", ranks: [.principal])])
        values.append(contentsOf: [RankWord(word: "staff", ranks: [.staff]), RankWord(word: "head", ranks: [.head])])
        values.append(contentsOf: [RankWord(word: "chief", ranks: [.head]), RankWord(word: "director", ranks: [.director])])
        values.append(contentsOf: [RankWord(word: "manager", ranks: [.manager]), RankWord(word: "architect", ranks: [.architect])])
        return values
    }()

    /// cv-giovanni 6e28147 core/ProvenanceCheck.js NOT_PLURALS
    static let provenanceNotPlurals: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["news", "goods", "means", "series"])
        values.append(contentsOf: ["species", "lens", "gas", "bus"])
        values.append(contentsOf: ["sales"])
        return values
    }()

    /// cv-giovanni 6e28147 core/ProvenanceCheck.js LEGAL_FORM, the forms of its alternatives, with its optional spaces left to the check
    static let provenanceLegalForms: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["gmbh & co kg", "gmbh & co kga", "gmbh & co kgaa", "gmbh & co. kg"])
        values.append(contentsOf: ["gmbh & co. kga", "gmbh & co. kgaa", "ug (haftungsbeschränkt)", "gmbh"])
        values.append(contentsOf: ["ggmbh", "kgaa", "ag", "se"])
        values.append(contentsOf: ["kg", "ug", "e.v.", "s.a."])
        values.append(contentsOf: ["b.v.", "ltd", "ltd.", "limited"])
        values.append(contentsOf: ["inc", "inc.", "llc", "plc"])
        return values
    }()

    /// cv-giovanni 6e28147 core/ProvenanceCheck.js ProvenanceCheck.names (the first person, expanded)
    static let provenanceFirstPerson: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["I", "I'm", "I've", "I'd"])
        values.append(contentsOf: ["I'll", "I’m", "I’ve", "I’d"])
        values.append(contentsOf: ["I’ll"])
        return values
    }()

    /// cv-giovanni 6e28147 domain/TechnologyLexicon.js TECHNOLOGIES
    static let fieldsTechnologies: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["Kotlin", "Objective-C", "TypeScript", "JavaScript"])
        values.append(contentsOf: ["Node.js", "Python", "Scala", "Elixir"])
        values.append(contentsOf: ["SwiftUI", "UIKit", "AppKit", "Xcode"])
        values.append(contentsOf: ["XCTest", "XCUITest", "CoreML", "TestFlight"])
        values.append(contentsOf: ["CocoaPods", "Alamofire", "RxSwift", "RxJava"])
        values.append(contentsOf: ["Jetpack Compose", "Gradle", "React Native", "Xamarin"])
        values.append(contentsOf: ["fastlane", "Bitrise", "Jenkins", "CircleCI"])
        values.append(contentsOf: ["GitHub Actions", "GitLab CI", "Docker", "Kubernetes"])
        values.append(contentsOf: ["Terraform", "Firebase", "Crashlytics", "Sentry"])
        values.append(contentsOf: ["Datadog", "New Relic", "GraphQL", "gRPC"])
        values.append(contentsOf: ["Protobuf", "PostgreSQL", "MySQL", "MongoDB"])
        values.append(contentsOf: ["Redis", "Kafka", "Elasticsearch", "TensorFlow"])
        values.append(contentsOf: ["PyTorch"])
        return values
    }()
}
