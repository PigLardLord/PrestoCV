import Foundation
@testable import CVGeneratorAI

/// A draft as a list of fields (`experience[0].startDate = 2016`), one for each text that is not empty.
enum Sheet {
    struct Step {
        let name: String
        let index: Int?

        init(_ name: String, _ index: Int? = nil) {
            self.name = name
            self.index = index
        }
    }

    struct Leaf {
        let steps: [Step]
        let value: String

        var path: String {
            steps.map { step in step.index.map { "\(step.name)[\($0)]" } ?? step.name }.joined(separator: ".")
        }
    }

    static func leaves(of cv: CVData) -> [Leaf] {
        var found: [Leaf] = []
        func add(_ steps: [Step], _ value: String?) {
            guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            found.append(Leaf(steps: steps, value: value))
        }

        let info = cv.personalInfo
        let personal: [(String, String?)] = [
            ("name", info.name), ("email", info.email), ("phone", info.phone), ("location", info.location),
            ("website", info.website), ("linkedin", info.linkedin), ("github", info.github), ("title", info.title),
        ]
        for (name, value) in personal { add([Step("personalInfo"), Step(name)], value) }
        add([Step("summary")], cv.summary)

        for (index, job) in cv.experience.enumerated() {
            let entry = Step("experience", index)
            let fields: [(String, String?)] = [
                ("title", job.title), ("company", job.company), ("location", job.location), ("startDate", job.startDate),
                ("endDate", job.endDate), ("current", job.current ? "true" : nil), ("description", job.description),
            ]
            for (name, value) in fields { add([entry, Step(name)], value) }
            for (number, achievement) in job.achievements.enumerated() { add([entry, Step("achievements", number)], achievement) }
        }
        for (index, study) in cv.education.enumerated() {
            let entry = Step("education", index)
            let fields: [(String, String?)] = [
                ("degree", study.degree), ("institution", study.institution), ("startDate", study.startDate),
                ("endDate", study.endDate), ("description", study.description),
            ]
            for (name, value) in fields { add([entry, Step(name)], value) }
        }
        for (index, skill) in cv.skills.enumerated() {
            add([Step("skills", index), Step("name")], skill.name)
            add([Step("skills", index), Step("level")], skill.level?.rawValue)
            add([Step("skills", index), Step("kind")], skill.kind == .softSkill ? skill.kind.rawValue : nil)
        }
        for (index, language) in cv.languages.enumerated() {
            add([Step("languages", index), Step("name")], language.name)
            add([Step("languages", index), Step("proficiency")], language.proficiency?.rawValue)
        }
        for (index, certification) in cv.certifications.enumerated() {
            let entry = Step("certifications", index)
            let fields: [(String, String?)] = [
                ("name", certification.name), ("issuer", certification.issuer), ("date", certification.date), ("url", certification.url),
            ]
            for (name, value) in fields { add([entry, Step(name)], value) }
        }
        for (index, interest) in cv.interests.enumerated() { add([Step("interests", index)], interest) }
        return found
    }

    /// The fields by path, with the entries and achievements renumbered: an entry with nothing left is not counted.
    static func fields(of cv: CVData) -> [String: String] {
        compacted(leaves(of: cv))
    }

    /// The fields the sanitised draft must have for a `keeping` outcome.
    static func fields(of draft: CVData, dropping drops: [Drop], rewriting rewrites: [Rewrite]) -> [String: String] {
        let dropped = Set(drops.map(\.path))
        var rewritten: [String: String] = [:]
        for rewrite in rewrites { rewritten[rewrite.path] = rewrite.value }

        let kept = leaves(of: draft)
            .filter { !dropped.contains($0.path) }
            .map { leaf in rewritten[leaf.path].map { Leaf(steps: leaf.steps, value: $0) } ?? leaf }
        return compacted(kept)
    }

    private static func compacted(_ leaves: [Leaf]) -> [String: String] {
        var counters: [String: Int] = [:]
        var numbers: [String: Int] = [:]
        var fields: [String: String] = [:]

        for leaf in leaves {
            var path = ""
            for step in leaf.steps {
                path += path.isEmpty ? "" : "."
                guard let index = step.index else {
                    path += step.name
                    continue
                }
                let list = path + step.name
                let key = "\(list)#\(index)"
                if numbers[key] == nil {
                    numbers[key] = counters[list, default: 0]
                    counters[list, default: 0] += 1
                }
                path += "\(step.name)[\(numbers[key] ?? 0)]"
            }
            fields[path] = leaf.value
        }
        return fields
    }
}
