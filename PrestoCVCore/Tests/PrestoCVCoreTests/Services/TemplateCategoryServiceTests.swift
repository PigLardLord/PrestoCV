import Testing
import Foundation
@testable import PrestoCVCore

@Suite("TemplateCategoryService Tests")
struct TemplateCategoryServiceTests {
    
    // MARK: - Initialization Tests
    
    @Test("TemplateCategoryService initializes correctly")
    func serviceInitialization() {
        let service = TemplateCategoryService()
        #expect(type(of: service) == TemplateCategoryService.self)
    }
    
    // MARK: - Keyword Matching Tests
    
    @Test("MatchTemplateCategory returns true for matching keywords")
    func matchTemplateCategoryReturnsTrueForMatches() {
        let service = TemplateCategoryService()
        
        // Test various matching cases
        #expect(service.matchTemplateCategory(for: "technical_cv", to: "technical"))
        #expect(service.matchTemplateCategory(for: "developer_resume", to: "technical"))
        #expect(service.matchTemplateCategory(for: "software_engineer_cv", to: "technical"))
        
        #expect(service.matchTemplateCategory(for: "creative_cv", to: "creative"))
        #expect(service.matchTemplateCategory(for: "ux_designer_resume", to: "creative"))
        
        #expect(service.matchTemplateCategory(for: "business_manager_cv", to: "business"))
    }
    
    @Test("MatchTemplateCategory returns false for non-matching keywords")
    func matchTemplateCategoryReturnsFalseForNonMatches() {
        let service = TemplateCategoryService()
        
        #expect(!service.matchTemplateCategory(for: "creative_cv", to: "technical"))
        #expect(!service.matchTemplateCategory(for: "business_cv", to: "creative"))
        #expect(!service.matchTemplateCategory(for: "technical_resume", to: "business"))
    }
    
    @Test("MatchTemplateCategory is case-insensitive")
    func matchTemplateCategoryIsCaseInsensitive() {
        let service = TemplateCategoryService()
        
        #expect(service.matchTemplateCategory(for: "TECHNICAL_CV", to: "technical"))
        #expect(service.matchTemplateCategory(for: "Creative_Resume", to: "creative"))
        #expect(service.matchTemplateCategory(for: "Business_Manager", to: "business"))
    }
    
    // MARK: - Keyword Retrieval Tests
    
    @Test("GetCategoryKeywords returns non-empty dictionary")
    func getCategoryKeywordsReturnsNonEmptyDictionary() {
        let service = TemplateCategoryService()
        let keywords = service.getCategoryKeywords()
        
        #expect(!keywords.isEmpty)
        #expect(keywords["technical"] != nil)
        #expect(keywords["creative"] != nil)
    }
    
    // MARK: - Edge Cases
    
    @Test("MatchTemplateCategory handles empty and invalid inputs")
    func matchTemplateCategoryHandlesInvalidInputs() {
        let service = TemplateCategoryService()
        
        #expect(!service.matchTemplateCategory(for: "", to: "technical"))
        #expect(!service.matchTemplateCategory(for: "technical_cv", to: ""))
        #expect(!service.matchTemplateCategory(for: "technical_cv", to: "unknown_category"))
    }
    
    // MARK: - Additional Edge Case Tests
    
    @Test("MatchTemplateCategory handles special characters and symbols")
    func matchTemplateCategoryHandlesSpecialCharacters() {
        let service = TemplateCategoryService()
        
        // Test with underscores, hyphens, numbers
        #expect(service.matchTemplateCategory(for: "technical-cv-2024", to: "technical"))
        #expect(service.matchTemplateCategory(for: "creative_resume_v2", to: "creative"))
        #expect(service.matchTemplateCategory(for: "business-manager-123", to: "business"))
        
        // Test with special characters that shouldn't match
        #expect(!service.matchTemplateCategory(for: "!@#$%^&*()", to: "technical"))
        #expect(!service.matchTemplateCategory(for: "random_symbols_#*&", to: "creative"))
    }
    
