import Foundation

/// What a CV is called wherever it is named, in a row of the list, in the rename that starts from it, in the question
/// before it is deleted and above its editor: its own name, otherwise the role it is for (an example's, for a CV started
/// from one), otherwise "Untitled CV", in the words of the app (R13).
public enum CVTitle: Hashable, Sendable {
    case name(String)
    case role(String)
    case untitled

    /// - Parameters:
    ///   - name: The CV's own name. White space around it does not count.
    ///   - role: The professional title of its person.
    public init(name: String, role: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let role = role.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            self = .name(name)
        } else if !role.isEmpty {
            self = .role(role)
        } else {
            self = .untitled
        }
    }

    /// The numbers that tell apart CVs whose titles read alike, so that no two rows of a list read the same: the first
    /// of them, in the order of their identities, keeps its title, and the next ones are numbered from 2. Case, accents
    /// and spaces around a title do not make it different. CVs whose title is unique have no number.
    public static func numbers<ID: Hashable & Comparable>(for titles: [(id: ID, title: CVTitle)]) -> [ID: Int] {
        var numbers: [ID: Int] = [:]
        for group in Dictionary(grouping: titles, by: { $0.title.comparable }).values where group.count > 1 {
            for (index, entry) in group.sorted(by: { $0.id < $1.id }).enumerated().dropFirst() {
                numbers[entry.id] = index + 1
            }
        }
        return numbers
    }

    /// The title as it is compared: untitled CVs all read alike
    private var comparable: String? {
        switch self {
        case .name(let text), .role(let text):
            return text.trimmingCharacters(in: .whitespacesAndNewlines).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        case .untitled:
            return nil
        }
    }
}
