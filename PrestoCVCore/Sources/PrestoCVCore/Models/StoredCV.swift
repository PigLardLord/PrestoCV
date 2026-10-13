import Foundation

/// A CV as it is kept in its file: the CV itself, flat in the JSON, plus the times the repository stamped on it.
///
/// `CVModel` makes up an identifier when the JSON has none, so a file without one would get a new identity on
/// every read and could never be opened or deleted again. A stored CV must carry its `id`. The times are optional,
/// so files written before they existed still load.
struct StoredCV: Codable, Sendable, Equatable, StorageIdentified {
    var cv: CVModel
    /// In whole seconds: the file keeps ISO 8601 without fractions.
    var createdAt: Date?
    var updatedAt: Date?
    
    /// The file name a CV is stored under. Reading, writing and deleting all derive it from the id.
    static func identifier(for id: UUID) -> String {
        return "cv_\(id.uuidString)"
    }

    var storageIdentifier: String {
        return Self.identifier(for: cv.id)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case createdAt
        case updatedAt
    }
    
    init(cv: CVModel, createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.cv = cv
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        _ = try container.decode(UUID.self, forKey: .id)
        self.cv = try CVModel(from: decoder)
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
    
    func encode(to encoder: Encoder) throws {
        try cv.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}

// MARK: - List Order

extension StoredCV {
    /// The order of the CV list: the most recently changed first, then the CVs without a time. Ties go by name
    /// and then by id, so the order never depends on the order in which the files were read.
    static func isListedBefore(_ lhs: StoredCV, _ rhs: StoredCV) -> Bool {
        switch (lhs.updatedAt, rhs.updatedAt) {
        case let (left?, right?) where left != right:
            return left > right
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        default:
            break
        }
        
        let byName = lhs.cv.name.localizedCaseInsensitiveCompare(rhs.cv.name)
        if byName != .orderedSame {
            return byName == .orderedAscending
        }
        return lhs.cv.id.uuidString < rhs.cv.id.uuidString
    }
}
