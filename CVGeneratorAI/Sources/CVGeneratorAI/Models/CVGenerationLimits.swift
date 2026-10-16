/// Size limits of a generation request.
public enum CVGenerationLimits {
    /// Shortest description worth sending to the model
    public static let minimumDescriptionLength = 10

    /// Longest description the on-device model can take next to the instructions, the schema and its answer
    public static let maximumDescriptionLength = 2000
}
