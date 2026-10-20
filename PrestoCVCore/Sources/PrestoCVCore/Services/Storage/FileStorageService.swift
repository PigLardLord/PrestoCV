import Foundation
import os

// MARK: - Cross-Platform Storage Service

/// Stores each object as a JSON file in one directory. The actor serialises the operations, so exactly one instance
/// may own a directory; the dependency container creates it.
public actor FileStorageService: StorageServiceProtocol{
    /// Every file is written atomically, so a crash or a full disk leaves the previous file intact, and is
    /// encrypted until the first unlock after boot, so the app can still read it in the background.
    static let writeOptions: Data.WritingOptions = [.atomic, .completeFileProtectionUntilFirstUserAuthentication]

    /// The directory gets the same protection class as the files written into it.
    static var directoryAttributes: [FileAttributeKey: Any] {
        [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
    }

    static let quarantineDirectoryName = "Quarantine"

    /// Where the quarantined files go once the user has been told about them.
    static let acknowledgedDirectoryName = "acknowledged"

    private let fileManager: FileManager
    private let baseDirectory: URL
    private let fileExtension = "json"
    private let logger = Logger(subsystem: "com.PigLardLord.prestocv", category: "storage")

    public init(fileManager: FileManager, baseDirectory: URL) throws {
        self.fileManager = fileManager
        self.baseDirectory = baseDirectory

        // Create directory synchronously since init must be synchronous
        // and this is a one-time setup operation
        guard !fileManager.fileExists(atPath: baseDirectory.path) else { return }
        try fileManager.createDirectory(
            at: baseDirectory,
            withIntermediateDirectories: true,
            attributes: Self.directoryAttributes
        )
    }

    // MARK: - Public Methods

    public func save<T: Codable & Sendable>(_ object: T, to identifier: String) async throws {
        try write(object, to: identifier)
    }

    public func save<T: Codable & Sendable>(to identifier: String, updating transform: @Sendable (T?) -> T) async throws {
        // A file that cannot be read has no object to keep: the save replaces it. Nothing suspends between the
        // read and the write, so no other operation on this actor runs in between.
        let stored = try? decodeFile(at: fileURL(for: identifier), as: T.self)
        try write(transform(stored), to: identifier)
    }

    public func load<T: Codable & Sendable>(_ type: T.Type, from identifier: String) async throws -> T? {
        return try loadFile(type, from: identifier)
    }

    public func loadIdentified<T: Codable & Sendable & StorageIdentified>(_ type: T.Type, from identifier: String) async throws -> T? {
        guard let object = try loadFile(type, from: identifier) else {
            return nil
        }
        guard object.storageIdentifier == identifier else {
            _ = renameIfFree(fileURL(for: identifier), to: object.storageIdentifier)
            return nil
        }
        return object
    }

    public func loadAll<T: Codable & Sendable>(_ type: T.Type) async throws -> [T] {
        return try loadFiles(type, identifierOf: nil).objects
    }

    public func loadAllReporting<T: Codable & Sendable & StorageIdentified>(_ type: T.Type) async throws -> StorageLoadReport<T> {
        let result = try loadFiles(type, identifierOf: { $0.storageIdentifier })
        // The files set aside are counted from the quarantine, not from this call: whichever load set them aside,
        // they are reported until they are acknowledged.
        return StorageLoadReport(items: result.objects, unreadableCount: result.leftInPlaceCount + pendingQuarantineCount())
    }

    public func acknowledgeQuarantined() async throws {
        do {
            let pending = try pendingQuarantineURLs()
            guard !pending.isEmpty else {
                return
            }

            let acknowledged = quarantineDirectory.appendingPathComponent(Self.acknowledgedDirectoryName, isDirectory: true)
            try fileManager.createDirectory(
                at: acknowledged,
                withIntermediateDirectories: true,
                attributes: Self.directoryAttributes
            )
            for url in pending {
                try fileManager.moveItem(at: url, to: availableURL(for: url.lastPathComponent, in: acknowledged))
            }
        } catch {
            throw AppError.fileSystemError(error.localizedDescription)
        }
    }

    /// Deleting is idempotent: a file that is already gone is not an error.
    public func delete(identifier: String) async throws {
        let url = fileURL(for: identifier)

        guard fileManager.fileExists(atPath: url.path) else {
            return
        }

        do {
            try fileManager.removeItem(at: url)
        } catch {
            throw AppError.fileSystemError(error.localizedDescription)
        }
    }

    public func exists(identifier: String) async -> Bool {
        let url = fileURL(for: identifier)
        return fileManager.fileExists(atPath: url.path)
    }

    public func getAllIdentifiers() async throws -> [String] {
        let urls = try getStoredFileURLs()
        return extractIdentifiersFromURLs(urls)
    }

    // MARK: - Private Methods

    private func write<T: Encodable>(_ object: T, to identifier: String) throws {
        let data: Data
        do {
            data = try configuredJSONEncoder().encode(object)
        } catch {
            throw AppError.encodingError(error.localizedDescription)
        }

        do {
            try data.write(to: fileURL(for: identifier), options: Self.writeOptions)
        } catch {
            throw AppError.fileSystemError(error.localizedDescription)
        }
    }

    private func loadFile<T: Decodable>(_ type: T.Type, from identifier: String) throws -> T? {
        let url = fileURL(for: identifier)

        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        return try decodeFile(at: url, as: type)
    }

    private enum FileReadOutcome<T> {
        case loaded(T)
        case unreadable(String)
        case corrupt(String)
    }

    /// Reads every stored file, in a stable order, and sorts out the ones that cannot be used.
    ///
    /// Corrupt files are set aside first, so that a name they held is free for a file that is named wrongly.
    /// - Parameter identifierOf: The identifier an object must be stored under. A file named otherwise is renamed
    ///   to it when that name is free: one move, so an interruption leaves either the old name or the new one.
    ///   When the name is taken, the file stays where it is, untouched, and is not listed. Nil skips the check.
    /// - Returns: The objects that could be used, and how many files that could not be used are still where they were.
    private func loadFiles<T: Codable & Sendable>(
        _ type: T.Type,
        identifierOf: ((T) -> String)?
    ) throws -> (objects: [T], leftInPlaceCount: Int) {
        let outcomes = try getStoredFileURLs().map { (url: $0, outcome: readFile(at: $0, as: type)) }
        var objects: [T] = []
        var leftInPlaceCount = 0

        for case (let url, .corrupt(let reason)) in outcomes {
            logger.error("Corrupt file \(url.lastPathComponent, privacy: .public): \(reason, privacy: .private)")
            if !quarantine(url) {
                leftInPlaceCount += 1
            }
        }

        for (url, outcome) in outcomes {
            switch outcome {
            case .loaded(let object):
                guard let expected = identifierOf?(object), expected != extractIdentifierFromURL(url) else {
                    objects.append(object)
                    continue
                }
                if renameIfFree(url, to: expected) {
                    objects.append(object)
                } else {
                    leftInPlaceCount += 1
                }
            case .unreadable(let reason):
                // The file may only be locked until the first unlock, so it stays and is read again next time.
                logger.error("Could not read \(url.lastPathComponent, privacy: .public): \(reason, privacy: .private)")
                leftInPlaceCount += 1
            case .corrupt:
                break
            }
        }
        return (objects, leftInPlaceCount)
    }

    /// Reads and decodes one file, telling a file that cannot be opened from one whose content is not valid.
    private func readFile<T: Decodable>(at url: URL, as type: T.Type) -> FileReadOutcome<T> {
        do {
            return .loaded(try decodeFile(at: url, as: type))
        } catch AppError.decodingError(let reason) {
            return .corrupt(reason)
        } catch {
            return .unreadable(error.localizedDescription)
        }
    }

    /// Reads and decodes one file.
    /// - Throws: `AppError.fileSystemError` when the file cannot be read, `AppError.decodingError` when its content is not a valid `T`.
    private func decodeFile<T: Decodable>(at url: URL, as type: T.Type) throws -> T {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw AppError.fileSystemError(error.localizedDescription)
        }

        do {
            return try configuredJSONDecoder().decode(type, from: data)
        } catch {
            throw AppError.decodingError(error.localizedDescription)
        }
    }

    /// Renames a file to the identifier its content belongs under, if no file has that name. Nothing is overwritten.
    /// - Returns: Whether the file was renamed.
    private func renameIfFree(_ url: URL, to identifier: String) -> Bool {
        let destination = fileURL(for: identifier)
        guard !fileManager.fileExists(atPath: destination.path) else {
            logger.error("\(url.lastPathComponent, privacy: .public) holds a CV that belongs under \(destination.lastPathComponent, privacy: .public), which is taken")
            return false
        }

        do {
            try fileManager.moveItem(at: url, to: destination)
            logger.notice("Renamed \(url.lastPathComponent, privacy: .public) to \(destination.lastPathComponent, privacy: .public), the name its content belongs under")
            return true
        } catch {
            logger.error("Could not rename \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .private)")
            return false
        }
    }

    private var quarantineDirectory: URL {
        return baseDirectory.appendingPathComponent(Self.quarantineDirectoryName, isDirectory: true)
    }

    /// The files in the quarantine that nobody has acknowledged yet.
    private func pendingQuarantineURLs() throws -> [URL] {
        guard fileManager.fileExists(atPath: quarantineDirectory.path) else {
            return []
        }
        return try fileManager
            .contentsOfDirectory(at: quarantineDirectory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent != Self.acknowledgedDirectoryName }
    }

    /// How many files wait in the quarantine. A quarantine that cannot be listed must not stop the listing of the CVs.
    private func pendingQuarantineCount() -> Int {
        do {
            return try pendingQuarantineURLs().count
        } catch {
            logger.error("Could not list the quarantine: \(error.localizedDescription, privacy: .private)")
            return 0
        }
    }

    /// Moves a corrupt file out of the way, so it is neither listed again nor lost.
    /// - Returns: Whether the file was moved.
    private func quarantine(_ url: URL) -> Bool {
        let directory = quarantineDirectory
        do {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: Self.directoryAttributes
            )
            try fileManager.moveItem(at: url, to: availableURL(for: url.lastPathComponent, in: directory))
            return true
        } catch {
            logger.error("Could not quarantine \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .private)")
            return false
        }
    }

    /// A file name that is free in the directory: a file with the same name can arrive again.
    private func availableURL(for fileName: String, in directory: URL) -> URL {
        var candidate = directory.appendingPathComponent(fileName)
        var attempt = 1
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(attempt)~\(fileName)")
            attempt += 1
        }
        return candidate
    }

    /// Extracts identifiers from file URLs by removing the file extension
    /// - Parameter urls: Array of file URLs to process
    /// - Returns: Array of identifiers (filenames without extension)
    private func extractIdentifiersFromURLs(_ urls: [URL]) -> [String] {
        return urls.compactMap(extractIdentifierFromURL)
    }

    /// Extracts identifier from a single URL if it matches the expected file extension
    /// - Parameter url: File URL to process
    /// - Returns: Identifier (filename without extension) or nil if invalid
    private func extractIdentifierFromURL(_ url: URL) -> String? {
        let filename = url.lastPathComponent
        let expectedSuffix = ".\(fileExtension)"

        guard filename.hasSuffix(expectedSuffix) else {
            return nil
        }

        return String(filename.dropLast(expectedSuffix.count))
    }

    private func configuredJSONEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private func configuredJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func fileURL(for identifier: String) -> URL {
        return baseDirectory.appendingPathComponent("\(identifier).\(fileExtension)")
    }

    /// The stored files in a stable order. The quarantine is a directory, so it is not among them.
    private func getStoredFileURLs() throws -> [URL] {
        let contents: [URL]
        do {
            contents = try fileManager.contentsOfDirectory(at: baseDirectory, includingPropertiesForKeys: nil)
        } catch {
            throw AppError.fileSystemError(error.localizedDescription)
        }
        return contents
            .filter { $0.pathExtension == fileExtension }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
