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
}