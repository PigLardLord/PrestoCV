import Foundation

/// The command behind `swift run --package-path Tools/SourceChecks store-listing-counts [--write] [--root <folder>]`: it prints
/// the counts table of docs/release/store-listing.md, and with `--write` rewrites the table in the document. The checks
/// that hold the table to the texts are in `swift test`.
public enum StoreListingCounts {
    public static let document = "docs/release/store-listing.md"

    /// The exit status: 0 when the table is current or was rewritten, 1 when it is stale and `write` is false, 2 on a usage error.
    public static func run(arguments: [String]) -> Int32 {
        var write = false
        var root = FileManager.default.currentDirectoryPath
        var rest = arguments[...]
        while let argument = rest.popFirst() {
            switch argument {
            case "--write": write = true
            case "--root":
                guard let value = rest.popFirst() else { return usage("--root needs a folder") }
                root = value
            default: return usage("unknown argument '\(argument)'")
            }
        }
        let url = URL(fileURLWithPath: root).appendingPathComponent(document)
        do {
            let lines = try String(contentsOf: url, encoding: .utf8).components(separatedBy: "\n")
            let table = StoreListingRules.countsTable(StoreListingRules.parse(lines))
            print(table.joined(separator: "\n"))
            guard let updated = StoreListingRules.replacingCounts(in: lines, with: table) else {
                return usage("\(document): no \(StoreListingRules.countsStart) … \(StoreListingRules.countsEnd) markers")
            }
            if updated == lines { return 0 }
            guard write else {
                FileHandle.standardError.write(Data("error: the counts table is stale: run with --write\n".utf8))
                return 1
            }
            try updated.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
            print("\nwrote the counts table of \(url.lastPathComponent)")
            return 0
        } catch {
            return usage("\(error)")
        }
    }

    private static func usage(_ message: String) -> Int32 {
        FileHandle.standardError.write(Data("store-listing-counts: \(message)\n".utf8))
        return 2
    }
}
