import Foundation

/// The paths that documents name before the code exists, each with the open ticket that creates it. They are read
/// from a JSON list of `{"path": …, "ticket": …}` objects.
struct PlannedPaths {
    struct Entry {
        let path: String
        let ticket: Int
        let line: Int
    }

    struct Problem {
        let line: Int
        let message: String
    }

    private(set) var entries: [Entry] = []
    private(set) var problems: [Problem] = []

    static let none = PlannedPaths()

    private init() {}

    private struct RawEntry: Decodable {
        let path: String
        let ticket: Int
    }

    init(json: String) {
        let raw: [RawEntry]
        do {
            raw = try JSONDecoder().decode([RawEntry].self, from: Data(json.utf8))
        } catch {
            problems.append(Problem(line: 1, message: "it is not a list of objects with a string `path` and an integer `ticket`"))
            return
        }
        let lines = json.components(separatedBy: "\n")
        for entry in raw {
            let line = (lines.firstIndex { $0.contains("\"\(entry.path)\"") } ?? 0) + 1
            if let reason = Self.reasonInvalid(entry) {
                problems.append(Problem(line: line, message: "the entry for `\(entry.path)` \(reason)"))
            } else {
                entries.append(Entry(path: Self.normalised(entry.path), ticket: entry.ticket, line: line))
            }
        }
    }

    func declares(_ path: String) -> Bool {
        entries.contains { $0.path == path }
    }

    private static func normalised(_ path: String) -> String {
        path.hasSuffix("/") ? String(path.dropLast()) : path
    }

    private static func reasonInvalid(_ entry: RawEntry) -> String? {
        let segments = normalised(entry.path).split(separator: "/", omittingEmptySubsequences: false)
        if entry.ticket < 1 { return "needs the number of the open ticket that creates it" }
        if segments.contains(where: { $0.isEmpty || $0.allSatisfy { $0 == "." } }) || entry.path.hasPrefix("/") {
            return "is not a path relative to the repository root"
        }
        if entry.path.contains(where: { "*?<>{}[]…".contains($0) }) { return "has a placeholder or a glob in its path" }
        return nil
    }
}
