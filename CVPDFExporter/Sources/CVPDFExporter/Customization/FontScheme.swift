import Foundation

// MARK: - Font Scheme

/// Available font schemes for PDF export
public enum FontScheme: String, CaseIterable, Sendable, Codable {
    case classic = "classic"
    case modern = "modern"
    case serif = "serif"

    /// Returns the font values for this scheme
    public var fonts: (heading: String, body: String, size: String) {
        switch self {
        case .classic:
            return (
                heading: "-apple-system, BlinkMacSystemFont, 'Helvetica Neue', Helvetica, Arial, sans-serif",
                body: "-apple-system, BlinkMacSystemFont, 'Helvetica Neue', Helvetica, Arial, sans-serif",
                size: "11pt"
            )
        case .modern:
            return (
                heading: "'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif",
                body: "'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif",
                size: "10pt"
            )
        case .serif:
            return (
                heading: "ui-serif, Georgia, Cambria, 'Times New Roman', Times, serif",
                body: "ui-serif, Georgia, Cambria, 'Times New Roman', Times, serif",
                size: "12pt"
            )
        }
    }

    /// Returns CSS font properties for this scheme
    public func toCSSVariables() -> String {
        let fonts = self.fonts
        return """
        --font-heading: \(fonts.heading);
        --font-body: \(fonts.body);
        --font-size: \(fonts.size);
        """
    }
}