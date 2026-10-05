import Foundation

/// A list of interests that is normalised on every way in: each is trimmed, empty ones are dropped, and of two that are
/// equal ignoring case the first stays.
///
/// The rule belongs to the property that holds the list, so a value given to the initialiser of the type and a value
/// set later are held to it alike, and that initialiser only stores.
@propertyWrapper
public struct NormalisedInterests: Hashable, Sendable {
    private var values: [String]

    /// Creates the list from the value the property starts with, normalised.
    ///
    /// - Parameter wrappedValue: The interests, in the order the user chose.
    public init(wrappedValue: [String]) { values = Self.normalise(wrappedValue) }

    /// The interests, trimmed, never empty, and with no two equal ignoring case. What is set is normalised first.
    public var wrappedValue: [String] {
        get { values }
        set { values = Self.normalise(newValue) }
    }

    private static func normalise(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }
}
