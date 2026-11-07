import Foundation
import PrestoCVDomain
import PrestoCVImporting
import PrestoCVWorkflowPorts

/// Turns what the import read into a new CV and what the person should check (ADR 0027).
///
/// Pure and deterministic: the same import gives the same CV, apart from the id it is given (R2). Every value it writes
/// is a value of the import, which is the person's own text; it adds only the list marks that join an entry's lines.
/// What the CV cannot hold is never guessed and never dropped: it is reported for review, and its text goes to the text
/// not imported. Dates become a typed period only where the text states a range that `Period.make` accepts.
public struct ImportedCVMapper: Sendable {
    public init() {}

    public func map(_ result: ImportResult, id: CVID) -> ImportOutcome {
        // The mapper reports the periods itself, with the dates as the text wrote them
        var notes = Notes(document: result.document, items: result.reviewList.filter { !$0.isAboutAPeriod }.map(ReviewItemMapping.item))
        let imported = result.cv
        let person = imported.person

        var sections = CVSections()
        // An entry with nothing left is not added (its text stays in the text not imported), and review fields count only
        // the entries the CV holds: an entry takes its place in the CV, and the items of one left out are withdrawn.
        for (index, entry) in imported.experience.enumerated() {
            let place = sections.experiences.count + 1
            let experience = Experience(role: entry.role?.value ?? "", company: entry.employer?.value ?? "", location: entry.location?.value ?? "",
                                        period: period(entry.period, field: .experiencePeriod(place), notes: &notes), description: description(entry.details))
            let kept = !experience.hasNoContent
            if kept { sections.experiences.append(experience) }
            notes.settle(from: [.experience(index + 1)], to: kept ? [.experience(place)] : [], withdrawing: [.experiencePeriod(place)], kept: kept)
        }
        for (index, entry) in imported.education.enumerated() {
            let place = sections.education.count + 1
            if let location = entry.location { notes.drop(.educationLocation(place), .locationNotKept, location.value) }
            let education = Education(degree: entry.degree?.value ?? "", school: entry.school?.value ?? "",
                                      period: period(entry.period, field: .educationPeriod(place), notes: &notes), description: description(entry.details))
            let kept = !education.hasNoContent
            if kept { sections.education.append(education) }
            notes.settle(from: [.education(index + 1)], to: kept ? [.education(place)] : [],
                         withdrawing: [.educationPeriod(place), .educationLocation(place)], kept: kept)
        }
        sections.skills = imported.skills.map { Skill(name: $0.value) }
        for (index, language) in imported.languages.enumerated() {
            if let level = language.level {
                sections.languages.append(LanguageSkill(language: language.name.value, proficiency: level.value))
            } else {
                // The CV needs a level, and the text states none: the language stays visible, never invented
                let text = [language.name.value, language.levelWords?.value].compactMap { $0 }.joined(separator: " — ")
                let reason: ImportReviewReason = switch language.levelWords?.check {
                case .levelsDiffer: .levelsDiffer
                case .levelNotCEFR: .levelNotCEFR
                case .none, .some: .levelMissing
                }
                notes.drop(.language(index + 1), reason, text)
            }
        }
        sections.certifications = imported.certifications.enumerated().map { index, certification in
            var issued: PartialDate?
            if let year = certification.year {
                issued = PartialDate(year: year.value)
                if issued == nil { notes.drop(.certificationYear(index + 1), .yearUnreadable, String(year.value)) }
            }
            return Certification(name: certification.name.value, issuer: certification.issuer?.value ?? "", issued: issued)
        }
        sections.setInterests(imported.interests.map(\.value))

        var website: WebLink?
        for link in person.links {
            switch link.kind {
            case .linkedIn: sections.profiles.append(ProfileLink(platform: "LinkedIn", link: link.address.value))
            case .gitHub: sections.profiles.append(ProfileLink(platform: "GitHub", link: link.address.value))
            case .xing: sections.profiles.append(ProfileLink(platform: "XING", link: link.address.value))
            case .website:
                if website == nil { website = link.address.value } else { notes.listed.append(link.address.value.value) }
            }
        }

        var cv = CV(id: id, language: result.language.flatMap { DocumentLanguage($0.rawValue) })
        cv.setPersonalDetails(PersonalDetails(
            fullName: person.name?.value ?? "", professionalTitle: person.title?.value ?? "", email: person.email?.value,
            phone: person.phone?.value, location: person.location?.value ?? "", website: website, summary: person.summary?.value ?? ""))
        cv.setSections(sections)
        return ImportOutcome(cv: cv, review: notes.items, notImported: (result.unplaced.map(\.text) + notes.listed).joined(separator: "\n"))
    }

