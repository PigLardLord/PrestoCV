import PrestoCVCore
import struct PrestoCVApplication.LookChange

extension CVEditorViewModel {

    /// The design, palette or font the person chose for the PDF of this CV in its export sheet. The form keeps the look
    /// with the rest of the CV, and saves it by itself. Only the parts chosen change: the ids of the others stay as the
    /// CV holds them.
    func chooseLook(_ change: LookChange) {
        cv.look = CVLook.applying(change, to: cv.look)
    }
}
