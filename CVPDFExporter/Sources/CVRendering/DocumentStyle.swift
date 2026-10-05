import Foundation
import CVDesignCatalog

/// The look a document is rendered with: a validated design's stylesheet, and the palette and font scheme chosen with it.
public struct DocumentStyle: Sendable {
    public let stylesheet: ValidatedStylesheet
    public let palette: Palette
    public let fonts: FontScheme

    public init(stylesheet: ValidatedStylesheet, palette: Palette, fonts: FontScheme = .system) {
        self.stylesheet = stylesheet
        self.palette = palette
        self.fonts = fonts
    }
}
