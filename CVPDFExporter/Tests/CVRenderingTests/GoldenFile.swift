import Foundation

/// UPDATE_GOLDEN=1 writes the output of a golden test over its committed file in the checkout, next to this file, so
/// that the diff can be reviewed like code (R10). The tests themselves read the golden files through `Bundle.module`:
/// on a simulator the checkout may not be there (R16).
enum GoldenFile {
    static func updateIfRequested(_ name: String, with text: String) throws {
        guard ProcessInfo.processInfo.environment["UPDATE_GOLDEN"] == "1" else { return }
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Golden/\(name)")
        try Data(text.utf8).write(to: file)
    }
}
