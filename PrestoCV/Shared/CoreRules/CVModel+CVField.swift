import PrestoCVCore
import enum PrestoCVDomain.CVField

extension CVModel {
    /// The CV with `fields` left blank. A profile keeps its platform, without its link.
    func clearing(_ fields: Set<CVField>) -> CVModel {
        var cv = self
        for field in fields {
            switch field {
            case .title: cv.name = ""
            case .fullName: cv.personalInfo.name = ""
            case .professionalTitle: cv.personalInfo.title = ""
            case .email: cv.personalInfo.email = ""
            case .phone: cv.personalInfo.phone = ""
            case .location: cv.personalInfo.location = ""
            case .website: cv.personalInfo.portfolio = ""
            case .summary: cv.personalInfo.profile = ""
            case .profileLinks: cv.social = cv.social.map { Social(id: $0.id, platform: $0.platform, url: "") }
            }
        }
        return cv
    }
}
