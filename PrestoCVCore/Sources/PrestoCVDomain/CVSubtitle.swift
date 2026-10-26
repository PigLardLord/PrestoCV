import Foundation

/// The line under the title of a CV in a row of the list: who the CV is about, without what its title (`CVTitle`)
/// already says. A CV titled by its own name shows the name of its person and the role; one titled by its person shows
/// only the role; one titled by its role shows only its person, if it has one.
public enum CVSubtitle {
    /// What separates the name of the person from the role, as in "Lena Hartmann · Pflegefachkraft"
    public static let separator = " · "

    /// - Parameters:
    ///   - name: The CV's own name.
    ///   - person: The full name of its person.
    ///   - role: The professional title of its person.
    /// - Returns: The parts the title does not say, without the white space around them, joined by `separator`; nil
    ///   when none is left. An empty part leaves no separator behind.
    public static func text(name: String, person: String, role: String) -> String? {
        let person = person.trimmingCharacters(in: .whitespacesAndNewlines)
        let role = role.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts: [String]
        switch CVTitle(name: name, person: person, role: role) {
        case .name, .untitled:
            parts = [person, role]
        case .person:
            parts = [role]
        case .role:
            parts = [person]
        }
        let shown = parts.filter { !$0.isEmpty }
        return shown.isEmpty ? nil : shown.joined(separator: separator)
    }
}
