import SwiftUI

/// How closely the first run sets its ways to start, for the text size.
///
/// At the accessibility sizes the dimmed AI draft, with the line that says why, pushed the blank CV off the first screen
/// of a short one, as the outer screen of the iPhone Duo. So at every accessibility size, on every device, the ways to
/// start sit closer together and leave out their symbols, so that their titles get the whole width and take fewer
/// lines.
enum FirstRunActionDensity: Equatable {
    case regular
    case compact

    static func resolve(dynamicTypeSize: DynamicTypeSize) -> FirstRunActionDensity {
        dynamicTypeSize.isAccessibilitySize ? .compact : .regular
    }

    /// The space between one way to start and the next.
    var spacing: CGFloat {
        switch self {
        case .regular: return DesignTokens.Spacing.lg
        case .compact: return DesignTokens.Spacing.xs
        }
    }

    /// The symbol a way to start shows next to its title, or none.
    func symbol(_ name: String) -> String? {
        switch self {
        case .regular: return name
        case .compact: return nil
        }
    }

    /// The largest size the line under the dimmed AI draft is drawn at: the full explanation, a tap away and read by
    /// VoiceOver, grows to every size.
    static let largestReasonLineSize = DynamicTypeSize.accessibility1
}
