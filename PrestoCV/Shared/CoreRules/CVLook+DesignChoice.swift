import PrestoCVCore
import struct PrestoCVDomain.DesignChoice

extension CVLook {
    /// The look that keeps a design choice: its ids, copied as they are. PrestoCVCore stores plain text and knows
    /// nothing of `DesignChoice`, so the app, which sees both, translates.
    init(_ choice: DesignChoice) {
        self.init(design: choice.design, palette: choice.palette, fonts: choice.fonts)
    }
}
