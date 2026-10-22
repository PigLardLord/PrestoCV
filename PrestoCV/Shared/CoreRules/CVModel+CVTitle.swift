import PrestoCVCore
import enum PrestoCVDomain.CVTitle
import enum PrestoCVDomain.CVSubtitle

extension CVModel {
    /// What the CV is called, by `CVTitle`: its name, otherwise the name of its person, otherwise their professional title
    var cvTitle: CVTitle {
        CVTitle(name: name, person: personalInfo.name, role: personalInfo.title)
    }

    /// The line under the title of the CV's row, by `CVSubtitle`: who the CV is about, without what its title says
    var rowSubtitle: String? {
        CVSubtitle.text(name: name, person: personalInfo.name, role: personalInfo.title)
    }

    /// What a copy of the CV is called: the title it is shown with, marked as a copy in the words of the app
    var copyName: String {
        cvTitle.copyName(untitled: "cv.untitled".localized, copySuffix: "action.copy_suffix".localized)
    }

    /// What a copy made of edits an earlier version of the app left unsaved is called, when the CV they were made on
    /// changed after them: the title of that CV, marked as recovered.
    var recoveredCopyName: String {
        let recovered = "unsaved_edits.recovered_suffix".localized
        return "\(cvTitle.text) \(recovered)"
    }

    /// What the editor of the CV calls it: its title; for a CV with none, "New CV" until it is stored, and "Untitled
    /// CV", as the list calls it, once it is.
    func editorTitle(isStored: Bool) -> String {
        guard case .untitled = cvTitle else { return cvTitle.text }
        return isStored ? "cv.untitled".localized : "editor.new_cv".localized
    }
}

extension CVTitle {
    /// The title in the words of the app: "Untitled CV" for a CV with none of a name, a person and a role
    var text: String {
        text(untitled: "cv.untitled".localized)
    }
}
