import Foundation
import PrestoCVCore
import PrestoCVImporting
import enum PrestoCVDomain.LanguageProficiency

/// A CV read from the person's text, not stored yet, and what the editor shows about it.
struct ImportedDraft: Equatable, Sendable {
    let cv: CVModel
    let review: ImportReview
}

/// Turns what the import read into a CV the editor can open, and its review (ADR 0027).
///
/// Pure: the same import always gives the same CV, apart from fresh ids. It lives in the app because the legacy
/// `CVModel` is the app's, as the AI draft's mapper does (ADR 0007). Every value it writes is a value of the import,
/// which is the person's own text; it adds only the list marks that join an entry's lines.
struct ImportedCVMapper {

    func map(_ result: ImportResult) -> ImportedDraft {
        let imported = result.cv
        let person = imported.person
        var notImported = result.unplaced.map(\.text)
        var items: [ImportReview.Item] = reviewItems(of: result)

        var languages: [Language] = []
        for language in imported.languages {
            if let level = language.level {
                languages.append(Language(name: language.name.value, level: level.value.legacyLevel))
            } else {
                // The CV needs a level, and none the text states: the language stays visible, not invented
                let text = [language.name.value, language.levelWords?.value].compactMap { $0 }.joined(separator: " — ")
                let reason: ImportReview.Item.Reason = language.levelWords?.check == .levelsDiffer ? .languageLevels : .languageNotAdded
                items.append(ImportReview.Item(field: .language, reason: reason, text: text))
                notImported.append(text)
            }
        }

        // The CV has one website and no place for a study: the rest stays visible, never dropped
        notImported += person.links.filter { $0.kind == .website }.dropFirst().map(\.address.value.value)
        for (index, entry) in imported.education.enumerated() {
            guard let place = entry.location?.value else { continue }
            items.append(ImportReview.Item(field: .education(index + 1), reason: .placeNotKept, text: place))
            notImported.append(place)
        }

        let cv = CVModel(
            personalInfo: PersonalInfo(
                name: person.name?.value ?? "",
                title: person.title?.value ?? "",
                location: person.location?.value ?? "",
                email: person.email?.value.value ?? "",
                phone: person.phone?.value.value ?? "",
                portfolio: person.links.first { $0.kind == .website }?.address.value.value ?? "",
                profile: person.summary?.value ?? ""
            ),
            relevant_experience: imported.experience.map { entry in
                Experience(
                    title: entry.role?.value ?? "", company: entry.employer?.value ?? "", location: entry.location?.value ?? "",
                    period: periodText(entry.period, in: result), description: description(entry.details)
                )
            },
            education: imported.education.map { entry in
                Education(
                    degree: entry.degree?.value ?? "", school: entry.school?.value ?? "", period: periodText(entry.period, in: result),
                    description: description(entry.details)
                )
            },
            skills: imported.skills.map { Skill(name: $0.value) },
            languages: languages,
            certifications: imported.certifications.map { certification in
                Certification(name: certification.name.value, issuer: certification.issuer?.value ?? "", year: certification.year?.value ?? 0)
            },
            interests: imported.interests.map(\.value),
            social: person.links.compactMap(social),
            documentLanguage: result.language?.rawValue
        )
        return ImportedDraft(cv: cv, review: ImportReview(items: items, notImported: notImported.joined(separator: "\n")))
    }

    // MARK: Review

    private func reviewItems(of result: ImportResult) -> [ImportReview.Item] {
        result.reviewList.compactMap { item in
            let field: ImportReview.Item.Field
            switch item.field {
            case .name: field = .name
            case .title: field = .title
            case .location: field = .location
            case .summary: field = .summary
            case .experience(let index), .experiencePeriod(let index): field = .experience(index + 1)
            case .education(let index), .educationPeriod(let index): field = .education(index + 1)
            case .language: return nil   // a language without a level is listed once, where it is left out
            }
            let reason: ImportReview.Item.Reason
            switch item.reason {
            case .nameByPosition, .titleByPosition, .locationByPosition, .summaryWithoutHeading: reason = .byPosition
            case .roleOrEmployerByOrder: reason = .partsByOrder
            case .entryBoundsUnsure: reason = .entryBounds
            case .periodUnreadable, .periodOpenEnd: reason = .period
            case .levelNotCEFR: reason = .languageNotAdded
            case .levelsDiffer: reason = .languageLevels
            }
            return ImportReview.Item(field: field, reason: reason, text: item.text)
        }
    }

    // MARK: Values

    /// The period as the text writes it: "03/2019 – heute" stays in the CV's own words.
    private func periodText(_ period: Sourced<ImportedPeriod>?, in result: ImportResult) -> String {
        guard let period else { return "" }
        return result.document.text(of: period.spans, joinedBy: " ")
    }

    /// An entry's lines, one per line; several are listed with bullets, as the AI draft's are.
    private func description(_ details: [Sourced<String>]) -> String {
        guard details.count > 1 else { return details.first?.value ?? "" }
        return details.map { "• " + $0.value }.joined(separator: "\n")
    }

    private func social(_ link: ImportedLink) -> Social? {
        switch link.kind {
        case .linkedIn: return Social(platform: "LinkedIn", url: link.address.value.value)
        case .gitHub: return Social(platform: "GitHub", url: link.address.value.value)
        case .xing: return Social(platform: "XING", url: link.address.value.value)
        case .website: return nil
        }
    }
}

private extension LanguageProficiency {
    var legacyLevel: LanguageProficiencyLevel {
        switch self {
        case .a1: return .a1
        case .a2: return .a2
        case .b1: return .b1
        case .b2: return .b2
        case .c1: return .c1
        case .c2: return .c2
        case .native: return .native
        }
    }
}
