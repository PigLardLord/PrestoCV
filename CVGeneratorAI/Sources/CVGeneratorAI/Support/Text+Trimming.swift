import Foundation

extension String {
    /// The text without surrounding whitespace, or nil when nothing is left
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension Optional where Wrapped == String {
    /// The text without surrounding whitespace, or nil when it is missing or blank
    var trimmedNonEmpty: String? {
        self?.trimmedNonEmpty
    }
}

extension Optional where Wrapped == String {
    /// The text without surrounding whitespace, or nil when it is missing, blank or the word "null": the on-device
    /// model sometimes writes the word itself instead of leaving a field empty.
    var presentValue: String? {
        guard let value = self.trimmedNonEmpty, value.lowercased() != "null" else { return nil }
        return value
    }
}

extension String {
    /// See `Optional<String>.presentValue`.
    var presentValue: String? {
        Optional(self).presentValue
    }
}
