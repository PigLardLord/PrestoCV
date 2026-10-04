import Foundation

/// Check 1. Every relative link resolves to a file or a directory of the repository, and an anchor into a Markdown
/// file is one of its headings. Links to other sites are not followed.
struct LinkCheck {
    let tree: RepositoryTree
    private var anchorsByFile: [String: Set<Anchor>] = [:]

    init(tree: RepositoryTree) {
        self.tree = tree
    }

    mutating func findings(in documents: [Document]) throws(DocsCheckError) -> [Finding] {
        var findings: [Finding] = []
        for document in documents {
            anchorsByFile[document.path] = Set(document.markdown.anchors.map(Anchor.init))
            for link in document.markdown.links {
                if let finding = try finding(for: link, in: document) { findings.append(finding) }
            }
        }
        return findings
    }

    private mutating func finding(for link: MarkdownDocument.Link, in document: Document) throws(DocsCheckError) -> Finding? {
        guard let target = LinkTarget(destination: link.destination) else { return nil }
        func report(_ code: FindingCode, _ message: String) -> Finding {
            Finding(file: document.path, line: link.line, code: code, message: message)
        }
        let path: String
        switch target.path {
        case nil:
            path = document.path
        case let relative?:
            guard let resolved = RepositoryPath.resolve(relative, from: document.path) else {
                return report(.linkTargetMissing, "\(Finding.quoted(link.destination)) leaves the repository")
            }
            guard let kind = try tree.kind(of: resolved), kind == .directory || !relative.hasSuffix("/") else {
                return report(.linkTargetMissing, "\(Finding.quoted(link.destination)) does not exist")
            }
            guard kind == .file, resolved.hasSuffix(".md") else { return nil }
            path = resolved
        }
        guard let anchor = target.anchor, !anchor.isEmpty else { return nil }
        guard try anchors(of: path).contains(Anchor(anchor)) else {
            return report(.linkAnchorMissing, "\(Finding.quoted(path)) has no heading with the anchor \(Finding.quoted("#" + anchor))")
        }
        return nil
    }

    private mutating func anchors(of path: String) throws(DocsCheckError) -> Set<Anchor> {
        if let known = anchorsByFile[path] { return known }
        let anchors = Set(MarkdownDocument(text: try tree.text(of: path)).anchors.map(Anchor.init))
        anchorsByFile[path] = anchors
        return anchors
    }
}

/// The parts of a link destination that point into the repository.
struct LinkTarget {
    /// The path as written, without query and fragment, percent-decoded. Nil when the link points into its own file.
    let path: String?
    /// The fragment, percent-decoded.
    let anchor: String?

    /// Nil for a link to another site: any destination that starts with a URL scheme or with `//`.
    init?(destination: String) {
        if destination.hasPrefix("//") || Self.hasScheme(destination) { return nil }
        var rest = Substring(destination)
        var fragment: String?
        if let hash = rest.firstIndex(of: "#") {
            fragment = Self.decode(rest[rest.index(after: hash)...])
            rest = rest[..<hash]
        }
        if let query = rest.firstIndex(of: "?") { rest = rest[..<query] }
        path = rest.isEmpty ? nil : Self.decode(rest)
        anchor = fragment
    }

    private static func hasScheme(_ destination: String) -> Bool {
        guard let colon = destination.firstIndex(of: ":"), let first = destination.first, first.isASCII, first.isLetter else { return false }
        return destination[..<colon].allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || "+.-".contains($0)) }
    }

    private static func decode(_ text: Substring) -> String {
        String(text).removingPercentEncoding ?? String(text)
    }
}

/// Resolution of the paths documents write, against the file that holds them.
enum RepositoryPath {
    /// The repository-relative path that `link` names from `file`, or nil if it leaves the repository. A leading
    /// slash means the repository root, as on GitHub. A trailing slash is dropped; the caller reads it from `link`.
    static func resolve(_ link: String, from file: String) -> String? {
        var components: [Substring] = []
        if !link.hasPrefix("/") {
            components = file.split(separator: "/").dropLast()
        }
        for component in link.split(separator: "/") {
            switch component {
            case ".":
                continue
            case "..":
                guard components.popLast() != nil else { return nil }
            default:
                components.append(component)
            }
        }
        return components.joined(separator: "/")
    }
}
