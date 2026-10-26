import Foundation

/// An entry of a draft (a job, a study, a certification) as the description's clauses see it: what names it, and which words of
/// its own the entry explains.
struct Subject {
    /// The quotes a clause must all name to back the entry: its employer, school or certification, or its title or degree when
    /// it has no employer or school, or when another entry has the same one.
    let names: [[String]]
    /// The quotes that a clause names the entry by, to mention it as a fact: its employer, school or certification, or its title or
    /// degree when it has none. The title of a job that shares its employer is not among them: the employer alone names it.
    let mentions: [[String]]
    /// The quotes of the entry whose words explain themselves in a clause that backs it: its title, employer, school, place.
    let quotes: [[String]]
    /// The achievements of a job, each as the words it is made of.
    let achievements: [[String]]
    /// The name of the employer or the school of the entry, when it has one: a statement about the entry names it, and says
    /// nothing else with its words (ADR 0023, rule (b)).
    let holder: [String]?
    /// Whether the entry is found by its title alone: it is, only if the description names the title once.
    let isFoundByItsTitle: Bool
    /// Whether the entry is a study: a graduation phrase next to its clause joins it, and gives its end date.
    let isEducation: Bool

    init(
        names: [[String]], mentions: [[String]]? = nil, quotes: [[String]], achievements: [[String]] = [], holder: [String]? = nil,
        isFoundByItsTitle: Bool = false, isEducation: Bool = false
    ) {
        self.names = names
        self.mentions = mentions ?? names
        self.quotes = quotes
        self.achievements = achievements
        self.holder = holder
        self.isFoundByItsTitle = isFoundByItsTitle
        self.isEducation = isEducation
    }
}
