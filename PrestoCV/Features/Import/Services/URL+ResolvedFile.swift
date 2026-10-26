import Foundation

extension URL {
    /// The file this URL names, however the path to it is written: symbolic links resolved (`/var` is `/private/var` on a
    /// device, and a folder may be a link), then `.` and `..` removed. Two URLs name the same file when this is equal: the
    /// one rule for "the same file" in the import, for the file being read and for the container of an opened file's copy.
    var resolvedFileURL: URL {
        resolvingSymlinksInPath().standardizedFileURL
    }
}
