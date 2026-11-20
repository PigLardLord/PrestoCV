import SwiftUI

// The values every screen takes its measures from. Colours are SwiftUI styles (`.tint`, `.secondary`, `.background`) at
// the call site, never a UIKit or AppKit colour, so that this folder builds for both platforms. A token lands here with
// its first user.

/// The gaps between elements
enum Spacing {
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
}

/// The rounding of controls
enum CornerRadius {
    static let control: CGFloat = 12
    /// The corner of a small page, such as a design's sample in the look picker
    static let page: CGFloat = 4
}

/// The size of the symbol that opens a screen
enum IconSize {
    /// A state screen: empty, failed
    static let state: CGFloat = 48
    /// The welcome of the first run
    static let hero: CGFloat = 64
}

/// The smallest height a control may have and still be easy to tap; a control that is a symbol alone takes it as its
/// width too
enum TapTarget {
    static let minimumHeight: CGFloat = 44
}

/// The round backing of a symbol button laid over content, such as the corner button over the PDF's pages; its tap
/// target stays `TapTarget.minimumHeight` on each side
enum OverlayButton {
    static let diameter: CGFloat = 28
}

/// The widest a block of reading text grows on a large screen
enum ReadableWidth {
    static let maximum: CGFloat = 560
}

/// The smallest height of a field of several lines at the default text size, about four lines of body text. It grows
/// with the text size.
enum ParagraphHeight {
    static let minimum: CGFloat = 96
}

/// The height of the box that holds the text of a CV to import, at the default text size. It grows with the text size
/// up to a share of the screen's height, and a long CV scrolls inside it, so that the buttons under it stay one swipe
/// away.
enum ImportBoxHeight {
    static let compact: CGFloat = 220
    /// A wide screen, such as an iPad's
    static let regular: CGFloat = 260
    /// A short screen, such as an iPhone on its side
    static let compactHeight: CGFloat = 140
    static let maximumShare: CGFloat = 0.6
}

/// The shape of a page of the PDF, its width over its height (A4)
enum PageShape {
    static let a4: CGFloat = 210.0 / 297.0
}

/// The narrowest a tile of the look picker may be: a design or a font scheme, and a colour
enum LookTile {
    static let minimumWidth: CGFloat = 96
    static let colorMinimumWidth: CGFloat = 72
}

/// The round sample of a colour in the look picker, as wide as a tap target
enum Swatch {
    static let diameter: CGFloat = 44
}

/// The width of a sample beside its name in a row of the look picker, at the accessibility text sizes
enum LookThumbnail {
    static let width: CGFloat = 84
}

/// The ring around the chosen item of the look picker, and the room between it and the sample
enum SelectionRing {
    static let width: CGFloat = 2
    static let gap: CGFloat = 3
}
