import Foundation

// MARK: - Customization Options

/// Options for customizing the appearance of the exported PDF
public struct CustomizationOptions: Sendable {
    public let colorPalette: ColorPalette
    public let fontScheme: FontScheme
    
    public init(
        colorPalette: ColorPalette = .professional,
        fontScheme: FontScheme = .classic
    ) {
        self.colorPalette = colorPalette
        self.fontScheme = fontScheme
    }
}
