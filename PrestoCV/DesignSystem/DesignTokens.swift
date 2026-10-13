import SwiftUI

// MARK: - Design Tokens
/// Centralized design system constants for consistent UI
enum DesignTokens {
    
    // MARK: - Spacing
    enum Spacing {
        static let xxxs: CGFloat = 2
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 40
    }
    
    // MARK: - Corner Radius
    enum CornerRadius {
        static let xs: CGFloat = 2
        static let sm: CGFloat = 4
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
        static let xxl: CGFloat = 20
        static let full: CGFloat = .infinity
    }
    
    // MARK: - Icon Sizes
    enum IconSize {
        case small
        case medium
        case large
        case hero
        case heroLarge
        
        var font: Font {
            switch self {
            case .small:
                return .system(size: 16)
            case .medium:
                return .system(size: 20)
            case .large:
                return .system(size: 24)
            case .hero:
                return .system(size: 48)
            case .heroLarge:
                return .system(size: 64)
            }
        }
        
        var size: CGFloat {
            switch self {
            case .small:
                return 16
            case .medium:
                return 20
            case .large:
                return 24
            case .hero:
                return 48
            case .heroLarge:
                return 64
            }
        }
    }
    
    // MARK: - Indicator Sizes
    enum IndicatorSize {
        static let small: CGFloat = 6
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
    }
    
    // MARK: - Input Sizes
    enum InputSize {
        static let textEditorMinHeight: CGFloat = 100
        static let textFieldWidth: CGFloat = 80
        static let textFieldMaxWidth: CGFloat = 100
        /// The smallest size of anything the user taps.
        static let minimumTapTarget: CGFloat = 44
    }
    
    // MARK: - Border Widths
    enum BorderWidth {
        static let thin: CGFloat = 1
        static let medium: CGFloat = 2
        static let thick: CGFloat = 3
    }
    
    // MARK: - Opacity
    enum Opacity {
        static let disabled: Double = 0.3
        static let subtle: Double = 0.5
        static let medium: Double = 0.7
        static let prominent: Double = 0.9
        static let opaque: Double = 1.0
    }
    
    // MARK: - Animation Durations
    enum AnimationDuration {
        static let fast: Double = 0.2
        static let standard: Double = 0.3
        static let slow: Double = 0.5
    }
    
    // MARK: - Animations
    enum Animations {
        static let fastEaseInOut = Animation.easeInOut(duration: AnimationDuration.fast)
        static let standardEaseInOut = Animation.easeInOut(duration: AnimationDuration.standard)
        static let slowEaseInOut = Animation.easeInOut(duration: AnimationDuration.slow)
        static let spring = Animation.spring()
        static let bouncy = Animation.bouncy()
    }
    
    // MARK: - Colors
    enum Colors {
        // Text colors
        static let primary = Color.primary
        static let secondary = Color.secondary
        static let tertiary = Color.gray
        static let inverse = Color.white
        
        // Background colors
        static let background = Color(UIColor.systemBackground)
        static let backgroundSecondary = Color(UIColor.secondarySystemBackground)
        static let backgroundTertiary = Color(UIColor.tertiarySystemBackground)
        static let backgroundInverse = Color(UIColor.label)
        
        // Accent colors
        static let accent = Color.blue
        static let accentSecondary = Color.purple
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let info = Color.blue
        
        // Semantic colors
        static let border = Color.gray.opacity(0.3)
        static let divider = Color.gray.opacity(0.2)
        static let shadow = Color.black.opacity(0.1)
        static let overlay = Color.black.opacity(0.4)
        
        // Button colors
        static let primaryButtonBackground = accent
        static let primaryButtonForeground = Color.white
        static let secondaryButtonBackground = Color.clear
        static let secondaryButtonForeground = accent
        static let destructiveButtonBackground = error
        static let destructiveButtonForeground = Color.white
        static let disabledButtonBackground = Color.gray.opacity(0.3)
        static let disabledButtonForeground = Color.gray
        
        // Tag colors
        static let tagBackground = backgroundSecondary
        static let tagForeground = primary
        static let tagBorder = border
    }
    
    // MARK: - Shadow
    enum Shadow {
        static let small = (radius: CGFloat(2), x: CGFloat(0), y: CGFloat(1))
        static let medium = (radius: CGFloat(4), x: CGFloat(0), y: CGFloat(2))
        static let large = (radius: CGFloat(8), x: CGFloat(0), y: CGFloat(4))
    }
    
    // MARK: - Typography
    enum Typography {
        case largeTitle
        case title1
        case title2
        case title3
        case headline
        case subheadline
        case body
        case callout
        case footnote
        case caption1
        case caption2
        
        var font: Font {
            switch self {
            case .largeTitle: return .largeTitle
            case .title1: return .title
            case .title2: return .title2
            case .title3: return .title3
            case .headline: return .headline
            case .subheadline: return .subheadline
            case .body: return .body
            case .callout: return .callout
            case .footnote: return .footnote
            case .caption1: return .caption
            case .caption2: return .caption2
            }
        }
        
        var fontWeight: Font.Weight {
            switch self {
            case .largeTitle, .title1, .title2: return .bold
            case .title3, .headline: return .semibold
            case .subheadline, .body, .callout: return .regular
            case .footnote, .caption1, .caption2: return .regular
            }
        }
        
        var color: Color {
            switch self {
            case .largeTitle, .title1, .title2, .title3, .headline: return Colors.primary
            case .subheadline, .body, .callout: return Colors.primary
            case .footnote, .caption1, .caption2: return Colors.secondary
            }
        }
    }
    
    // MARK: - Text Styles
    enum TextStyle {
        case display
        case heading1
        case heading2
        case heading3
        case bodyLarge
        case bodyMedium
        case bodySmall
        case labelLarge
        case labelMedium
        case labelSmall
        
        var typography: Typography {
            switch self {
            case .display: return .largeTitle
            case .heading1: return .title1
            case .heading2: return .title2
            case .heading3: return .title3
            case .bodyLarge: return .body
            case .bodyMedium: return .callout
            case .bodySmall: return .subheadline
            case .labelLarge: return .headline
            case .labelMedium: return .footnote
            case .labelSmall: return .caption1
            }
        }
    }
}