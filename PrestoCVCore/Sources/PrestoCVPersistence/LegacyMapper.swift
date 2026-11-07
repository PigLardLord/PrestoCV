import Foundation
import PrestoCVDomain
import PrestoCVApplication

/// Maps what the legacy app wrote to the domain (ADR 0022). A value the domain refuses is dropped, not repaired, and the
/// drop is noted once per kind, so the report says what the person lost without quoting their content.
struct LegacyMapper {
    private(set) var drops: [LegacyDrop] = []

    private mutating func note(_ drop: LegacyDrop) { if !drops.contains(drop) { drops.append(drop) } }

    mutating func map(_ raw: LegacyCVFile.Raw, id: CVID, fallback: Date) -> CV {
        let times = Self.times(raw, fallback: fallback)
        return CV(id: id, revision: 0, createdAt: times.created, updatedAt: times.updated, title: raw.name ?? "",
                  personal: personal(raw.personalInfo), sections: sections(raw), design: design(raw.look?.value),
                  language: optional(raw.documentLanguage, .documentLanguage) { DocumentLanguage($0) })
    }

    // MARK: Times

    /// A file with neither time takes the fallback; with one, that one; an update is never dated before its creation.
    static func times(_ raw: LegacyCVFile.Raw, fallback: Date) -> (created: Date, updated: Date) {
        let created = raw.createdAt?.value ?? raw.updatedAt?.value ?? fallback
        let updated = raw.updatedAt?.value ?? created
        return (created, max(created, updated))
    }

    // MARK: Values

    /// Empty is nothing; anything else the domain does not accept is dropped and noted.
    private mutating func optional<T>(_ text: String?, _ drop: LegacyDrop, _ make: (String) -> T?) -> T? {
        let trimmed = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let value = make(trimmed) else { note(drop); return nil }
        return value
    }

    private mutating func personal(_ info: LegacyCVFile.Personal?) -> PersonalDetails {
        PersonalDetails(fullName: info?.name ?? "", professionalTitle: info?.title ?? "",
                        email: optional(info?.email, .email) { EmailAddress($0) },
                        phone: optional(info?.phone, .phone) { PhoneNumber($0) },
                        location: info?.location ?? "", website: optional(info?.portfolio, .website) { WebLink($0) },
                        summary: info?.profile ?? "")
    }

    /// A look needs a design the domain accepts; palette and fonts that it refuses are left out with it kept.
    private mutating func design(_ look: LegacyCVFile.Look?) -> DesignChoice? {
        guard let look else { return nil }
        guard let design = look.design, let choice = DesignChoice(design: design, palette: look.palette, fonts: look.fonts) else {
            note(.look); return nil
        }
        return choice
    }

    // MARK: Sections

    private mutating func sections(_ raw: LegacyCVFile.Raw) -> CVSections {
        CVSections(experiences: (raw.experiences ?? []).map { experience($0) }, education: (raw.education ?? []).map { education($0) },
                   skills: (raw.skills ?? []).map { skill($0) }, languages: (raw.languages ?? []).map { language($0) },
                   certifications: (raw.certifications ?? []).map { certification($0) },
                   profiles: (raw.social ?? []).compactMap { profile($0) }, interests: raw.interests ?? [])
    }

    private mutating func period(_ text: String?) -> Period? {
        switch LegacyPeriod.read(text ?? "") {
        case .none: return nil
        case .period(let period): return period
        case .unreadable: note(.period); return nil
        }
    }

    private mutating func experience(_ e: LegacyCVFile.Experience) -> Experience {
        Experience(role: e.title ?? "", company: e.company ?? "", location: e.location ?? "", period: period(e.period), description: e.description ?? "")
    }

    private mutating func education(_ e: LegacyCVFile.Education) -> Education {
        Education(degree: e.degree ?? "", school: e.school ?? "", period: period(e.period), description: e.description ?? "")
    }

    /// The legacy level 0 is "no level".
    private mutating func skill(_ s: LegacyCVFile.Skill) -> Skill {
        guard let raw = s.level, raw != 0 else { return Skill(name: s.name ?? "") }
        guard let level = SkillLevel(raw) else { note(.skillLevel); return Skill(name: s.name ?? "") }
        return Skill(name: s.name ?? "", level: level)
    }

    private func language(_ l: LegacyCVFile.Language) -> LanguageSkill {
        LanguageSkill(language: l.name ?? "", proficiency: Self.proficiency(l.level?.value ?? ""))
    }

    private mutating func certification(_ c: LegacyCVFile.Certification) -> Certification {
        let issued = c.year.flatMap { $0 == 0 ? nil : PartialDate(year: $0) }
        if let year = c.year, year != 0, issued == nil { note(.certificationYear) }
        return Certification(name: c.name ?? "", issuer: c.issuer ?? "", issued: issued,
                             link: optional(c.url, .certificationLink) { WebLink($0) }, description: c.description ?? "")
    }

    /// A profile exists only with a valid link.
    private mutating func profile(_ s: LegacyCVFile.Social) -> ProfileLink? {
        guard let link = WebLink((s.url ?? "").trimmingCharacters(in: .whitespacesAndNewlines)) else { note(.profile); return nil }
        return ProfileLink(platform: s.platform ?? "", link: link)
    }

    // MARK: Language levels

    /// As the legacy app read a level: the exact name, then words that stand for one, and B1 for what it did not know.
    static func proficiency(_ text: String) -> LanguageProficiency {
        let lowered = text.lowercased()
        if let exact = LanguageProficiency(rawValue: lowered) { return exact }
        let words: [(LanguageProficiency, [String])] = [
            (.native, ["native", "mother"]), (.a1, ["beginner", "a1"]), (.a2, ["elementary", "a2"]),
            (.b2, ["upper", "b2"]), (.b1, ["intermediate"]), (.c1, ["advanced", "c1"]), (.c2, ["proficient", "c2"]),
        ]
        return words.first { _, keys in keys.contains { lowered.contains($0) } }?.0 ?? .b1
    }
}
