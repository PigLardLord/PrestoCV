import Testing
import Foundation
@testable import PrestoCV

// MARK: - PrestoCVCore Adapter Tests

@Suite("PrestoCVCore Adapter")
struct PrestoCVCoreAdapterTests {

    @Test("Adapter initialization")
    func adapterInitialization() {
        let adapter = PrestoCVCoreAdapter()
        #expect(adapter != nil)
    }

    @Test("Sprint 0 returns hardcoded data")
    func sprint0ReturnsHardcodedData() {
        // Sprint 0: Should return sample data
        let adapter = PrestoCVCoreAdapter()
        let document = adapter.convertToCV(from: nil)

        #expect(document.personalInfo.name == "John Doe")
        #expect(document.personalInfo.email == "john.doe@example.com")
    }

    @Test("Convert to CV returns valid document")
    func convertToCVReturnsValidDocument() {
        let adapter = PrestoCVCoreAdapter()
        let document = adapter.convertToCV(from: nil)

        #expect(!document.personalInfo.name.isEmpty)
        #expect(!document.personalInfo.email.isEmpty)
        #expect(document.sections.count > 0)
    }

    @Test("Convert to CV personal info")
    func convertToCVPersonalInfo() {
        let adapter = PrestoCVCoreAdapter()
        let document = adapter.convertToCV(from: nil)
        let personalInfo = document.personalInfo

        #expect(!personalInfo.name.isEmpty)
        #expect(!personalInfo.email.isEmpty)
        #expect(personalInfo.phone != nil)
        #expect(personalInfo.location != nil)
        #expect(personalInfo.website != nil)
        #expect(personalInfo.summary != nil)
    }

    @Test("Convert to CV work section")
    func convertToCVWorkSection() {
        let adapter = PrestoCVCoreAdapter()
        let document = adapter.convertToCV(from: nil)

        let workSections = document.sections.filter { $0.type == .work }
        #expect(!workSections.isEmpty)

        if let workSection = workSections.first {
            #expect(!workSection.items.isEmpty)

            // Check first work item
            if let firstItem = workSection.items.first {
                #expect(!firstItem.title.isEmpty)
                #expect(firstItem.subtitle != nil)
                #expect(firstItem.description != nil)
                #expect(firstItem.startDate != nil)
                #expect(firstItem.endDate != nil)
                #expect(firstItem.location != nil)
            }
        }
    }

    @Test("Convert to CV education section")
    func convertToCVEducationSection() {
        let adapter = PrestoCVCoreAdapter()
        let document = adapter.convertToCV(from: nil)

        let educationSections = document.sections.filter { $0.type == .education }
        #expect(!educationSections.isEmpty)

        if let educationSection = educationSections.first {
            #expect(!educationSection.items.isEmpty)

            // Check education item
            if let firstItem = educationSection.items.first {
                #expect(firstItem.title.contains("Bachelor") || firstItem.title.contains("Master"))
                #expect(firstItem.subtitle != nil)
                #expect(firstItem.startDate != nil)
                #expect(firstItem.endDate != nil)
            }
        }
    }

    @Test("Convert to CV skills section")
    func convertToCVSkillsSection() {
        let adapter = PrestoCVCoreAdapter()
        let document = adapter.convertToCV(from: nil)

        let skillSections = document.sections.filter { $0.type == .skills }
        #expect(!skillSections.isEmpty)

        if let skillSection = skillSections.first {
            #expect(!skillSection.items.isEmpty)

            // Check skill categories
            let categories = skillSection.items.map { $0.title }
            #expect(categories.contains { $0.contains("Languages") || $0.contains("Frameworks") })
            #expect(categories.contains { $0.contains("Tools") || $0.contains("Platforms") })
        }
    }

    @Test("Convert to CV section order")
    func convertToCVSectionOrder() {
        let adapter = PrestoCVCoreAdapter()
        let document = adapter.convertToCV(from: nil)

        // Sections should have defined order
        for section in document.sections {
            #expect(section.order > 0)
        }

        // Check order is sequential
        let orders = document.sections.map { $0.order }.sorted()
        if orders.count >= 2 {
            for i in 1..<orders.count {
                #expect(orders[i] >= orders[i-1])
            }
        }
    }

    @Test("Convert to CV metadata")
    func convertToCVMetadata() {
        let adapter = PrestoCVCoreAdapter()
        let document = adapter.convertToCV(from: nil)

        #expect(document.metadata != nil)
        #expect(!document.metadata.version.isEmpty)
    }

    @Test("Convert to CV consistency")
    func convertToCVConsistency() {
        let adapter = PrestoCVCoreAdapter()

        // Call multiple times should return same structure
        let document1 = adapter.convertToCV(from: nil)
        let document2 = adapter.convertToCV(from: nil)

        #expect(document1.personalInfo.name == document2.personalInfo.name)
        #expect(document1.sections.count == document2.sections.count)
    }
}