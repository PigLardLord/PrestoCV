import Foundation

/// What a CV is called wherever it is named, in a row of the list, in the rename that starts from it, in the question
/// before it is deleted and above its editor: its own name, otherwise the name of its person ("Lena Hartmann"),
/// otherwise the role it is for (an example's, for a CV started from one). Only a CV with none of the three, such as a
/// blank CV with only a summary, is "Untitled CV", in the words of the app (R13).
public enum CVTitle: Hashable, Sendable {
    /// The name the person gave the CV, with Rename
    case name(String)
    /// The full name of the person the CV is about
    case person(String)
    /// The role the CV is for
    case role(String)
    case untitled

    /// White space around each of them does not count.
    /// - Parameters:
    ///   - name: The CV's own name.
    ///   - person: The full name of its person.
    ///   - role: The professional title of its person.
    public init(name: String, person: String, role: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let person = person.trimmingCharacters(in: .whitespacesAndNewlines)
        let role = role.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            self = .name(name)
        } else if !person.isEmpty {
            self = .person(person)
        } else if !role.isEmpty {
            self = .role(role)
        } else {
            self = .untitled
        }
    }

    /// The title in words: the name, the person or the role; for a CV with none, `untitled`, in the words of the app
    public func text(untitled: String) -> String {
        switch self {
        case .name(let text), .person(let text), .role(let text):
            return text
        case .untitled:
            return untitled
        }
    }

    /// What a copy of the CV is called: the title the CV is shown with, followed by `copySuffix`, the words of the app
    /// for a copy, as "Lena Hartmann (Copy)". Copies whose names read alike are numbered by `numbers(for:)`, as any
    /// titles are.
    public func copyName(untitled: String, copySuffix: String) -> String {
        "\(text(untitled: untitled)) \(copySuffix.trimmingCharacters(in: .whitespacesAndNewlines))"
    }

    /// The labels of the rows of a list, so that no two read the same: each CV is called by its title in the words of
    /// the app, and a CV whose title reads like the title of one before it, in the order of their identities, gets the
    /// first number from 2 that gives a label no other row shows. Case, accents and spaces around a title do not make
    /// it different, so an untitled CV and a CV named with the app's words for an untitled one read alike.
    /// - Parameters:
    ///   - titles: The CVs of the list, by identity.
    ///   - untitled: What the app calls a CV with no title, as "Untitled CV".
    ///   - numbered: How the app numbers a title, as "Backend (2)".
    /// - Returns: The label of each identity.
    public static func labels<ID: Hashable & Comparable>(
        for titles: [(id: ID, title: CVTitle)],
        untitled: String,
        numbered: (String, Int) -> String
    ) -> [ID: String] {
        let texts = titles.map { (id: $0.id, text: $0.title.text(untitled: untitled)) }.sorted { $0.id < $1.id }
        // Every title the list shows is taken from the start, so that a number never repeats one further down
        var taken = Set(texts.map { comparable($0.text) })
        var kept: Set<String> = []
        var labels: [ID: String] = [:]
        for entry in texts {
            if kept.insert(comparable(entry.text)).inserted {
                labels[entry.id] = entry.text
                continue
            }
            // At most twice as many labels as rows are taken, so a free number comes before this bound
            var number = 2
            var label = numbered(entry.text, number)
            while taken.contains(comparable(label)), number < 2 * texts.count + 2 {
                number += 1
                label = numbered(entry.text, number)
            }
            taken.insert(comparable(label))
            labels[entry.id] = label
        }
        return labels
    }

    /// A title as it is compared: case, accents and the spaces around it do not count
    private static func comparable(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
