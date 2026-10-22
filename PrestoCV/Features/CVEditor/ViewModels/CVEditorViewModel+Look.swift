import PrestoCVCore
import struct PrestoCVDomain.DesignChoice

extension CVEditorViewModel {

    /// The design, palette and font chosen for the PDF of this CV in its export sheet. The form keeps them with the rest
    /// of the CV, and saves them by itself.
    func chooseLook(_ choice: DesignChoice) {
        cv.look = CVLook(choice)
    }
}
