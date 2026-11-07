import Testing
import Foundation
import PrestoCVDomain

/// Every text field of the domain's value types, by name and kind. The Mirror check below fails when a type gains a
/// text field that is not listed here, so a new field cannot skip the rule (R10).
private struct Field<Root> {
    let name: String, multiLine: Bool, path: WritableKeyPath<Root, String>
    init(_ name: String, _ path: WritableKeyPath<Root, String>, multiLine: Bool = false) {
        self.name = name; self.path = path; self.multiLine = multiLine
    }
}

private let dirty = "\u{202E}a\tb\r\nc\u{0}d\u{E0041}e"
private func clean(_ multiLine: Bool) -> String { multiLine ? "a b\ncd" + "e" : "a b cd" + "e" }

private func stringLabels<T>(of value: T) -> Set<String> {
    Set(Mirror(reflecting: value).children.compactMap { $0.value is String ? $0.label : nil })
}

@Suite("R6 · every text field applies the rule")
struct TextFieldsTests {
    private func check<Root>(_ fields: [Field<Root>], blank: Root, make: (WritableKeyPath<Root, String>) -> Root) {
        #expect(stringLabels(of: blank) == Set(fields.map(\.name)), "a text field is missing from the list")
        for field in fields {
            let expected = clean(field.multiLine)
            let built = make(field.path)
            #expect(built[keyPath: field.path] == expected, "initialiser: \(field.name)")
            var set = blank
            set[keyPath: field.path] = dirty
            #expect(set[keyPath: field.path] == expected, "setter: \(field.name)")
        }
    }

    @Test("PersonalDetails")
    func personal() {
        let fields: [Field<PersonalDetails>] = [
            Field("fullName", \.fullName), Field("professionalTitle", \.professionalTitle), Field("location", \.location),
            Field("summary", \.summary, multiLine: true),
        ]
        check(fields, blank: PersonalDetails()) { path in
            PersonalDetails(fullName: path == \.fullName ? dirty : "", professionalTitle: path == \.professionalTitle ? dirty : "",
                                    location: path == \.location ? dirty : "", summary: path == \.summary ? dirty : "")
        }
    }

    @Test("Experience")
    func experience() {
        let fields: [Field<Experience>] = [Field("role", \.role), Field("company", \.company), Field("location", \.location),
                                           Field("description", \.description, multiLine: true)]
        check(fields, blank: Experience(role: "", company: "")) { path in
            Experience(role: path == \.role ? dirty : "", company: path == \.company ? dirty : "",
                       location: path == \.location ? dirty : "", description: path == \.description ? dirty : "")
        }
    }

    @Test("Education")
    func education() {
        let fields: [Field<Education>] = [Field("degree", \.degree), Field("school", \.school), Field("description", \.description, multiLine: true)]
        check(fields, blank: Education(degree: "", school: "")) { path in
            Education(degree: path == \.degree ? dirty : "", school: path == \.school ? dirty : "", description: path == \.description ? dirty : "")
        }
    }

    @Test("Skill, LanguageSkill and ProfileLink")
    func small() throws {
        check([Field<Skill>("name", \.name)], blank: Skill(name: "")) { _ in Skill(name: dirty) }
        check([Field<LanguageSkill>("language", \.language)], blank: LanguageSkill(language: "", proficiency: .b1)) { _ in
            LanguageSkill(language: dirty, proficiency: .b1)
        }
        let link = try #require(WebLink("https://ada.example"))
        check([Field<ProfileLink>("platform", \.platform)], blank: ProfileLink(platform: "", link: link)) { _ in
            ProfileLink(platform: dirty, link: link)
        }
    }

    @Test("Certification")
    func certification() {
        let fields: [Field<Certification>] = [Field("name", \.name), Field("issuer", \.issuer), Field("description", \.description, multiLine: true)]
        check(fields, blank: Certification(name: "", issuer: "")) { path in
            Certification(name: path == \.name ? dirty : "", issuer: path == \.issuer ? dirty : "", description: path == \.description ? dirty : "")
        }
    }

    @Test("the interests and the CV's own title")
    func interestsAndTitle() {
        var sections = CVSections(interests: [" \(dirty) ", "a b cde", "Chess"])
        #expect(sections.interests == ["a b cde", "Chess"])
        sections.setInterests(["x\ty"])
        #expect(sections.interests == ["x y"])
        #expect(CV(id: id1, title: dirty).title == "a b cde")
        var cv = CV(id: id1)
        cv.rename(dirty)
        #expect(cv.title == "a b cde")
        #expect(cv.duplicated(as: id1, title: dirty).title == "a b cde")
    }

    @Test("a CV given sections and details keeps them clean, whatever came in")
    func wholeCV() {
        let cv = CV(id: id1, personal: PersonalDetails(fullName: "Ada\u{202E}"), sections: CVSections(skills: [Skill(name: "S\u{0}wift")]))
        #expect(cv.personal.fullName == "Ada" && cv.sections.skills.first?.name == "Swift")
    }

    @Test("e-mail, phone and web address refuse the same characters, as they always did",
          arguments: ["\u{202E}", "\u{200F}", "\u{E0041}", "\t", "\n", "\u{0}"])
    func valueObjectsRefuse(hidden: String) {
        #expect(EmailAddress("ada\(hidden)@example.com") == nil)
        #expect(PhoneNumber("+39 06\(hidden)1234567") == nil)
        #expect(WebLink("https://ada\(hidden).example") == nil)
    }
}
