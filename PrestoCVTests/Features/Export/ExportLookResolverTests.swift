import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore
@testable import CVPDFExporter
import struct PrestoCVDomain.DesignChoice

/// What the export sheet starts from: the look stored with the CV, with the choice of the old global file for a CV that
/// has none, and a default for each part that is missing or that the app no longer knows.
@Suite("ExportLookResolver")
struct ExportLookResolverTests {

    private let installed = ["professional", "modern", "minimal"]

    private func resolve(
        _ look: CVLook?,
        legacy: ExportPreferences = ExportPreferences(),
        installed: [String]? = nil
    ) -> ExportLook {
        ExportLookResolver.resolve(look: look, legacy: legacy, availableTemplateIds: installed ?? self.installed)
    }

    // MARK: - A CV without a look

    @Test("A CV without a look is shown with the choice the old global file holds")
    func noLookUsesTheLegacyChoice() {
        let legacy = ExportPreferences(templateId: "minimal", colorPalette: .creative, fontScheme: .serif)

        #expect(resolve(nil, legacy: legacy) == ExportLook(templateId: "minimal", colorPalette: .creative, fontScheme: .serif))
    }

    @Test("A CV without a look, and no old choice, is shown with the defaults: the first design, professional, classic")
    func noLookNoLegacyUsesTheDefaults() {
        #expect(resolve(nil) == ExportLook(templateId: "professional", colorPalette: .professional, fontScheme: .classic))
        #expect(resolve(nil, installed: ["modern", "minimal"]).templateId == "modern", "The first design the sheet lists")
    }

    @Test("An old choice with only some of its parts gives the others their defaults")
    func partialLegacyChoice() {
        let legacy = ExportPreferences(templateId: nil, colorPalette: .minimal, fontScheme: nil)

        #expect(resolve(nil, legacy: legacy) == ExportLook(templateId: "professional", colorPalette: .minimal, fontScheme: .classic))
    }

    @Test("An old choice of a design that is no longer installed gives the first design")
    func legacyDesignGone() {
        let legacy = ExportPreferences(templateId: "retired", colorPalette: .modern, fontScheme: .modern)

        #expect(resolve(nil, legacy: legacy) == ExportLook(templateId: "professional", colorPalette: .modern, fontScheme: .modern))
    }

    // MARK: - A CV with a look

    @Test("The look of the CV is what is shown, whatever the old global file holds")
    func storedValuesWinOverLegacy() {
        let legacy = ExportPreferences(templateId: "minimal", colorPalette: .minimal, fontScheme: .classic)
        let look = CVLook(design: "modern", palette: "creative", fonts: "serif")

        #expect(resolve(look, legacy: legacy) == ExportLook(templateId: "modern", colorPalette: .creative, fontScheme: .serif))
    }

