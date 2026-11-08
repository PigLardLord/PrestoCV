/// What the look picker offers, as app values: ids and the codes the view words (R13). The design catalog is the real
/// source (step 3-4); a view model only reads what it is given.
public protocol LookOptionsProviding: Sendable {
    func options() -> LookOptions
}

/// One choice of a picker: the id a CV keeps and the code of its name, which the view words.
public struct LookOption: Hashable, Sendable {
    public let id: String
    public let nameCode: String

    public init(id: String, nameCode: String) {
        self.id = id
        self.nameCode = nameCode
    }
}

/// The designs, palettes and font schemes a picker shows, and the look it shows for a CV that keeps none.
public struct LookOptions: Hashable, Sendable {
    public let designs: [LookOption]
    public let palettes: [LookOption]
    public let fontSchemes: [LookOption]
    public let defaultDesign: String
    public let defaultPalette: String?
    public let defaultFonts: String?

    public init(
        designs: [LookOption], palettes: [LookOption], fontSchemes: [LookOption],
        defaultDesign: String, defaultPalette: String?, defaultFonts: String?
    ) {
        self.designs = designs
        self.palettes = palettes
        self.fontSchemes = fontSchemes
        self.defaultDesign = defaultDesign
        self.defaultPalette = defaultPalette
        self.defaultFonts = defaultFonts
    }
}
