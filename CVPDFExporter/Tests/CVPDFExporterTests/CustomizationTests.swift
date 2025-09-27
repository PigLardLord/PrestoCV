import Testing
import Foundation
@testable import CVPDFExporter

// MARK: - Customization Tests (Sprint 2)

@Suite("Customization Options")
struct CustomizationTests {

    // MARK: - Color Palette Tests

    @Test("Color palette enum has all required cases")
    func colorPaletteEnum() {
        let palettes = ColorPalette.allCases

        #expect(palettes.count == 4)
        #expect(palettes.contains(.professional))
        #expect(palettes.contains(.modern))
        #expect(palettes.contains(.minimal))
        #expect(palettes.contains(.creative))
    }

    @Test("Professional color palette values")
    func professionalColorPalette() {
        let palette = ColorPalette.professional
        let colors = palette.colors

        #expect(colors.primary == "#2C3E50")
        #expect(colors.secondary == "#34495E")
        #expect(colors.accent == "#3498DB")
        #expect(colors.background == "#FFFFFF")
        #expect(colors.text == "#2C3E50")
    }

    @Test("Modern color palette values")
    func modernColorPalette() {
        let palette = ColorPalette.modern
        let colors = palette.colors

        #expect(colors.primary == "#1E293B")
        #expect(colors.secondary == "#475569")
        #expect(colors.accent == "#0EA5E9")
        #expect(colors.background == "#F8FAFC")
        #expect(colors.text == "#0F172A")
    }

    @Test("Minimal color palette values")
    func minimalColorPalette() {
        let palette = ColorPalette.minimal
        let colors = palette.colors

        #expect(colors.primary == "#000000")
        #expect(colors.secondary == "#4A4A4A")
        #expect(colors.accent == "#000000")
        #expect(colors.background == "#FFFFFF")
        #expect(colors.text == "#000000")
    }

    @Test("Creative color palette values")
    func creativeColorPalette() {
        let palette = ColorPalette.creative
        let colors = palette.colors

        #expect(colors.primary == "#6B46C1")
        #expect(colors.secondary == "#9333EA")
        #expect(colors.accent == "#F97316")
        #expect(colors.background == "#FEF3C7")
        #expect(colors.text == "#1F2937")
    }

    // MARK: - Font Scheme Tests

    @Test("Font scheme enum has all required cases")
    func fontSchemeEnum() {
        let schemes = FontScheme.allCases

        #expect(schemes.count == 3)
        #expect(schemes.contains(.classic))
        #expect(schemes.contains(.modern))
        #expect(schemes.contains(.serif))
    }

    @Test("Classic font scheme values")
    func classicFontScheme() {
        let scheme = FontScheme.classic
        let fonts = scheme.fonts

        #expect(fonts.heading.contains("Helvetica"))
        #expect(fonts.body.contains("Helvetica"))
        #expect(fonts.size == "11pt")
    }

    @Test("Modern font scheme values")
    func modernFontScheme() {
        let scheme = FontScheme.modern
        let fonts = scheme.fonts

        #expect(fonts.heading.contains("SF Pro Rounded"))
        #expect(fonts.body.contains("SF Pro Text"))
        #expect(fonts.size == "10.5pt")
    }

    @Test("Serif font scheme values")
    func serifFontScheme() {
        let scheme = FontScheme.serif
        let fonts = scheme.fonts

        #expect(fonts.heading.contains("Georgia"))
        #expect(fonts.body.contains("Georgia"))
        #expect(fonts.size == "12pt")
    }

    // MARK: - Customization Options Tests

    @Test("Customization options initialization")
    func customizationOptionsInit() {
        let options = CustomizationOptions(
            colorPalette: .modern,
            fontScheme: .serif
        )

        #expect(options.colorPalette == .modern)
        #expect(options.fontScheme == .serif)
    }

    @Test("Customization options default values")
    func customizationOptionsDefaults() {
        let options = CustomizationOptions()

        #expect(options.colorPalette == .professional)
        #expect(options.fontScheme == .classic)
    }

    @Test("Export options with customization")
    func exportOptionsWithCustomization() {
        let customization = CustomizationOptions(
            colorPalette: .creative,
            fontScheme: .modern
        )

        let options = ExportOptions(
            pageSize: .a4,
            margins: .default,
            templateId: "modern",
            customization: customization
        )

        #expect(options.customization.colorPalette == .creative)
        #expect(options.customization.fontScheme == .modern)
    }

    // MARK: - Template Customization Tests

    @Test("Template applies color palette")
    func templateAppliesColorPalette() async throws {
        // Given
        let template = Template(
            id: "test",
            name: "Test",
            description: "",
            htmlContent: """
            <style>
                :root {
                    --color-primary: {{colorPrimary}};
                    --color-secondary: {{colorSecondary}};
                    --color-accent: {{colorAccent}};
                    --color-background: {{colorBackground}};
                    --color-text: {{colorText}};
                }
            </style>
            <h1>{{name}}</h1>
            """,
            supportedVariables: ["name", "colorPrimary", "colorSecondary", "colorAccent", "colorBackground", "colorText"]
        )

        let document = CVDocument(
            personalInfo: PersonalInfo(name: "Test User", email: "test@example.com"),
            sections: [],
            metadata: DocumentMetadata()
        )

        let customization = CustomizationOptions(colorPalette: .modern)
        let engine = MustacheTemplateEngine()

        // When
        let rendered = try await engine.render(
            template: template,
            data: document,
            customization: customization
        )

        // Then
        #expect(rendered.contains("#1E293B")) // Modern primary color
        #expect(rendered.contains("#475569")) // Modern secondary color
    }

    @Test("Template applies font scheme")
    func templateAppliesFontScheme() async throws {
        // Given
        let template = Template(
            id: "test",
            name: "Test",
            description: "",
            htmlContent: """
            <style>
                body {
                    font-family: {{fontBody}};
                    font-size: {{fontSize}};
                }
                h1, h2, h3 {
                    font-family: {{fontHeading}};
                }
            </style>
            <h1>{{name}}</h1>
            """,
            supportedVariables: ["name", "fontHeading", "fontBody", "fontSize"]
        )

        let document = CVDocument(
            personalInfo: PersonalInfo(name: "Test User", email: "test@example.com"),
            sections: [],
            metadata: DocumentMetadata()
        )

        let customization = CustomizationOptions(fontScheme: .serif)
        let engine = MustacheTemplateEngine()

        // When
        let rendered = try await engine.render(
            template: template,
            data: document,
            customization: customization
        )

        // Then
        #expect(rendered.contains("Georgia"))
        #expect(rendered.contains("12pt"))
    }

    // MARK: - Page Limit Tests

    @Test("Page limit configuration")
    func pageLimitConfiguration() {
        let options = ExportOptions(
            pageSize: .a4,
            margins: .default,
            maxPages: 4
        )

        #expect(options.maxPages == 4)
    }

    @Test("Default page limit is 4")
    func defaultPageLimit() {
        let options = ExportOptions.default

        #expect(options.maxPages == 4)
    }
}