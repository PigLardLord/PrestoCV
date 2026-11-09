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
}

/// The size of the symbol that opens a screen
enum IconSize {
    /// A state screen: empty, failed
    static let state: CGFloat = 48
    /// The welcome of the first run
    static let hero: CGFloat = 64
}

/// The smallest height a control may have and still be easy to tap
enum TapTarget {
    static let minimumHeight: CGFloat = 44
}

/// The widest a block of reading text grows on a large screen
enum ReadableWidth {
    static let maximum: CGFloat = 560
}