    // MARK: Values

    /// The typed period of a range the text states, or none, with the reason: a single date, an end before the start or a
    /// date out of the years the CV holds, or a start with no end ("2019 -"): that is no unambiguous range, and it is never
    /// "present". Each of these is one review item for the field, and the person's words stay in the text not imported.
    private func period(_ period: Sourced<ImportedPeriod>?, field: ImportReviewField, notes: inout Notes) -> Period? {
        guard let period else { return nil }
        if let check = period.check { notes.drop(field, ReviewItemMapping.reason(check), notes.words(of: period), listed: false) }
        let start = (year: period.value.start.year, month: period.value.start.month)
        do {
            switch period.value.end {
            case nil:
                notes.drop(field, .periodNotARange, notes.words(of: period))
                return nil
            case .date(let end)?: return try Period.make(start: start, end: (year: end.year, month: end.month), current: false)
            case .current?: return try Period.make(start: start, end: nil, current: true)
            case .unstated?:
                notes.drop(field, .periodOpenEnd, notes.words(of: period))
                return nil
            }
        } catch {
            notes.drop(field, .periodUnreadable, notes.words(of: period))
            return nil
        }
    }

    /// An entry's lines, one per line; several are listed with bullets.
    private func description(_ details: [Sourced<String>]) -> String {
        guard details.count > 1 else { return details.first?.value ?? "" }
        return details.map { "• " + $0.value }.joined(separator: "\n")
    }

    // MARK: Review

    /// The review so far and the values the CV cannot hold, as the person's text.
    private struct Notes {
        let document: SourceDocument
        var items: [ImportReviewItem]
        var listed: [String] = []

        init(document: SourceDocument, items: [ImportReviewItem]) {
            self.document = document; self.items = items
        }

        func words(of period: Sourced<ImportedPeriod>) -> String { document.text(of: period.spans, joinedBy: " ") }

        /// Ends an entry: its imported review items move to the entry's place in the CV, or, when the entry is left out,
        /// they and the items of its dropped values are withdrawn. The text of what was dropped stays in `listed`.
        mutating func settle(from imported: [ImportReviewField], to place: [ImportReviewField], withdrawing dropped: [ImportReviewField], kept: Bool) {
            items = items.compactMap { item in
                if let at = imported.firstIndex(of: item.field) {
                    return place.indices.contains(at) ? ImportReviewItem(field: place[at], reason: item.reason, text: item.text) : nil
                }
                return !kept && dropped.contains(item.field) ? nil : item
            }
        }

        /// A value left out of the CV: reported once for its field and reason, and kept in the text not imported.
        mutating func drop(_ field: ImportReviewField, _ reason: ImportReviewReason, _ text: String, listed isListed: Bool = true) {
            if let known = items.firstIndex(where: { $0.field == field && $0.reason == reason }) {
                items[known] = ImportReviewItem(field: field, reason: reason, text: items[known].text)
            } else {
                items.append(ImportReviewItem(field: field, reason: reason, text: text))
            }
            if isListed { listed.append(text) }
        }
    }
}

/// The entry reads nothing: no value of it is left. The domain has no such predicate; it is the adapter's own check of
/// what it has just built from an import, kept to the fields the mapper fills.
private extension Experience {
    var hasNoContent: Bool { [role, company, location, description].allSatisfy(\.isEmpty) && period == nil }
}

private extension Education {
    var hasNoContent: Bool { [degree, school, description].allSatisfy(\.isEmpty) && period == nil }
}

private extension ReviewItem {
    var isAboutAPeriod: Bool {
        switch field {
        case .experiencePeriod, .educationPeriod: true
        case .name, .title, .location, .summary, .experience, .education, .language: false
        }
    }
}
