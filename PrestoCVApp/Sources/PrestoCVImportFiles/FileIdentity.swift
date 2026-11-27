import Foundation

/// Which file a path names: its device and its file number, as `lstat` gives them. Two paths name one file when their
/// identities are equal, however each path is written (hard links included).
public struct FileIdentity: Hashable, Sendable {
    public let device: UInt64
    public let file: UInt64

    public init(device: UInt64, file: UInt64) {
        self.device = device
        self.file = file
    }
}
