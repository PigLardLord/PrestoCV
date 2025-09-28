import Foundation

// MARK: - JSON Resume Format

/// JSON Resume standard format (https://jsonresume.org/schema/)
/// Sprint 5: Export format support
public struct JSONResume: Codable, Sendable {

    // MARK: - Basics

    public struct Basics: Codable, Sendable {
        public let name: String?
        public let label: String?
        public let image: String?
        public let email: String?
        public let phone: String?
        public let url: String?
        public let summary: String?
        public let location: Location?
        public let profiles: [Profile]?

        public init(
            name: String? = nil,
            label: String? = nil,
            image: String? = nil,
            email: String? = nil,
            phone: String? = nil,
            url: String? = nil,
            summary: String? = nil,
            location: Location? = nil,
            profiles: [Profile]? = nil
        ) {
            self.name = name
            self.label = label
            self.image = image
            self.email = email
            self.phone = phone
            self.url = url
            self.summary = summary
            self.location = location
            self.profiles = profiles
        }
    }

    // MARK: - Location

    public struct Location: Codable, Sendable {
        public let address: String?
        public let postalCode: String?
        public let city: String?
        public let countryCode: String?
        public let region: String?

        public init(
            address: String? = nil,
            postalCode: String? = nil,
            city: String? = nil,
            countryCode: String? = nil,
            region: String? = nil
        ) {
            self.address = address
            self.postalCode = postalCode
            self.city = city
            self.countryCode = countryCode
            self.region = region
        }
    }

    // MARK: - Profile

    public struct Profile: Codable, Sendable {
        public let network: String?
        public let username: String?
        public let url: String?

        public init(
            network: String? = nil,
            username: String? = nil,
            url: String? = nil
        ) {
            self.network = network
            self.username = username
            self.url = url
        }
    }

    // MARK: - Work

    public struct Work: Codable, Sendable {
        public let name: String?
        public let position: String?
        public let url: String?
        public let startDate: String?
        public let endDate: String?
        public let summary: String?
        public let highlights: [String]?

        public init(
            name: String? = nil,
            position: String? = nil,
            url: String? = nil,
            startDate: String? = nil,
            endDate: String? = nil,
            summary: String? = nil,
            highlights: [String]? = nil
        ) {
            self.name = name
            self.position = position
            self.url = url
            self.startDate = startDate
            self.endDate = endDate
            self.summary = summary
            self.highlights = highlights
        }
    }

    // MARK: - Education

    public struct Education: Codable, Sendable {
        public let institution: String?
        public let area: String?
        public let studyType: String?
        public let startDate: String?
        public let endDate: String?
        public let gpa: String?
        public let courses: [String]?

        public init(
            institution: String? = nil,
            area: String? = nil,
            studyType: String? = nil,
            startDate: String? = nil,
            endDate: String? = nil,
            gpa: String? = nil,
            courses: [String]? = nil
        ) {
            self.institution = institution
            self.area = area
            self.studyType = studyType
            self.startDate = startDate
            self.endDate = endDate
            self.gpa = gpa
            self.courses = courses
        }
    }

    // MARK: - Skill

    public struct Skill: Codable, Sendable {
        public let name: String?
        public let level: String?
        public let keywords: [String]?

        public init(
            name: String? = nil,
            level: String? = nil,
            keywords: [String]? = nil
        ) {
            self.name = name
            self.level = level
            self.keywords = keywords
        }
    }

    // MARK: - Language

    public struct Language: Codable, Sendable {
        public let language: String?
        public let fluency: String?

        public init(
            language: String? = nil,
            fluency: String? = nil
        ) {
            self.language = language
            self.fluency = fluency
        }
    }

    // MARK: - Interest

    public struct Interest: Codable, Sendable {
        public let name: String?
        public let keywords: [String]?

        public init(
            name: String? = nil,
            keywords: [String]? = nil
        ) {
            self.name = name
            self.keywords = keywords
        }
    }

    // MARK: - Reference

    public struct Reference: Codable, Sendable {
        public let name: String?
        public let reference: String?

        public init(
            name: String? = nil,
            reference: String? = nil
        ) {
            self.name = name
            self.reference = reference
        }
    }

    // MARK: - Main Structure

    public let basics: Basics?
    public let work: [Work]?
    public let education: [Education]?
    public let skills: [Skill]?
    public let languages: [Language]?
    public let interests: [Interest]?
    public let references: [Reference]?

    public init(
        basics: Basics? = nil,
        work: [Work]? = nil,
        education: [Education]? = nil,
        skills: [Skill]? = nil,
        languages: [Language]? = nil,
        interests: [Interest]? = nil,
        references: [Reference]? = nil
    ) {
        self.basics = basics
        self.work = work
        self.education = education
        self.skills = skills
        self.languages = languages
        self.interests = interests
        self.references = references
    }
}