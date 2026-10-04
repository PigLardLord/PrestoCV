import Foundation

/// A stored file that the strict decoder of its schema refuses, with the reason: the file is corrupt (R12).
struct FileInvalid: Error, Equatable { let reason: String }

/// The JSON of every stored file: ISO 8601 dates in whole seconds, and sorted keys, so the same value is always written
/// as the same bytes.
enum StoredJSON {
    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }

    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }
}
