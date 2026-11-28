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
                        cvDocument: createSampleCV(),
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
func createSampleCV() -> CVDocument {
    CVDocument(
        personalInfo: PersonalInfo(
            name: "Alexandra Johnson",
            email: "alex.johnson@email.com",
            phone: "+1 (555) 123-4567",
            location: "San Francisco, CA",
            website: "linkedin.com/in/alexjohnson",
            summary: "Senior iOS Developer with 8+ years of experience building high-performance mobile applications.",
            title: "Senior iOS Engineer"
        ),
        sections: [
            CVSection(id: "work", type: .work, title: "Work Experience", items: [
                CVItem(
                    title: "Senior iOS Engineer", subtitle: "TechCorp Inc.",
                    description: "Led the iOS team of 6 engineers on the flagship mobile banking app",
                    period: "Jan 2021 - Present", location: "San Francisco, CA"
                ),
                CVItem(
                    title: "iOS Developer", subtitle: "StartupXYZ",
                    description: "Developed a consumer-facing iOS app from concept to App Store release",
                    period: "Jun 2018 - Dec 2020", location: "San Francisco, CA"
                ),
            ], order: 1),
            CVSection(id: "education", type: .education, title: "Education", items: [
                CVItem(
                    title: "Bachelor of Science in Computer Science", subtitle: "University of California, Berkeley",
                    period: "2012 - 2016", location: "Berkeley, CA"
                ),
            ], order: 2),
            CVSection(id: "skills", type: .skills, title: "Skills", items: [
                CVItem(title: "Swift", tags: ["5"], metadata: ["level": "5"]),
                CVItem(title: "SwiftUI", tags: ["4"], metadata: ["level": "4"]),
            ], order: 3),
            CVSection(id: "languages", type: .languages, title: "Languages", items: [
                CVItem(title: "English", subtitle: "Native"),
                CVItem(title: "Spanish", subtitle: "Professional"),
            ], order: 4),
            CVSection(id: "certifications", type: .certifications, title: "Certifications", items: [
                CVItem(title: "AWS Certified Solutions Architect", subtitle: "Amazon Web Services", startDate: "2022"),
            ], order: 5),
        ]
    )
}
