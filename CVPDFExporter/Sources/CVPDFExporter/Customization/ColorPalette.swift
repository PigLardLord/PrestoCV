import Foundation

// MARK: - Color Palette

/// Available color palettes for PDF export
public enum ColorPalette: String, CaseIterable, Sendable {
    case professional = "professional"
    case modern = "modern"
    case minimal = "minimal"
    case creative = "creative"

    /// Returns the color values for this palette
    public var colors: (primary: String, secondary: String, accent: String, background: String, text: String) {
        switch self {
        case .professional:
            return (
                primary: "#2C3E50",      // Dark blue-gray
                secondary: "#34495E",    // Darker blue-gray
                accent: "#3498DB",       // Blue
                background: "#FFFFFF",   // White
                text: "#2C3E50"         // Dark blue-gray
            )
        case .modern:
            return (
                primary: "#1e40af",      // Blue
                secondary: "#6b7280",    // Gray
                accent: "#3b82f6",       // Lighter blue
                background: "#e0e7ff",   // Light blue
                text: "#1f2937"         // Dark gray
            )
        case .minimal:
            return (
                primary: "#000000",      // Black
                secondary: "#4A4A4A",    // Gray
                accent: "#000000",       // Black
                background: "#FFFFFF",   // White
                text: "#000000"         // Black
            )
        case .creative:
            return (
                primary: "#6B46C1",      // Purple
                secondary: "#9333EA",    // Lighter purple
                accent: "#F97316",       // Orange
                background: "#FEF3C7",   // Light yellow
                text: "#1F2937"         // Dark gray
            )
        }
    }

    /// Returns CSS custom properties for this palette
    public func toCSSVariables() -> String {
        let colors = self.colors
        return """
        --color-primary: \(colors.primary);
        --color-secondary: \(colors.secondary);
        --color-accent: \(colors.accent);
        --color-background: \(colors.background);
        --color-text: \(colors.text);
        """
    }
}