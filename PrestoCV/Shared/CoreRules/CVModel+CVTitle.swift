import PrestoCVCore
import enum PrestoCVDomain.CVTitle

extension CVModel {
    /// What the CV is called, by `CVTitle`: its name, otherwise the professional title of its person
    var cvTitle: CVTitle {
        CVTitle(name: name, role: personalInfo.title)
    }
}

extension CVTitle {
    /// The title in the words of the app: "Untitled CV" for a CV with neither a name nor a role
    var text: String {
        switch self {
        case .name(let text), .role(let text):
            return text
        case .untitled:
            return "cv.untitled".localized
        }
    }
}
