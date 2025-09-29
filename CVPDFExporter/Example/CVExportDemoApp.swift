import SwiftUI
import CVPDFExporter

#if canImport(UIKit)
import UIKit
#endif

@main
struct CVExportDemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var selectedTemplate = "modern"
    @State private var colorPalette = ColorPalette.professional
    @State private var fontScheme = FontScheme.modern

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // CV Preview Card
                    CVPreviewCard()
                        .padding(.horizontal)

                    // Export Button - One-tap solution as requested
                    #if canImport(UIKit)
                    CVExportButton(
                        cvData: createSampleCV(),
                        templateId: selectedTemplate,
                        customization: CustomizationOptions(
                            colorPalette: colorPalette,
                            fontScheme: fontScheme
                        )
                    )
                    .padding(.horizontal)
                    #else
                    Text("Export feature available on iOS only")
                        .padding()
                    #endif

                    // Template Selector
                    TemplateSelector(selectedTemplate: $selectedTemplate)
                        .padding(.horizontal)

                    // Customization Options
                    CustomizationSection(
                        colorPalette: $colorPalette,
                        fontScheme: $fontScheme
                    )
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("CV Export Demo")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
        }
    }
}

struct CVPreviewCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Alexandra Johnson")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Senior iOS Developer")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            Divider()

            // Quick Stats
            HStack(spacing: 20) {
                StatView(icon: "briefcase.fill", value: "8+", label: "Years")
                StatView(icon: "star.fill", value: "15", label: "Projects")
                StatView(icon: "graduationcap.fill", value: "BS", label: "Degree")
                StatView(icon: "globe", value: "3", label: "Languages")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                #if canImport(UIKit)
                .fill(Color(UIColor.systemBackground))
                #else
                .fill(Color.white)
                #endif
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
        )
    }
}

struct StatView: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.blue)

            Text(value)
                .font(.headline)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct TemplateSelector: View {
    @Binding var selectedTemplate: String

    let templates = [
        ("modern", "Modern", "Clean and contemporary design"),
        ("professional", "Professional", "Corporate-friendly layout"),
        ("minimal", "Minimal", "Simple and elegant style")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Template")
                .font(.headline)

            ForEach(templates, id: \.0) { template in
                TemplateOption(
                    id: template.0,
                    name: template.1,
                    description: template.2,
                    isSelected: selectedTemplate == template.0
                ) {
                    selectedTemplate = template.0
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                #if canImport(UIKit)
                .fill(Color(UIColor.secondarySystemBackground))
                #else
                .fill(Color.gray.opacity(0.1))
                #endif
        )
    }
}

struct TemplateOption: View {
    let id: String
    let name: String
    let description: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CustomizationSection: View {
    @Binding var colorPalette: ColorPalette
    @Binding var fontScheme: FontScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Customization")
                .font(.headline)

            // Color Palette
            VStack(alignment: .leading, spacing: 8) {
                Text("Color Palette")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    ColorOption(name: "Prof.", color: .blue, isSelected: colorPalette == .professional) {
                        colorPalette = .professional
                    }
                    ColorOption(name: "Modern", color: .purple, isSelected: colorPalette == .modern) {
                        colorPalette = .modern
                    }
                    ColorOption(name: "Creative", color: .orange, isSelected: colorPalette == .creative) {
                        colorPalette = .creative
                    }
                    ColorOption(name: "Minimal", color: .gray, isSelected: colorPalette == .minimal) {
                        colorPalette = .minimal
                    }
                }
            }

            // Font Scheme
            VStack(alignment: .leading, spacing: 8) {
                Text("Font Style")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    FontOption(name: "Modern", isSelected: fontScheme == .modern) {
                        fontScheme = .modern
                    }
                    FontOption(name: "Classic", isSelected: fontScheme == .classic) {
                        fontScheme = .classic
                    }
                    FontOption(name: "Serif", isSelected: fontScheme == .serif) {
                        fontScheme = .serif
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                #if canImport(UIKit)
                .fill(Color(UIColor.secondarySystemBackground))
                #else
                .fill(Color.gray.opacity(0.1))
                #endif
        )
    }
}

struct ColorOption: View {
    let name: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 2)
                    )

                Text(name)
                    .font(.caption2)
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FontOption: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.blue : Color.gray.opacity(0.2))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Sample CV Data Creation
func createSampleCV() -> Any {
    // Returns a CV model that can be used by the export system
    // Create a mock CV model structure that matches what CVExportManager expects
    let personalInfo = [
        "name": "Alexandra Johnson",
        "email": "alex.johnson@email.com",
        "phone": "+1 (555) 123-4567",
        "location": "San Francisco, CA",
        "linkedIn": "linkedin.com/in/alexjohnson",
        "summary": """
        Senior iOS Developer with 8+ years of experience building high-performance mobile applications. \
        Specialized in Swift, SwiftUI, and modern iOS architectures. Passionate about creating \
        intuitive user experiences and mentoring junior developers. Led teams of up to 10 engineers \
        in delivering mission-critical applications with millions of active users.
        """
    ]

    return [
        "personalInfo": personalInfo,
        "experience": createSampleExperience(),
        "education": createSampleEducation(),
        "skills": createSampleSkills(),
        "languages": createSampleLanguages(),
        "certifications": createSampleCertifications()
    ]
}

