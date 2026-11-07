import PrestoCVWorkflowPorts

/// One choice of the picker: the id a CV keeps, and the code of its name, which the view words (R13).
public struct LookChoice: Hashable, Sendable {
    public let id: String
    public let nameCode: String
}

/// The designs, palettes and font schemes the picker shows.
public struct LookChoices: Hashable, Sendable {
    public let designs: [LookChoice]
    public let palettes: [LookChoice]
    public let fontSchemes: [LookChoice]

    init(_ options: LookOptions) {
        designs = options.designs.map(LookChoice.init)
        palettes = options.palettes.map(LookChoice.init)
        fontSchemes = options.fontSchemes.map(LookChoice.init)
    }
}

extension LookChoice {
    init(_ option: LookOption) { self.init(id: option.id, nameCode: option.nameCode) }
}