    @Test("A look with parts missing gives those parts their defaults, not the old choice")
    func partialLookIsNotMixedWithLegacy() {
        let legacy = ExportPreferences(templateId: "minimal", colorPalette: .creative, fontScheme: .serif)

        #expect(resolve(CVLook(palette: "modern"), legacy: legacy)
                == ExportLook(templateId: "professional", colorPalette: .modern, fontScheme: .classic))
        #expect(resolve(CVLook(), legacy: legacy) == ExportLook(templateId: "professional", colorPalette: .professional, fontScheme: .classic))
    }

    @Test("A design that is not installed gives the first design, and keeps the palette and font")
    func unknownDesign() {
        let look = CVLook(design: "retired-design", palette: "creative", fonts: "serif")

        #expect(resolve(look) == ExportLook(templateId: "professional", colorPalette: .creative, fontScheme: .serif))
    }

    @Test("A palette the app does not know gives professional, and keeps the design and font")
    func unknownPalette() {
        let look = CVLook(design: "minimal", palette: "neon", fonts: "serif")

        #expect(resolve(look) == ExportLook(templateId: "minimal", colorPalette: .professional, fontScheme: .serif))
    }

    @Test("A font the app does not know gives classic, and keeps the design and palette")
    func unknownFont() {
        let look = CVLook(design: "minimal", palette: "creative", fonts: "comic")

        #expect(resolve(look) == ExportLook(templateId: "minimal", colorPalette: .creative, fontScheme: .classic))
    }

    @Test("Ids are told apart by their exact text")
    func idsAreExact() {
        let look = CVLook(design: "Modern", palette: "Creative", fonts: " serif")

        #expect(resolve(look) == ExportLook(templateId: "professional", colorPalette: .professional, fontScheme: .classic))
    }

    @Test("With no design installed there is no design to show, and the palette and font still resolve")
    func noDesignInstalled() {
        let look = CVLook(design: "modern", palette: "creative", fonts: "serif")

        #expect(resolve(look, installed: []) == ExportLook(templateId: nil, colorPalette: .creative, fontScheme: .serif))
        #expect(resolve(nil, installed: []).templateId == nil)
    }

    // MARK: - The look to store

    @Test("The look of a selection is stored as the ids of its design, palette and font")
    func lookToStore() throws {
        let look = ExportLook(templateId: "modern", colorPalette: .creative, fontScheme: .serif)

        let choice = try #require(look.designChoice)

        #expect(choice == DesignChoice(design: "modern", palette: "creative", fonts: "serif"))
        #expect(CVLook(choice) == CVLook(design: "modern", palette: "creative", fonts: "serif"))
    }

    @Test("Without a design there is no look to store")
    func noDesignNoLook() {
        #expect(ExportLook(templateId: nil, colorPalette: .creative, fontScheme: .serif).designChoice == nil)
    }

    @Test("A design whose id a look cannot hold is not stored")
    func idOutsideThePattern() {
        #expect(ExportLook(templateId: "My Design", colorPalette: .creative, fontScheme: .serif).designChoice == nil)
        #expect(ExportLook(templateId: "", colorPalette: .creative, fontScheme: .serif).designChoice == nil)
    }

    @Test("What is stored is what is shown again: every design, palette and font comes back as it was")
    func storedLookResolvesToItself() throws {
        for design in installed {
            for palette in ColorPalette.allCases {
                for font in FontScheme.allCases {
                    let shown = ExportLook(templateId: design, colorPalette: palette, fontScheme: font)

                    let stored = CVLook(try #require(shown.designChoice))

                    #expect(resolve(stored) == shown)
                }
            }
        }
    }

    // MARK: - The ids of the new CV domain

    @Test("A look the sheet stores is always a valid design choice of the new domain, and the ids are copied as they are")
    func storedLooksAreValidDesignChoices() throws {
        for design in installed {
            for palette in ColorPalette.allCases {
                for font in FontScheme.allCases {
                    let stored = CVLook(try #require(ExportLook(templateId: design, colorPalette: palette, fontScheme: font).designChoice))

                    let choice = try #require(DesignChoice(design: stored.design ?? "", palette: stored.palette, fonts: stored.fonts))

                    #expect(choice.design == design && choice.palette == palette.rawValue && choice.fonts == font.rawValue)
                }
            }
        }
    }

    @Test("A look that the pattern of a design choice refuses is dropped, never stored half way")
    func looksOutsideThePatternAreRefused() {
        #expect(DesignChoice(design: "Modern", palette: "creative", fonts: "serif") == nil)
        #expect(DesignChoice(design: "modern", palette: "Creative", fonts: "serif") == nil)
        #expect(DesignChoice(design: "modern", palette: "creative", fonts: "x y") == nil)
        #expect(DesignChoice(design: String(repeating: "a", count: 65)) == nil)
    }

    // MARK: - The standard look

    @Test("The standard look of a new CV is what the sheet shows for a CV without one: the first design, professional, classic")
    func standardLookIsTheDefault() throws {
        let standard = resolve(CVLook.standard)

        #expect(standard == resolve(nil))
        #expect(standard == ExportLook(templateId: "professional", colorPalette: .professional, fontScheme: .classic))
        #expect(CVLook(try #require(standard.designChoice)) == CVLook.standard)
    }

    @Test("The designs the app ships are the ones the ids name: professional first, then modern and minimal")
    func bundledDesignIds() async throws {
        let environment = try await ExportTestEnvironment.make()
        defer { environment.cleanUp() }

        let ids = try await environment.makeService().availableTemplates().map(\.id)

        #expect(ids == installed, "A stored look names its design by id, so a shipped design keeps its id")
        #expect(ids.first == CVLook.standard.design)
    }
}