func createSampleExperience() -> [[String: String]] {
    return [
        [
            "title": "Senior iOS Engineer",
            "company": "TechCorp Inc.",
            "period": "Jan 2021 - Present",
            "location": "San Francisco, CA",
            "description": """
            • Led iOS development team of 6 engineers in building flagship mobile banking app
            • Architected and implemented modular SwiftUI architecture reducing build times by 40%
            • Mentored junior developers and conducted code reviews to maintain high code quality
            • Implemented CI/CD pipeline reducing deployment time from days to hours
            • Collaborated with product and design teams to deliver features used by 2M+ users
            """
        ],
        [
            "title": "iOS Developer",
            "company": "StartupXYZ",
            "period": "Jun 2018 - Dec 2020",
            "location": "San Francisco, CA",
            "description": """
            • Developed consumer-facing iOS app from concept to App Store release
            • Implemented real-time chat using WebSocket and background processing
            • Reduced app launch time by 60% through performance optimizations
            • Built custom UI components library used across multiple products
            • Achieved 4.8★ App Store rating with over 50K downloads
            """
        ],
        [
            "title": "Junior iOS Developer",
            "company": "Digital Agency Co.",
            "period": "Jul 2016 - May 2018",
            "location": "New York, NY",
            "description": """
            • Developed and maintained iOS applications for various clients
            • Implemented push notifications and in-app purchase features
            • Collaborated with Android team to ensure feature parity
            • Participated in agile development process with 2-week sprints
            """
        ]
    ]
}

func createSampleEducation() -> [[String: String]] {
    return [
        [
            "degree": "Bachelor of Science in Computer Science",
            "institution": "University of California, Berkeley",
            "period": "2012 - 2016",
            "location": "Berkeley, CA",
            "description": "GPA: 3.8/4.0 • Dean's List • Magna Cum Laude"
        ]
    ]
}

func createSampleSkills() -> [[String: Any]] {
    return [
        [
            "category": "Languages & Frameworks",
            "tags": ["Swift", "SwiftUI", "UIKit", "Objective-C", "Combine", "Core Data", "CloudKit"]
        ],
        [
            "category": "Tools & Technologies",
            "tags": ["Xcode", "Git", "CI/CD", "Fastlane", "TestFlight", "Firebase", "REST APIs", "GraphQL"]
        ],
        [
            "category": "Architecture & Patterns",
            "tags": ["MVVM", "Clean Architecture", "TDD", "SOLID", "Coordinator Pattern", "Dependency Injection"]
        ],
        [
            "category": "Soft Skills",
            "tags": ["Team Leadership", "Mentoring", "Agile/Scrum", "Code Review", "Technical Documentation"]
        ]
    ]
}

func createSampleLanguages() -> [[String: String]] {
    return [
        ["name": "English", "level": "Native"],
        ["name": "Spanish", "level": "Professional Working Proficiency"],
        ["name": "Mandarin", "level": "Basic Conversational"]
    ]
}

func createSampleCertifications() -> [[String: String]] {
    return [
        [
            "name": "Apple Certified iOS Developer",
            "issuer": "Apple Inc.",
            "date": "2023",
            "description": "Advanced certification in iOS development and best practices"
        ],
        [
            "name": "WWDC 2023 Scholarship Winner",
            "issuer": "Apple Inc.",
            "date": "2023",
            "description": "Selected from thousands of applicants worldwide"
        ],
        [
            "name": "AWS Certified Solutions Architect",
            "issuer": "Amazon Web Services",
            "date": "2022",
            "description": "Associate level certification for cloud architecture"
        ]
    ]
}