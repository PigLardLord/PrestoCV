import Foundation

/// "Has enough content to be saved", the one definition (R6). A CV can be saved once a detail of its person is written,
/// or one of its sections has an entry, even one the person has only just added. The CV's own title, which only names it
/// in the list, does not count.
///
/// It reads plain values, so that a CV kept in another shape, such as the app's stored CVs before the migration, is
/// judged by the same rule.
public enum SaveRule {
    /// - Parameters:
    ///   - personalDetails: The text of each detail of the person. White space does not count.
    ///   - sectionSizes: How many entries each section has.
    public static func allowsSaving(personalDetails: [String], sectionSizes: [Int]) -> Bool {
        personalDetails.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } || sectionSizes.contains { $0 > 0 }
    }
}
