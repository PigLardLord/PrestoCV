import PrestoCVCore
import enum PrestoCVDomain.CVTitle

extension CVModel {
    /// What the CV is called, by `CVTitle`: its name, otherwise the name of its person, otherwise their professional title
    var cvTitle: CVTitle {
        CVTitle(name: name, person: personalInfo.name, role: personalInfo.title)
    }

    /// What the editor of the CV, and the offer to restore its edits, call it: its title; for a CV with none, "New CV"
    /// until it is stored, and "Untitled CV", as the list calls it, once it is.
    func editorTitle(isStored: Bool) -> String {
        guard case .untitled = cvTitle else { return cvTitle.text }
        return isStored ? "cv.untitled".localized : "editor.new_cv".localized
    }
}

extension CVTitle {
    /// The title in the words of the app: "Untitled CV" for a CV with none of a name, a person and a role
    var text: String {
        switch self {
        case .name(let text), .person(let text), .role(let text):
            return text
        case .untitled:
            return "cv.untitled".localized
        }
    }
}
