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
    }
    
    // MARK: - Corner Radius
    enum CornerRadius {
        static let sm: CGFloat = 4
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
    }
    
    // MARK: - Icon Sizes
    enum IconSize {
        case small
        case medium
        case large
        case hero
        
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
            }
        }
    }
    
    // MARK: - Colors
    enum Colors {
        // Text colors
        static let primary = Color.primary
        static let secondary = Color.secondary
        static let tertiary = Color.gray
        
        // Background colors
        static let background = Color(UIColor.systemBackground)
        static let backgroundSecondary = Color(UIColor.secondarySystemBackground)
        static let backgroundTertiary = Color(UIColor.tertiarySystemBackground)
        
        // Accent colors
        static let accent = Color.blue
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        
        // Shadow
        static let shadow = Color.gray.opacity(0.3)
        
        // Button text colors
        static let primaryButtonText = Color.white
        static let secondaryButtonText = Color.blue
    }
    
    // MARK: - Shadow
    enum Shadow {
        static let radius: CGFloat = 3
        static let x: CGFloat = 0
        static let y: CGFloat = 2
    }
    
    // MARK: - Typography
    enum Typography {
        case title1
        case title2
        case headline
        case subheadline
        case body
        case callout
        case footnote
        case caption1
        case caption2
        
        var font: Font {
            switch self {
            case .title1: return .largeTitle
            case .title2: return .title
            case .headline: return .headline
            case .subheadline: return .subheadline
            case .body: return .body
            case .callout: return .callout
            case .footnote: return .footnote
            case .caption1: return .caption
            case .caption2: return .caption2
            }
        }
    }
}