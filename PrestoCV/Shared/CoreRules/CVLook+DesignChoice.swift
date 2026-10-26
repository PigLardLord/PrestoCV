import PrestoCVCore
import struct PrestoCVApplication.LookChange
import struct PrestoCVDomain.DesignChoice

extension CVLook {
    /// The look that keeps a design choice: its ids, copied as they are. PrestoCVCore stores plain text and knows
    /// nothing of `DesignChoice`, so the app, which sees both, translates.
    init(_ choice: DesignChoice) {
        self.init(design: choice.design, palette: choice.palette, fonts: choice.fonts)
    }

    /// The look of a CV after the person made `change` in the export sheet, when the CV held `stored`.
    ///
    /// The parts the person chose are set from the look the sheet showed. Every other part stays as the CV holds it, an
    /// id the app does not know included: the sheet showed a default for it, which the person never chose. A CV with no
    /// look yet takes all the look the sheet showed, so that it keeps what the person saw.
    static func applying(_ change: LookChange, to stored: CVLook?) -> CVLook {
        guard var look = stored else { return CVLook(change.shown) }
        if change.parts.contains(.design) { look.design = change.shown.design }
        if change.parts.contains(.palette) { look.palette = change.shown.palette }
        if change.parts.contains(.fonts) { look.fonts = change.shown.fonts }
        return look
    }
}
