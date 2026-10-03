/// What the format of the word-list files fixes (`docs/architecture/word-lists.md`).
enum WordListFormat {
    /// The only version of the format this code reads.
    static let version = 1

    /// The largest file read, in bytes. A file is untrusted input, so the size is checked before it is decoded (R8).
    static let maxFileBytes = 1_048_576
}
