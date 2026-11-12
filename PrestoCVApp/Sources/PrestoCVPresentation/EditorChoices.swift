internal import PrestoCVDomain

/// The choices of the editor's menus, as codes the view words: those the domain can store.
public enum EditorChoices {
    /// The levels of a skill, lowest first.
    public static let skillLevels: [Int] = Array(1...5)
    /// How well the person speaks a language, from beginner to native: the codes `a1` to `c2` and `native`.
    public static let proficiencies: [String] = LanguageProficiency.allCases.map(\.rawValue)
}
