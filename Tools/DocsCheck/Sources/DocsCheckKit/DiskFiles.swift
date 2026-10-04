import Foundation

/// `RepositoryFiles` on the disk, under a root directory.
struct DiskFiles: RepositoryFiles {
    let root: URL

    func names(inDirectory path: String) throws(DocsCheckError) -> [String]? {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: absolutePath(path), isDirectory: &isDirectory), isDirectory.boolValue else {
            if path.isEmpty { throw .unreadableRoot(path: root.path) }
            return nil
        }
        do {
            return try FileManager.default.contentsOfDirectory(atPath: absolutePath(path))
        } catch {
            throw path.isEmpty ? .unreadableRoot(path: root.path) : .unreadableDirectory(path: path)
        }
    }

    // Failing closed is right here: what cannot be told to exist is reported by the check as missing, so a document
    // is never accepted for naming something that could not be seen.
    func kind(atExactPath path: String) -> RepositoryTree.Kind? {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: absolutePath(path), isDirectory: &isDirectory) else { return nil }
        return isDirectory.boolValue ? .directory : .file
    }

    // Failing closed is right here too: a directory that cannot be told to be a link is treated as a plain one, and
    // listing it then fails with `unreadableDirectory` if it cannot be read, so nothing is skipped silently.
    func isSymbolicLink(_ path: String) -> Bool {
        let attributes = try? FileManager.default.attributesOfItem(atPath: absolutePath(path))
        return attributes?[.type] as? FileAttributeType == .typeSymbolicLink
    }

    func text(ofFile path: String) throws(DocsCheckError) -> String {
        do {
            return String(decoding: try Data(contentsOf: URL(fileURLWithPath: absolutePath(path))), as: UTF8.self)
        } catch {
            throw .unreadableFile(path: path)
        }
    }

    private func absolutePath(_ path: String) -> String {
        path.isEmpty ? root.path : root.appendingPathComponent(path).path
    }
}
