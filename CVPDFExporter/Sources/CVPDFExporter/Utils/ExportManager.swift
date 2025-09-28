import Foundation

// MARK: - Export Error

/// Errors that can occur during export/import operations
public enum ExportError: Error {
    case invalidJSON(String)
    case encodingFailed(String)
    case decodingFailed(String)
}

// MARK: - Export Manager

/// Manager for exporting and importing CV documents
/// Sprint 5: Export format support
public final class ExportManager: Sendable {

    private let adapter: JSONResumeAdapter
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init() {
        self.adapter = JSONResumeAdapter()

        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Export Methods

    /// Export CVDocument to JSON string
    public func exportToJSON(
        document: CVDocument,
        prettyPrinted: Bool = true
    ) throws -> String {
        // Convert to JSON Resume format
        let jsonResume = adapter.toJSONResume(from: document)

        // Configure encoder
        let encoder = JSONEncoder()
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        } else {
            encoder.outputFormatting = .sortedKeys
        }

        // Encode to data
        let data: Data
        do {
            data = try encoder.encode(jsonResume)
        } catch {
            throw ExportError.encodingFailed(error.localizedDescription)
        }

        // Convert to string
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw ExportError.encodingFailed("Failed to convert data to string")
        }

        return jsonString
    }

    /// Export CVDocument to JSON data
    public func exportToJSONData(document: CVDocument) throws -> Data {
        // Convert to JSON Resume format
        let jsonResume = adapter.toJSONResume(from: document)

        // Encode to data
        do {
            return try encoder.encode(jsonResume)
        } catch {
            throw ExportError.encodingFailed(error.localizedDescription)
        }
    }

    // MARK: - Import Methods

    /// Import CVDocument from JSON string
    public func importFromJSON(_ jsonString: String) throws -> CVDocument {
        guard let data = jsonString.data(using: .utf8) else {
            throw ExportError.invalidJSON("Failed to convert string to data")
        }

        return try importFromJSONData(data)
    }

    /// Import CVDocument from JSON data
    public func importFromJSONData(_ data: Data) throws -> CVDocument {
        // Decode JSON Resume
        let jsonResume: JSONResume
        do {
            jsonResume = try decoder.decode(JSONResume.self, from: data)
        } catch {
            throw ExportError.decodingFailed(error.localizedDescription)
        }

        // Convert to CVDocument
        return adapter.fromJSONResume(jsonResume)
    }

    // MARK: - File Operations

    /// Save CVDocument to file as JSON
    public func saveToFile(
        document: CVDocument,
        at url: URL
    ) throws {
        let data = try exportToJSONData(document: document)
        try data.write(to: url)
    }

    /// Load CVDocument from JSON file
    public func loadFromFile(at url: URL) throws -> CVDocument {
        let data = try Data(contentsOf: url)
        return try importFromJSONData(data)
    }

    // MARK: - Validation

    /// Validate JSON string is valid JSON Resume format
    public func validateJSON(_ jsonString: String) -> Bool {
        do {
            _ = try importFromJSON(jsonString)
            return true
        } catch {
            return false
        }
    }

    /// Validate JSON data is valid JSON Resume format
    public func validateJSONData(_ data: Data) -> Bool {
        do {
            _ = try importFromJSONData(data)
            return true
        } catch {
            return false
        }
    }
}