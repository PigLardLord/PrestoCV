/// What a CV keeps of the way its values were made, beside the values themselves (ADR 0036, #196, #522): which values
/// the import wrote, and the text it could not place. It is saved with the CV and never printed, and it is not content:
/// a CV with a draft and nothing else has nothing to save (`SaveRule`).
///
/// The marks point at values by place, and entries have no identity, so the CV moves them when its entries change
/// (`CV.setSections`, `CV.setPersonalDetails`): a mark follows its row, a value edited by the person loses its mark,
/// and a mark whose row cannot be told apart is dropped, never left on another row. A block with nothing left is no
/// draft at all.
public struct DraftBlock: Hashable, Sendable {
    /// The origin of each marked value. A value with no mark was written by the person.
    public let origins: [ValuePlace: ValueOrigin]
    /// The texts the import could not place, in the order it found them.
    public let notPlaced: [NotPlacedText]

    public init(origins: [ValuePlace: ValueOrigin], notPlaced: [NotPlacedText]) {
        self.origins = origins; self.notPlaced = notPlaced
    }

    var isEmpty: Bool { origins.isEmpty && notPlaced.isEmpty }

    /// The block with nothing left as none.
    private func orNone(_ origins: [ValuePlace: ValueOrigin]) -> DraftBlock? {
        let block = DraftBlock(origins: origins, notPlaced: notPlaced)
        return block.isEmpty ? nil : block
    }

    // MARK: Edits of the person

    /// The marks left after the personal details change from `old` to `new`: a detail with another value loses its mark.
    func keeping(_ old: PersonalDetails, changedTo new: PersonalDetails) -> DraftBlock? {
        orNone(origins.filter { place, _ in
            switch place {
            case .personal(let field): field.value(of: old) == field.value(of: new)
            case .entry: true
            }
        })
    }

    /// The marks moved with their rows when the sections change from `old` to `new`, section by section:
    /// - a section whose rows are all the same keeps its marks;
    /// - a row found among the old rows keeps the marks that every old row equal to it had, unless the edit made
    ///   more rows of that value than there were (a copy: the copies cannot be told from the original);
    /// - a row with a new value takes the place of the old row at its position only when the number of rows is the
    ///   same and that old row's value lost a row (an edit in place); it keeps the marks of the values it did not change;
    /// - every other mark is dropped.
    func anchored(from old: CVSections, to new: CVSections) -> DraftBlock? {
        var moved: [ValuePlace: ValueOrigin] = [:]
        for (place, origin) in origins {
            switch place {
            case .personal: moved[place] = origin
            case .entry: continue
            }
        }
        for section in CVSection.allCases {
            let before = section.rows(of: old), after = section.rows(of: new)
            let fields = EntryField.allCases.filter { $0.section == section }
            let oldMarks = { (field: EntryField, index: Int) in origins[.entry(field, index: index)] }
            guard before != after else {
                for field in fields { for index in before.indices { moved[.entry(field, index: index)] = oldMarks(field, index) } }
                continue
            }
            let oldRows = Dictionary(grouping: before.indices, by: { before[$0] })
            let newCounts = Dictionary(grouping: after.indices, by: { after[$0] }).mapValues(\.count)
            for (index, row) in after.enumerated() {
                for field in fields {
                    if let sources = oldRows[row] {
                        guard newCounts[row, default: 0] <= sources.count else { continue }
                        let found = sources.map { oldMarks(field, $0) }
                        guard let first = found.first, let origin = first, found.allSatisfy({ $0 == origin }) else { continue }
                        moved[.entry(field, index: index)] = origin
                    } else if after.count == before.count, newCounts[before[index], default: 0] < oldRows[before[index], default: []].count,
                              field.value(in: old, at: index) == field.value(in: new, at: index) {
                        moved[.entry(field, index: index)] = oldMarks(field, index)
                    }
                }
            }
        }
        return orNone(moved)
    }
}

/// Where a value came from, for a value that the person did not write.
public enum ValueOrigin: Hashable, Sendable {
    /// Read from a CV the person imported, and not changed since.
    case imported
}

/// The place of one value of a CV. An entry's position counts from zero, as the arrays of `CVSections` do.
public enum ValuePlace: Hashable, Sendable {
    case personal(PersonalField)
    case entry(EntryField, index: Int)

