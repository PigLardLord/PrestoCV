import Foundation

/// Comprehensive sample CV data for previews and testing
/// This CV uses ALL available fields to showcase template capabilities
public struct SampleCVData {

    /// Complete sample CV with all fields populated
    public static let complete: CVDocument = {
        CVDocument(
            personalInfo: PersonalInfo(
                name: "Maya Chen",
                email: "maya.chen@example.com",
                phone: "+1 (555) 987-6543",
                location: "Brooklyn, NY",
                website: "https://mayachen.design",
                summary: "Creative designer with 7+ years of experience crafting intuitive digital experiences for startups and Fortune 500 companies. Specialized in user-centered design, design systems, and cross-platform experiences. Passionate about accessibility and creating beautiful, functional interfaces that solve real user problems."
            ),
            sections: [
                workExperienceSection,
                educationSection,
                skillsSection,
                certificationsSection,
                languagesSection,
                projectsSection,
                interestsSection
            ]
        )
    }()

    // MARK: - Sections

    private static let workExperienceSection = CVSection(
        type: .work,
        title: "Work Experience",
        items: [
            CVItem(
                title: "Senior UX/UI Designer",
                subtitle: "DesignForward Agency",
                description: "Lead design for fintech platform used by 2M+ customers. • Created comprehensive design system adopted by 15+ product teams • Increased user engagement by 35% through UX optimization and A/B testing • Managed team of 4 designers and established design review process • Led accessibility initiative achieving WCAG 2.1 AA compliance",
                startDate: "April 2021",
                endDate: "Present",
                location: "New York, NY",
                tags: ["UX Design", "Design Systems", "Leadership", "Fintech"]
            ),
            CVItem(
                title: "Product Designer",
                subtitle: "EcoTech Solutions",
                description: "Designed sustainable technology platform for environmental monitoring. • Led end-to-end design process from user research to final implementation • Created interactive prototypes that improved stakeholder alignment by 50% • Collaborated with engineering team to ensure design feasibility and quality • Won 'Best Product Design' award at GreenTech Conference 2020",
                startDate: "August 2018",
                endDate: "March 2021",
                location: "San Francisco, CA",
                tags: ["Product Design", "Prototyping", "User Research"]
            ),
            CVItem(
                title: "Junior Designer",
                subtitle: "PixelPerfect Studio",
                description: "Created visual assets and layouts for marketing campaigns. • Designed brand identities for 20+ clients across various industries • Developed wireframes and prototypes for mobile and web applications • Participated in user testing sessions and incorporated feedback into designs",
                startDate: "June 2016",
                endDate: "July 2018",
                location: "Austin, TX",
                tags: ["Visual Design", "Branding", "UI Design"]
            )
        ]
    )

    private static let educationSection = CVSection(
        type: .education,
        title: "Education",
        items: [
            CVItem(
                title: "M.F.A. in Graphic Design",
                subtitle: "Rhode Island School of Design",
                description: "Focus on digital interaction design and motion graphics. Thesis project on inclusive design for accessibility.",
                startDate: "2014",
                endDate: "2016",
                location: "Providence, RI",
                tags: ["GPA: 3.9/4.0", "Dean's List", "Teaching Assistant"]
            ),
            CVItem(
                title: "B.F.A. in Visual Communication",
                subtitle: "School of the Art Institute of Chicago",
                description: "Emphasis on typography and user experience design. Graduated with distinction. Led design team for senior capstone project.",
                startDate: "2010",
                endDate: "2014",
                location: "Chicago, IL",
                tags: ["Graduated with Honors", "Presidential Scholarship"]
            )
        ]
    )

    private static let skillsSection = CVSection(
        type: .skills,
        title: "Skills",
        items: [
            CVItem(title: "Figma", tags: ["Expert", "5 years"]),
            CVItem(title: "Adobe Creative Suite", tags: ["Expert", "7+ years"]),
            CVItem(title: "Sketch", tags: ["Advanced", "4 years"]),
            CVItem(title: "Prototyping", tags: ["Expert", "6 years"]),
            CVItem(title: "User Research", tags: ["Advanced", "5 years"]),
            CVItem(title: "Design Systems", tags: ["Expert", "4 years"]),
            CVItem(title: "Accessibility (WCAG)", tags: ["Advanced", "3 years"]),
            CVItem(title: "Illustration", tags: ["Intermediate", "5 years"]),
            CVItem(title: "Motion Design", tags: ["Intermediate", "3 years"]),
            CVItem(title: "Brand Identity", tags: ["Expert", "6 years"]),
            CVItem(title: "HTML/CSS", tags: ["Intermediate", "4 years"]),
            CVItem(title: "JavaScript Basics", tags: ["Beginner", "2 years"])
        ]
    )

    private static let certificationsSection = CVSection(
        type: .certifications,
        title: "Certifications",
        items: [
            CVItem(
                title: "UX Design Professional Certificate",
                subtitle: "Google",
                description: "Comprehensive certification covering UX research, prototyping, and testing",
                startDate: "2023",
                url: "https://grow.google/certificates/ux-design/",
                metadata: ["year": "2023"]
            ),
            CVItem(
                title: "Certified Usability Analyst (CUA)",
                subtitle: "Human Factors International",
                description: "Advanced certification in usability evaluation and user research methodologies",
                startDate: "2022",
                metadata: ["year": "2022"]
            ),
            CVItem(
                title: "Accessibility Specialist Certification",
                subtitle: "International Association of Accessibility Professionals (IAAP)",
                startDate: "2021",
                url: "https://www.accessibilityassociation.org/",
                metadata: ["year": "2021"]
            )
        ]
    )

    private static let languagesSection = CVSection(
        type: .languages,
        title: "Languages",
        items: [
            CVItem(title: "English", tags: ["Native"]),
            CVItem(title: "Spanish", tags: ["Professional Working Proficiency"]),
            CVItem(title: "Mandarin Chinese", tags: ["Conversational"])
        ]
    )

    private static let projectsSection = CVSection(
        type: .projects,
        title: "Notable Projects",
        items: [
            CVItem(
                title: "AccessDesign Toolkit",
                subtitle: "Open Source Project",
                description: "Created open-source Figma plugin for accessibility testing with 10K+ downloads. • Featured in Figma's official plugin directory • Adopted by companies like Airbnb and Shopify • Active community with 50+ contributors",
                startDate: "2022",
                endDate: "Present",
                url: "https://github.com/mayachen/accessdesign",
                tags: ["Open Source", "Accessibility", "Figma Plugin"]
            ),
            CVItem(
                title: "Design System Handbook",
                subtitle: "Published Work",
                description: "Co-authored comprehensive guide to building and maintaining design systems.",
                startDate: "2023",
                url: "https://designsystemhandbook.com",
                tags: ["Publication", "Design Systems", "Education"]
            )
        ]
    )

    private static let interestsSection = CVSection(
        type: .interests,
        title: "Interests & Activities",
        items: [
            CVItem(
                title: "Speaking & Teaching",
                description: "Regular speaker at design conferences including UXDX, Config, and Design Matters. Guest lecturer at Parsons School of Design.",
                tags: ["Public Speaking", "Education", "Community"]
            ),
            CVItem(
                title: "Creative Pursuits",
                description: "Photography, watercolor painting, and exploring sustainable design practices.",
                tags: ["Photography", "Art", "Sustainability"]
            ),
            CVItem(
                title: "Volunteer Work",
                description: "Design mentor for underrepresented minorities through ADPList. Pro-bono design work for local nonprofits.",
                tags: ["Mentorship", "Volunteering", "Community Service"]
            )
        ]
    )
}
