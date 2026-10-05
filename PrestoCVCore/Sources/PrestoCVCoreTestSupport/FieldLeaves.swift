import Foundation

/// The leaves of a value, walked with Mirror: strings, integers, booleans and enum cases without a payload. A nil is
/// `missing` and an empty collection is `empty`, so a completeness test can require a fixture to populate every field,
/// and the mapper test (CleanTests) can check that each leaf reaches the document.
public enum FieldLeaves {
    /// What an unset optional contributes.
    public static let missing = "<nil>"
    /// What an empty collection contributes.
    public static let empty = "<empty>"

    /// The leaves of `value`, in the order of its fields. Dates and identifiers are not leaves.
    ///
    /// - Parameters:
    ///   - value: The value to walk.
    ///   - skipping: Labels of fields that are not walked, such as the ones a repository sets.
    public static func of(_ value: Any, skipping: Set<String> = []) -> [String] {
        let mirror = Mirror(reflecting: value)
        if let leaves = leavesOfShape(value, mirror, skipping: skipping) { return leaves }
        switch value {
        case let text as String: return [text]
        case let number as Int: return [String(number)]
        case let flag as Bool: return [String(flag)]
        case is Date, is UUID: return []
        default: return mirror.children.filter { !skipping.contains($0.label ?? "") }.flatMap { of($0.value, skipping: skipping) }
        }
    }

    /// The leaves that follow from the shape of `value`: an optional, an empty collection, or an enum case without a payload.
    /// `nil` for any other shape.
    private static func leavesOfShape(_ value: Any, _ mirror: Mirror, skipping: Set<String>) -> [String]? {
        switch mirror.displayStyle {
        case .optional?: return mirror.children.first.map { of($0.value, skipping: skipping) } ?? [missing]
        case .collection?, .set?, .dictionary?: return mirror.children.isEmpty ? [empty] : nil
        case .enum? where mirror.children.isEmpty: return [String(describing: value)]
        default: return nil
        }
    }
}