    /// Whether the place names a value the sections have.
    func isInside(_ sections: CVSections) -> Bool {
        switch self {
        case .personal: true
        case .entry(let field, let index): field.section.rows(of: sections).indices.contains(index)
        }
    }
}

/// A detail of the person that can carry a mark.
public enum PersonalField: Hashable, Sendable, CaseIterable {
    case fullName, professionalTitle, email, phone, location, website, summary

    func value(of details: PersonalDetails) -> AnyHashable {
        switch self {
        case .fullName: details.fullName
        case .professionalTitle: details.professionalTitle
        case .email: details.email
        case .phone: details.phone
        case .location: details.location
        case .website: details.website
        case .summary: details.summary
        }
    }
}

/// A value of an entry that can carry a mark: the values the import writes (R14).
public enum EntryField: Hashable, Sendable, CaseIterable {
    case experienceRole, experienceCompany, experienceLocation, experiencePeriod, experienceDescription
    case educationDegree, educationSchool, educationPeriod, educationDescription
    case skillName
    case languageName, languageProficiency
    case certificationName, certificationIssuer, certificationIssued
    case profilePlatform, profileLink
    case interest

    /// The section the value belongs to.
    var section: CVSection {
        switch self {
        case .experienceRole, .experienceCompany, .experienceLocation, .experiencePeriod, .experienceDescription: .experiences
        case .educationDegree, .educationSchool, .educationPeriod, .educationDescription: .education
        case .skillName: .skills
        case .languageName, .languageProficiency: .languages
        case .certificationName, .certificationIssuer, .certificationIssued: .certifications
        case .profilePlatform, .profileLink: .profiles
        case .interest: .interests
        }
    }

    /// The value at `index` of `sections`, which must have that entry.
    func value(in sections: CVSections, at index: Int) -> AnyHashable {
        switch self {
        case .experienceRole: sections.experiences[index].role
        case .experienceCompany: sections.experiences[index].company
        case .experienceLocation: sections.experiences[index].location
        case .experiencePeriod: sections.experiences[index].period
        case .experienceDescription: sections.experiences[index].description
        case .educationDegree: sections.education[index].degree
        case .educationSchool: sections.education[index].school
        case .educationPeriod: sections.education[index].period
        case .educationDescription: sections.education[index].description
        case .skillName: sections.skills[index].name
        case .languageName: sections.languages[index].language
        case .languageProficiency: sections.languages[index].proficiency
        case .certificationName: sections.certifications[index].name
        case .certificationIssuer: sections.certifications[index].issuer
        case .certificationIssued: sections.certifications[index].issued
        case .profilePlatform: sections.profiles[index].platform
        case .profileLink: sections.profiles[index].link
        case .interest: sections.interests[index]
        }
    }
}

extension CVSection {
    /// The entries of this section, as values that compare.
    func rows(of sections: CVSections) -> [AnyHashable] {
        switch self {
        case .experiences: sections.experiences.map(AnyHashable.init)
        case .education: sections.education.map(AnyHashable.init)
        case .skills: sections.skills.map(AnyHashable.init)
        case .languages: sections.languages.map(AnyHashable.init)
        case .certifications: sections.certifications.map(AnyHashable.init)
        case .profiles: sections.profiles.map(AnyHashable.init)
        case .interests: sections.interests.map(AnyHashable.init)
        }
    }
}

/// A text the import could not place, with the heading it stood under in the imported CV, if any. The text follows the
/// text rule of a multi-line field, the heading that of a single-line one (`TextRules`); nothing is trimmed.
public struct NotPlacedText: Hashable, Sendable {
    public let text: String
    public let heading: String?

    /// Nil for a text of white space only, which is nothing to keep. A heading of white space only is no heading.
    public init?(text: String, heading: String?) {
        let text = TextRules.multiLine(text)
        guard !text.allSatisfy(\.isWhitespace) else { return nil }
        self.text = text
        self.heading = heading.map(TextRules.singleLine).flatMap { $0.allSatisfy(\.isWhitespace) ? nil : $0 }
    }
}

/// Why a draft block was refused.
public enum DraftError: Error, Equatable, Sendable {
    /// A mark names an entry the CV does not have.
    case placeOutsideSections
}