    @Test("MatchTemplateCategory handles very long strings")
    func matchTemplateCategoryHandlesLongStrings() {
        let service = TemplateCategoryService()
        
        let longTemplateName = "very_long_template_name_with_technical_keywords_repeated_multiple_times_" + String(repeating: "technical_", count: 50)
        #expect(service.matchTemplateCategory(for: longTemplateName, to: "technical"))
        
        let longCategoryName = String(repeating: "a", count: 1000)
        #expect(!service.matchTemplateCategory(for: "technical_cv", to: longCategoryName))
    }
    
    @Test("MatchTemplateCategory handles whitespace")
    func matchTemplateCategoryHandlesWhitespace() {
        let service = TemplateCategoryService()
        
        // Test with leading/trailing spaces - should still match because it contains "technical"
        #expect(service.matchTemplateCategory(for: " technical_cv ", to: "technical"))
        #expect(!service.matchTemplateCategory(for: "technical_cv", to: " technical ")) // Invalid category key
        
        // Test with internal spaces - should match because it contains "technical"
        #expect(service.matchTemplateCategory(for: "technical cv", to: "technical"))
        #expect(service.matchTemplateCategory(for: "technical_cv_with_spaces", to: "technical"))
    }
    
    @Test("MatchTemplateCategory handles mixed case scenarios")
    func matchTemplateCategoryHandlesMixedCase() {
        let service = TemplateCategoryService()
        
        #expect(service.matchTemplateCategory(for: "TeChnIcaL_Cv", to: "technical"))
        #expect(service.matchTemplateCategory(for: "CREATIVE_RESUME", to: "creative")) // Category key must be exact
        #expect(service.matchTemplateCategory(for: "business_MANAGER", to: "business")) // Category key must be exact
    }
    
    @Test("MatchTemplateCategory handles partial matches correctly")
    func matchTemplateCategoryHandlesPartialMatches() {
        let service = TemplateCategoryService()
        
        // Should not match partial words
        #expect(!service.matchTemplateCategory(for: "tech_cv", to: "technical")) // "tech" is not "technical"
        #expect(!service.matchTemplateCategory(for: "create_resume", to: "creative")) // "create" is not "creative"
        
        // Should match when keyword is contained
        #expect(service.matchTemplateCategory(for: "technical_specialist_cv", to: "technical"))
    }
    
    @Test("GetCategoryKeywords contains expected categories")
    func getCategoryKeywordsContainsExpectedCategories() {
        let service = TemplateCategoryService()
        let keywords = service.getCategoryKeywords()
        
        // Verify basic categories exist
        #expect(keywords["technical"] != nil)
        #expect(keywords["creative"] != nil)
        
        // Verify keywords are arrays and not empty
        if let technicalKeywords = keywords["technical"] {
            #expect(!technicalKeywords.isEmpty)
            #expect(technicalKeywords.contains { $0.lowercased().contains("technical") || $0.lowercased().contains("developer") || $0.lowercased().contains("engineer") })
        }
        
        if let creativeKeywords = keywords["creative"] {
            #expect(!creativeKeywords.isEmpty)
            #expect(creativeKeywords.contains { $0.lowercased().contains("creative") || $0.lowercased().contains("design") || $0.lowercased().contains("art") })
        }
    }
    
    @Test("MatchTemplateCategory handles Unicode characters")
    func matchTemplateCategoryHandlesUnicode() {
        let service = TemplateCategoryService()
        
        // Test with accented characters - these don't contain exact "technical" or "creative" keywords
        #expect(!service.matchTemplateCategory(for: "téchnical_cv", to: "technical"))
        #expect(!service.matchTemplateCategory(for: "creätiive_resume", to: "creative"))
        
        // Test with other Unicode characters - these DO contain "technical" and "creative"
        #expect(service.matchTemplateCategory(for: "technical_cv_🚀", to: "technical"))
        #expect(service.matchTemplateCategory(for: "creative_résumé", to: "creative"))
    }
}