import Foundation

/// The characters that the reader of a CV cannot see, or that reorder what they see (ADR 0031): a control character, a format
/// character (a bidirectional mark, a zero-width character, the soft hyphen), a private-use, surrogate or unassigned scalar, and a
/// line or paragraph separator. A sentence the model writes holds none, and the description is read without them: one in the CV the
/// person shares would hide an address from the checks (`AddressTokens`) or turn the text around.
enum HiddenCharacters {
    /// Whether the reader cannot see `scalar`. Every space separator is seen, the no-break spaces of French and German included.
    static func hides(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .control, .format, .surrogate, .privateUse, .unassigned, .lineSeparator, .paragraphSeparator: true
        default: false
        }
    }

    /// Whether `text` holds a scalar that the reader cannot see.
    static func occur(in text: String) -> Bool {
        text.unicodeScalars.contains(where: hides)
    }

    /// `description` as it is read: the characters the reader cannot see are left out, so that a soft hyphen in a pasted word costs
    /// the person no sentence. A tab is a space, and a line break stays one ("\n", "\r\n" and "\r", and the line and paragraph
    /// separators, which a text copied from a page uses).
    static func cleaned(_ description: String) -> String {
        var scalars = String.UnicodeScalarView()
        var previous: Unicode.Scalar?
        for scalar in description.unicodeScalars {
            defer { previous = scalar }
            switch scalar {
            case "\t":
                scalars.append(" ")
            case "\n" where previous == "\r":
                break
            case "\n", "\r", "\u{0085}", "\u{2028}", "\u{2029}":
                scalars.append("\n")
            default:
                if !hides(scalar) { scalars.append(scalar) }
            }
        }
        return String(scalars)
    }

    // MARK: - The draft

    /// `cvData` read as `cleaned(_:)` reads the description: a fact or a sentence of the model that holds a character the reader
    /// cannot see shows the reader the text without it, and the checks read the words of that text, so the draft keeps it only as
    /// such. A sentence the model quotes from the description is checked by its letters and digits alone, and would otherwise reach
    /// the CV with the character in it. The skills stay as they are: a name with such a character goes (`SkillNameShape`).
    static func cleaned(_ cvData: CVData) -> CVData {
        let text: (String) -> String = { cleaned($0) }
        let info = cvData.personalInfo
        return CVData(
            personalInfo: PersonalInfo(
                name: info.name.map(text), email: info.email.map(text), phone: info.phone.map(text), location: info.location.map(text),
                website: info.website.map(text), linkedin: info.linkedin.map(text), github: info.github.map(text),
                title: info.title.map(text)
            ),
            summary: cvData.summary.map(text),
            experience: cvData.experience.map { job in
                Experience(
                    title: text(job.title), company: text(job.company), location: job.location.map(text),
                    startDate: job.startDate.map(text), endDate: job.endDate.map(text), current: job.current,
                    description: job.description.map(text), achievements: job.achievements.map(text)
                )
            },
            education: cvData.education.map { study in
                Education(
                    degree: study.degree.map(text), institution: study.institution.map(text), startDate: study.startDate.map(text),
                    endDate: study.endDate.map(text), description: study.description.map(text)
                )
            },
            skills: cvData.skills,
            languages: cvData.languages.map { Language(name: text($0.name), proficiency: $0.proficiency) },
            certifications: cvData.certifications.map { certificate in
                Certification(
                    name: text(certificate.name), issuer: certificate.issuer.map(text), date: certificate.date.map(text),
                    url: certificate.url.map(text)
                )
            },
            interests: cvData.interests.map(text)
        )
    }

    /// `writing` with its summary and duties read as `cleaned(_:)` reads the description, as in `cleaned(_ cvData:)`; its skills
    /// stay as they are.
    static func cleaned(_ writing: DraftWriting) -> DraftWriting {
        DraftWriting(
            summary: writing.summary.map { cleaned($0) }, roleDescriptions: writing.roleDescriptions.map { $0.map { cleaned($0) } },
            technologies: writing.technologies, softSkills: writing.softSkills
        )
    }
}
