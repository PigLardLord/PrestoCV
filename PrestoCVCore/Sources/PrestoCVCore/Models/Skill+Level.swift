extension Skill {
    /// The most stars a skill is rated with. A skill with no stars is not rated.
    public static let maxLevel = 5

    /// Rates the skill with the star the person tapped, counted from one. Tapping the star of its rating again takes
    /// the rating away.
    public mutating func chooseLevel(_ star: Int) {
        level = star == level ? 0 : star
    }
}
