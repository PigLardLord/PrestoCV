import Foundation

// MARK: - Template Category Service Implementation

public final class TemplateCategoryService: TemplateCategoryServiceProtocol, Sendable {
    
    public init() {}
    
    public func matchTemplateCategory(for fileName: String, to category: String) -> Bool {
        let fileNameLowercased = fileName.lowercased()
        let categoryKeywords = getCategoryKeywords()
        
        // Check if the file name contains keywords for the requested category
        if let keywords = categoryKeywords[category] {
            return keywords.contains { keyword in
                fileNameLowercased.contains(keyword.lowercased())
            }
        }
        
        return false
    }
    
    public func getCategoryKeywords() -> [String: [String]] {
        return [
            "technical": ["technical", "developer", "engineer", "software"],
            "creative": ["creative", "design", "artist", "ux", "ui"],
            "business": ["business", "manager", "executive", "operations"],
            "academic": ["academic", "research", "professor", "scientist"],
            "healthcare": ["healthcare", "medical", "doctor", "nurse"]
        ]
    }
}