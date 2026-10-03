/// What the format of the word-list files fixes (`docs/architecture/word-lists.md`). The decoder reads its keys from
/// here, so the document and the code are held to one list.
enum WordListFormat {
    /// The only version of the format this code reads.
    static let version = 1

    /// The largest file read, in bytes. A file is untrusted input, so the size is checked before it is decoded (R8).
    static let maxFileBytes = 1_048_576

    /// The groups of a file, in the order of the keys.
    static var groups: [String] {
        var seen = Set<String>()
        return WordListKey.allCases.map(\.group).filter { seen.insert($0).inserted }
    }

    /// The keys at the top of a file: the version and the groups.
    static var rootKeys: [String] { ["version"] + groups }

    /// The keys of a list.
    static let listKeys = ["source", "licence", "entries"]

    /// The keys of the list of streets, which also says where the language writes the word.
    static let streetListKeys = listKeys + ["order"]

    /// The keys of a month name, of a number word, of a group of synonyms and of a word of a form of address.
    static let monthKeys = ["name", "month"]
    static let numberKeys = ["word", "value"]
    static let synonymKeys = ["forms"]
    static let formKeys = ["form", "word"]

    /// The keys of a word that claims a rank.
    static let rankKeys = ["word", "ranks"]
}
