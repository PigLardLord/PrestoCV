import Foundation
import CVDesignCatalog

/// The look a document is rendered with: a validated design's stylesheet, and the palette and font scheme chosen with it.
public struct DocumentStyle: Sendable, Equatable {
    public let stylesheet: ValidatedStylesheet
    public let palette: Palette
    public let fonts: FontScheme

    /// - Parameters:
    ///   - stylesheet: the CSS of a design that passed `DesignPackageValidator`.
    ///   - palette: the colours the design's variables resolve to; readable by construction.
    ///   - fonts: the font stacks the design's variables resolve to; the system fonts when omitted.
    public init(stylesheet: ValidatedStylesheet, palette: Palette, fonts: FontScheme = .system) {
        self.stylesheet = stylesheet
        self.palette = palette
        self.fonts = fonts
    }
}
