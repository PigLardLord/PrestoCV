internal import PrestoCVApplication
internal import PrestoCVDomain

// The form's text read into a CV and back. It holds no rule: what a CV may hold, the domain's value objects and
// `CV.saveCheck()` say.

extension EditorContent {
    static let empty = EditorContent(
        title: "", fullName: "", professionalTitle: "", email: "", phone: "", location: "", website: "", summary: ""
    )

    /// The form as the CV holds it.
    init(_ cv: CV) {
        let person = cv.personal
        self.init(
            title: cv.title, fullName: person.fullName, professionalTitle: person.professionalTitle,
            email: person.email?.value ?? "", phone: person.phone?.value ?? "", location: person.location,
            website: person.website?.value ?? "", summary: person.summary
        )
    }

    /// `base` with the form's text: its identity, sections, look and language stay. A field that cannot be read as its
    /// kind is left out; `unreadableFields` names it.
    func applied(to base: CV) -> CV {
        var cv = base
        cv.rename(title)
        cv.setPersonalDetails(PersonalDetails(
            fullName: fullName, professionalTitle: professionalTitle, email: EmailAddress(email), phone: PhoneNumber(phone),
            location: location, website: WebLink(website), summary: summary
        ))
        return cv
    }

    /// The fields whose text is not blank and cannot be read as its kind, in the form's order.
    var unreadableFields: [EditorField] {
        let readings: [(EditorField, String, Bool)] = [
            (.email, email, EmailAddress(email) != nil),
            (.phone, phone, PhoneNumber(phone) != nil),
            (.website, website, WebLink(website) != nil),
        ]
        return readings.filter { _, text, isRead in !isRead && !text.allSatisfy(\.isWhitespace) }.map(\.0)
    }
}

extension EditorLook {
    init(_ design: DesignChoice) {
        self.init(design: design.design, palette: design.palette, fonts: design.fonts)
    }
}

extension LookChange {
    /// Nil when an id is not one a design may have.
    init?(shown look: EditorLook, parts: Set<LookPart>) {
        guard let shown = DesignChoice(design: look.design, palette: look.palette, fonts: look.fonts) else { return nil }
        self.init(shown: shown, parts: Set(parts.map(LookChange.Part.init)))
    }
}

extension LookChange.Part {
    init(_ part: LookPart) {
        switch part {
        case .design: self = .design
        case .palette: self = .palette
        case .fonts: self = .fonts
        }
    }
}
