import Testing
import Foundation
import PrestoCVDomain

/// A text of `bytes` UTF-8 bytes in at most 10,000 characters: 2-byte letters for the rest.
private func text(bytes: Int) -> String {
    if bytes <= CVLimits.maxTextCharacters { return String(repeating: "a", count: bytes) }
    let twoByte = bytes - CVLimits.maxTextCharacters   // each 2-byte letter adds one byte to a character
    return String(repeating: "a", count: CVLimits.maxTextCharacters - twoByte) + String(repeating: "é", count: twoByte)
}

private func cv(summary: String = "", sections: CVSections = CVSections()) -> CV {
    CV(id: id1, personal: PersonalDetails(fullName: "Ada", summary: summary), sections: sections)
}

@Suite("R6 · size limits at save")
struct CVLimitsTests {
    @Test("the limits are the ones the document validator keeps, or below")
    func constants() {
        #expect(CVLimits.maxTextBytes == 16_384 && CVLimits.maxTextCharacters == 10_000)
        #expect(CVLimits.maxTotalTextBytes == 262_144 && CVLimits.maxEntriesPerSection == 200)
    }

    @Test("a text at the byte limit saves; one byte over is textTooLong with its field")
    func byteLimit() {
        let atLimit = text(bytes: CVLimits.maxTextBytes)
        #expect(atLimit.utf8.count == 16_384 && atLimit.count == 10_000)
        #expect(cv(summary: atLimit).saveCheck() == .ok)
        #expect(cv(summary: text(bytes: CVLimits.maxTextBytes + 1)).saveCheck() == .textTooLong(.summary))
        #expect(!cv(summary: text(bytes: CVLimits.maxTextBytes + 1)).canBeSaved)
    }

    @Test("a text over 10,000 characters is refused though its bytes are within the limit")
    func characterLimit() {
        #expect(cv(summary: String(repeating: "a", count: 10_000)).saveCheck() == .ok)
        #expect(cv(summary: String(repeating: "a", count: 10_001)).saveCheck() == .textTooLong(.summary))
    }

    @Test("the refusal names the field that is too long, in each section")
    func fieldNames() {
        let long = String(repeating: "a", count: 10_001)
        func check(_ sections: CVSections, _ field: CVTextField) { #expect(cv(sections: sections).saveCheck() == .textTooLong(field)) }
        check(CVSections(experiences: [Experience(role: "r", company: long)]), .experienceCompany)
        check(CVSections(education: [Education(degree: "d", school: "s", description: long)]), .educationDescription)
        check(CVSections(skills: [Skill(name: long)]), .skillName)
        check(CVSections(interests: [long]), .interest)
        #expect(CV(id: id1, title: long, personal: PersonalDetails(fullName: "Ada")).saveCheck() == .textTooLong(.title))
        #expect(CV(id: id1, personal: PersonalDetails(fullName: long)).saveCheck() == .textTooLong(.fullName))
    }

    @Test("200 entries in a section save; 201 are tooManyEntries with the section", arguments: CVSection.allCases)
    func entryLimit(section: CVSection) {
        func sections(_ n: Int) -> CVSections {
            let link = WebLink("https://ada.example")!
            switch section {
            case .experiences: return CVSections(experiences: (0..<n).map { Experience(role: "r\($0)", company: "c") })
            case .education: return CVSections(education: (0..<n).map { Education(degree: "d\($0)", school: "s") })
            case .skills: return CVSections(skills: (0..<n).map { Skill(name: "s\($0)") })
            case .languages: return CVSections(languages: (0..<n).map { LanguageSkill(language: "l\($0)", proficiency: .b1) })
            case .certifications: return CVSections(certifications: (0..<n).map { Certification(name: "c\($0)", issuer: "i") })
            case .profiles: return CVSections(profiles: (0..<n).map { ProfileLink(platform: "p\($0)", link: link) })
            case .interests: return CVSections(interests: (0..<n).map { "i\($0)" })
            }
        }
        #expect(cv(sections: sections(200)).saveCheck() == .ok)
        #expect(cv(sections: sections(201)).saveCheck() == .tooManyEntries(section))
    }

    @Test("all the texts together are at most 262,144 bytes; one byte more is cvTooLarge")
    func totalLimit() {
        func big(extra: Int) -> CV {
            var entries = (0..<26).map { _ in Experience(role: "", company: "", description: String(repeating: "a", count: 10_000)) }
            entries.append(Experience(role: "", company: "", description: String(repeating: "a", count: 2_144 + extra)))
            return CV(id: id1, sections: CVSections(experiences: entries))
        }
        #expect(big(extra: 0).saveCheck() == .ok)
        #expect(big(extra: 1).saveCheck() == .cvTooLarge)
    }

    @Test("an empty CV is notEnoughContent, before any size is looked at")
    func emptyFirst() {
        #expect(CV(id: id1).saveCheck() == .notEnoughContent)
    }

    @Test("an oversize CV is built as it is given and never cut")
    func neverCut() {
        let long = String(repeating: "é", count: 9_000)
        let big = cv(summary: long, sections: CVSections(skills: (0..<250).map { Skill(name: "s\($0)") }))
        #expect(big.personal.summary == long && big.sections.skills.count == 250)
        #expect(big.saveCheck() == .textTooLong(.summary))
    }

    @Test("a text counts its UTF-8 bytes after the rule has removed what it removes")
    func countsAfterNormalising() {
        let padded = String(repeating: "a", count: 10_000) + String(repeating: "\u{202E}", count: 50)
        #expect(cv(summary: padded).saveCheck() == .ok)
    }
}
