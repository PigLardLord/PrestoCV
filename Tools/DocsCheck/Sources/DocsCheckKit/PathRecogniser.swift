/// A path a document names in a code span: relative to the repository root, without a trailing slash.
struct NamedPath: Hashable {
    let path: String
    /// The document wrote a trailing slash, so only a directory satisfies it.
    let mustBeDirectory: Bool
}

/// Finds the repository paths a code span names. A word is a path when it is made of path characters only and either
/// - its first segment is a top-level entry of the repository, or
/// - it has a `/` and ends in a file extension of `fileExtensions`, whatever its first segment, so that a document
///   that names a file in a directory that was renamed or deleted is found.
/// So placeholders, globs, ellipses, URLs, expressions and paths under `~` or `/` are never taken for one, and
/// neither is the name of a host (`example.com/index.html`) or any other name that is not at the top of the repository.
/// A path through a `.build` directory names a build product, which is not part of the repository, so it is skipped.
enum PathRecogniser {
    /// The file extensions, in lower case, that make a word with a `/` a path whatever its first segment.
    static let fileExtensions: [String] = ["swift", "md", "json", "mjs", "js", "sh", "yml", "yaml", "css", "html", "txt", "csv"]

    static func paths(inCodeSpan span: String, topLevel: Set<String>) -> [NamedPath] {
        span.split(whereSeparator: \.isWhitespace).compactMap { namedPath(in: $0, topLevel: topLevel) }
    }

    private static func namedPath(in word: Substring, topLevel: Set<String>) -> NamedPath? {
        var text = word
        if let hash = text.firstIndex(of: "#") { text = text[..<hash] }
        text = strippingLineNumbers(text)
        guard !text.isEmpty, text.allSatisfy(isPathCharacter) else { return nil }
        var segments = text.split(separator: "/", omittingEmptySubsequences: false)
        let mustBeDirectory = segments.count > 1 && segments.last?.isEmpty == true
        if mustBeDirectory { segments.removeLast() }
        guard let first = segments.first, segments.allSatisfy({ !$0.isEmpty && !$0.allSatisfy { $0 == "." } && $0 != ".build" }) else { return nil }
        guard topLevel.contains(String(first)) || (!mustBeDirectory && segments.count > 1 && namesAFile(segments) && !looksLikeAHost(first)) else { return nil }
        return NamedPath(path: segments.joined(separator: "/"), mustBeDirectory: mustBeDirectory)
    }

    /// The last segment ends in one of `fileExtensions`, after a name.
    private static func namesAFile(_ segments: [Substring]) -> Bool {
        guard let last = segments.last, let dot = last.lastIndex(of: "."), dot != last.startIndex else { return false }
        return fileExtensions.contains(String(last[last.index(after: dot)...]))
    }

    /// A first segment such as `example.com`: a name with a dot inside it.
    private static func looksLikeAHost(_ segment: Substring) -> Bool {
        segment.dropFirst().contains(".")
    }

    /// `file.swift:10`, `file.swift:10:3` and `file.swift:10-20` name `file.swift`.
    private static func strippingLineNumbers(_ text: Substring) -> Substring {
        guard let colon = text.firstIndex(of: ":") else { return text }
        let location = text[text.index(after: colon)...]
        guard let first = location.first, first.isASCII, first.isNumber, location.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == ":" || $0 == "-") }) else {
            return text
        }
        return text[..<colon]
    }

    private static func isPathCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || "._-/+@".contains(character)
    }
}
