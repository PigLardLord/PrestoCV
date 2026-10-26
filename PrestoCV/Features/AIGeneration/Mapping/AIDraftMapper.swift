import Foundation
import PrestoCVCore
import CVGeneratorAI

/// A CV drafted by AI, not stored yet, and whether its personal items were left blank because the claim check gave no answer
/// (ADR 0028). The editor opens it with the notice that matches.
struct AIDraft: Equatable, Sendable {
    let cv: CVModel
    let personalItemsUnchecked: Bool

    var notice: EditorNotice {
        personalItemsUnchecked ? .aiDraftUnchecked : .aiDraft
    }
}

/// Turns what the on-device model produced into a CV the editor can open.
///
/// Pure: the same CV data and labels always give the same CV (apart from fresh ids). It lives in
/// the app because no package may import another, and the app is where the CV model and the
/// AI model meet (ADR 0007).
struct AIDraftMapper {
    let labels: AIDraftLabels
    /// The BCP 47 tag of the language a text is written in, or nil when it cannot tell
    let languageOfText: (String) -> String?

    /// The draft of a generation, with whether its personal items went unchecked.
    /// - Parameters:
    ///   - draft: What the generation gave from the description.
    ///   - description: The person's own text.
    func map(_ draft: GeneratedDraft, writtenIn description: String) -> AIDraft {
        AIDraft(cv: map(draft.cvData, writtenIn: description), personalItemsUnchecked: draft.personalItemsUnchecked)
    }

    /// - Parameters:
    ///   - cvData: What the model produced from the description.
    ///   - description: The person's own text. The CV is printed in its language when the templates
    ///     support it, and otherwise follows the app's language.
    func map(_ cvData: CVGeneratorAI.CVData, writtenIn description: String) -> CVModel {
        let info = cvData.personalInfo

        // No name of its own: the list calls the draft by its person, otherwise by its role (CVTitle), until it is renamed
        return CVModel(
            personalInfo: PrestoCVCore.PersonalInfo(
                name: info.name ?? "",
                title: info.title ?? "",
                location: info.location ?? "",
                email: info.email ?? "",
                phone: info.phone ?? "",
                portfolio: info.website ?? "",
                profile: cvData.summary ?? ""
            ),
            relevant_experience: cvData.experience.map(experience),
            education: cvData.education.map(education),
            skills: cvData.skills.map(skill),
            languages: cvData.languages.compactMap(language),
            certifications: cvData.certifications.map(certification),
            interests: interests(cvData.interests),
            social: socialLinks(info),
            documentLanguage: documentLanguage(of: description)
        )
    }

    // MARK: - Sections

    private func experience(_ entry: CVGeneratorAI.Experience) -> PrestoCVCore.Experience {
        let achievements = entry.achievements.map { "• \($0)" }
        let description = ([entry.description].compactMap { $0 } + achievements).joined(separator: "\n")

        return PrestoCVCore.Experience(
            title: entry.title,
            company: entry.company,
            location: entry.location ?? "",
            period: period(start: entry.startDate, end: entry.endDate, isCurrent: entry.current),
            description: description
        )
    }

    private func education(_ entry: CVGeneratorAI.Education) -> PrestoCVCore.Education {
        PrestoCVCore.Education(
            degree: entry.degree ?? "",
            school: entry.institution ?? "",
            period: period(start: entry.startDate, end: entry.endDate, isCurrent: false),
            description: entry.description ?? ""
        )
    }

    private func skill(_ entry: CVGeneratorAI.Skill) -> PrestoCVCore.Skill {
        PrestoCVCore.Skill(name: entry.name, level: skillLevel(entry.level))
    }

    /// A language the person gave without a level is skipped: any level would be made up.
    private func language(_ entry: CVGeneratorAI.Language) -> PrestoCVCore.Language? {
        guard let proficiency = entry.proficiency else { return nil }
        return PrestoCVCore.Language(name: entry.name, level: languageLevel(proficiency))
    }

    private func certification(_ entry: CVGeneratorAI.Certification) -> PrestoCVCore.Certification {
        PrestoCVCore.Certification(
            name: entry.name,
            issuer: entry.issuer ?? "",
            year: year(in: entry.date),
            url: entry.url ?? ""
        )
    }

    private func interests(_ interests: [String]) -> [String] {
        var seen = Set<String>()
        return interests
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }

    private func socialLinks(_ info: CVGeneratorAI.PersonalInfo) -> [Social] {
        let links = [("LinkedIn", info.linkedin), ("GitHub", info.github)]

        return links.compactMap { platform, url in
            guard let url = url?.trimmingCharacters(in: .whitespacesAndNewlines), !url.isEmpty else { return nil }
            return Social(platform: platform, url: url)
        }
    }

    // MARK: - Values

    private func documentLanguage(of description: String) -> String? {
        languageOfText(description).flatMap(DocumentLanguage.init(languageTag:))?.rawValue
    }

    /// "start – end"; just the one date when only one is known. A current job has no end, so it ends with the
    /// injected word, unless the draft states an end date: that date always wins.
    private func period(start: String?, end: String?, isCurrent: Bool) -> String {
        let finish = end ?? (isCurrent ? labels.present : nil)

        switch (start, finish) {
        case let (start?, finish?): return "\(start) – \(finish)"
        case let (start?, nil): return start
        case let (nil, finish?): return finish
        case (nil, nil): return ""
        }
    }

    /// The editor rates skills with up to `Skill.maxLevel` stars; no level is no stars, and an expert gets them all.
    private func skillLevel(_ level: CVGeneratorAI.SkillLevel?) -> Int {
        switch level {
        case nil: return 0
        case .beginner?: return 1
        case .intermediate?: return 3
        case .advanced?: return 4
        case .expert?: return PrestoCVCore.Skill.maxLevel
        }
    }

    private func languageLevel(_ proficiency: CVGeneratorAI.LanguageProficiency) -> LanguageProficiencyLevel {
        switch proficiency {
        case .a1: return .a1
        case .a2: return .a2
        case .b1: return .b1
        case .b2: return .b2
        case .c1: return .c1
        case .c2: return .c2
        case .native: return .native
        }
    }

    /// The first plausible year in a free-form date such as "June 2022"; 0 when there is none.
    private func year(in date: String?) -> Int {
        guard let date else { return 0 }
        let numbers = date.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Int($0) }
        return numbers.first { (1900...2100).contains($0) } ?? 0
    }
}
