import Foundation

// MARK: - Template Engine Protocol

/// Protocol for rendering templates with CV data
public protocol TemplateEngine: Sendable {
    func render(template: Template, data: CVDocument, customization: CustomizationOptions) async throws -> String
}

// MARK: - Style Value

/// A colour or font from the app's own palettes and font schemes. It goes into CSS as written: escaping it as
/// HTML would turn the quotes of a font name into entities, which CSS does not decode.
private struct StyleValue {
    let css: String

    init(_ css: String) {
        self.css = css
    }
}

// MARK: - Mustache Template Engine

/// Template engine implementation using Mustache-style templates
public final class MustacheTemplateEngine: TemplateEngine, @unchecked Sendable {

    public init() {}

    public func render(template: Template, data: CVDocument, customization: CustomizationOptions = CustomizationOptions()) async throws -> String {
        // Headings first, from the template alone: text from the CV is never read as a placeholder
        var html = TemplateLocalizer(locale: Locale(identifier: data.metadata.language)).localize(template: template.htmlContent)

        // Prepare context from CV data and customization
        let context = prepareContext(from: data, customization: customization)

        // Process template
        html = processTemplate(html, with: context)

        return html
    }

    // MARK: - Private Methods

    private func prepareContext(from document: CVDocument, customization: CustomizationOptions) -> [String: Any] {
        var context: [String: Any] = [:]

        context["lang"] = document.metadata.language

        // Personal info
        context["name"] = document.personalInfo.name
        context["email"] = document.personalInfo.email
        context["phone"] = document.personalInfo.phone ?? ""
        context["location"] = document.personalInfo.location ?? ""
        context["website"] = document.personalInfo.website ?? ""
        context["summary"] = document.personalInfo.summary ?? ""
        context["title"] = document.personalInfo.title ?? ""

        // Conditionals
        context["hasSummary"] = document.personalInfo.summary != nil
        context["hasPhone"] = document.personalInfo.phone != nil
        context["hasLocation"] = document.personalInfo.location != nil
        context["hasWebsite"] = document.personalInfo.website != nil
        context["hasTitle"] = document.personalInfo.title != nil

        // Work Experience
        let workSections = document.sections.filter { $0.type == .work }
        if !workSections.isEmpty {
            var workItems: [[String: String]] = []
            for section in workSections {
                for item in section.items {
                    workItems.append([
                        "title": item.title,
                        "company": item.subtitle ?? "",
                        "description": item.description ?? "",
                        "startDate": item.startDate ?? "",
                        "endDate": item.endDate ?? "",
                        "period": periodText(for: item),
                        "location": item.location ?? ""
                    ])
                }
            }
            context["workExperience"] = workItems
            context["hasWorkExperience"] = !workItems.isEmpty
        } else {
            context["hasWorkExperience"] = false
        }

        // Education
        let educationSections = document.sections.filter { $0.type == .education }
        if !educationSections.isEmpty {
            var educationItems: [[String: String]] = []
            for section in educationSections {
                for item in section.items {
                    educationItems.append([
                        "degree": item.title,
                        "school": item.subtitle ?? "",
                        "description": item.description ?? "",
                        "startDate": item.startDate ?? "",
                        "endDate": item.endDate ?? "",
                        "period": periodText(for: item)
                    ])
                }
            }
            context["education"] = educationItems
            context["hasEducation"] = !educationItems.isEmpty
        } else {
            context["hasEducation"] = false
        }

        // Skills
        let skillSections = document.sections.filter { $0.type == .skills }
        if !skillSections.isEmpty {
            var allSkills: [[String: Any]] = []

            for section in skillSections {
                for item in section.items {
                    // Each item represents a single skill with both name and title for flexibility
                    var skillDict: [String: Any] = [
                        "name": item.title,    // For {{name}} in skill badges
                        "title": item.title    // For {{title}} in nested structures
                    ]

                    // Add tags array for nested iteration ({{#tags}}{{.}}{{/tags}})
                    if !item.tags.isEmpty {
                        skillDict["tags"] = item.tags
                    }

                    // A level of 0 means the skill is not rated: no level, no dots
                    if let levelStr = item.metadata["level"], let level = Int(levelStr), level > 0 {
                        let ratedLevel = min(level, Self.maxSkillLevel)
                        skillDict["level"] = ratedLevel
                        skillDict["hasLevel"] = true
                        skillDict["levelDots"] = createLevelDots(level: ratedLevel)
                    } else {
                        skillDict["hasLevel"] = false
                    }
                    allSkills.append(skillDict)
                }
            }

            context["skills"] = allSkills
            context["hasSkills"] = !allSkills.isEmpty
        } else {
            context["hasSkills"] = false
        }

        // Certifications
        let certSections = document.sections.filter { $0.type == .certifications }
        if !certSections.isEmpty {
            var certItems: [[String: String]] = []
            for section in certSections {
                for item in section.items {
                    certItems.append([
                        "title": item.title,
                        "issuer": item.subtitle ?? "",
                        "description": item.description ?? "",
                        "date": item.startDate ?? "",
                        "url": item.url ?? ""
                    ])
                }
            }
            context["certifications"] = certItems
            context["hasCertifications"] = !certItems.isEmpty
        } else {
            context["hasCertifications"] = false
        }

        // Languages
        let langSections = document.sections.filter { $0.type == .languages }
        if !langSections.isEmpty {
            var langItems: [[String: String]] = []
            for section in langSections {
                for item in section.items {
                    langItems.append([
                        "language": item.title,
                        "level": item.subtitle ?? ""
                    ])
                }
            }
            context["languages"] = langItems
            context["hasLanguages"] = !langItems.isEmpty
        } else {
            context["hasLanguages"] = false
        }

        // Interests
        let interestSections = document.sections.filter { $0.type == .interests }
        if !interestSections.isEmpty {
            var interestItems: [String] = []
            for section in interestSections {
                for item in section.items {
                    interestItems.append(item.title)
                }
            }
            context["interests"] = interestItems
            context["hasInterests"] = !interestItems.isEmpty
        } else {
            context["hasInterests"] = false
        }

        // Social Links / Online Profiles
        var socialItems: [[String: String]] = []
        for section in document.sections where section.id == CVSection.socialID {
            for item in section.items {
                socialItems.append([
                    "platform": item.title,
                    "url": item.url ?? item.subtitle ?? ""
                ])
            }
        }
        context["hasSocialLinks"] = !socialItems.isEmpty
        if !socialItems.isEmpty {
            context["socialLinks"] = socialItems
        }

        // Add customization values
        let colors = customization.colorPalette.colors
        context["colorPrimary"] = StyleValue(colors.primary)
        context["colorSecondary"] = StyleValue(colors.secondary)
        context["colorAccent"] = StyleValue(colors.accent)
        context["colorBackground"] = StyleValue(colors.background)
        context["colorText"] = StyleValue(colors.text)

        let fonts = customization.fontScheme.fonts
        context["fontHeading"] = StyleValue(fonts.heading)
        context["fontBody"] = StyleValue(fonts.body)
        context["fontSize"] = StyleValue(fonts.size)

        return context
    }

    /// The period as the person wrote it, or the start and end dates joined when there is none
    private func periodText(for item: CVItem) -> String {
        if let period = item.period?.trimmingCharacters(in: .whitespacesAndNewlines), !period.isEmpty {
            return period
        }
        return [item.startDate, item.endDate]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " – ")
    }

    private func processTemplate(_ template: String, with context: [String: Any]) -> String {
        var result = template

        // Process both conditionals and loops in a unified way
        result = processBlocks(result, context: context)

        // Process simple variables ({{key}})
        result = processVariables(result, context: context)

        return result
    }

    private func processBlocks(_ template: String, context: [String: Any]) -> String {
        var result = template

        // Process {{#key}}...{{/key}} blocks (both conditionals and loops)
        let blockPattern = #"\{\{#(\w+)\}\}(.*?)\{\{/\1\}\}"#
        if let regex = try? NSRegularExpression(pattern: blockPattern, options: [.dotMatchesLineSeparators]) {
            var hasChanges = true
            while hasChanges {
                hasChanges = false
                let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))

                for match in matches.reversed() {
                    if let keyRange = Range(match.range(at: 1), in: result),
                       let contentRange = Range(match.range(at: 2), in: result),
                       let fullRange = Range(match.range, in: result) {
                        let key = String(result[keyRange])
                        let content = String(result[contentRange])

                        if let value = context[key] {
                            if let arrayValue = value as? [[String: Any]] {
                                // It's an array of dictionaries - process as loop
                                var loopResult = ""
                                for item in arrayValue {
                                    var itemContent = content

                                    // Create a merged context with both parent and item data
                                    var mergedContext = context
                                    for (itemKey, itemValue) in item {
                                        mergedContext[itemKey] = itemValue
                                    }

                                    // Process nested blocks recursively with merged context
                                    itemContent = processBlocks(itemContent, context: mergedContext)

                                    // Then process any remaining variables
                                    itemContent = processVariables(itemContent, context: mergedContext)

                                    loopResult += itemContent
                                }
                                result.replaceSubrange(fullRange, with: loopResult)
                                hasChanges = true
                            } else if let stringArray = value as? [String] {
                                // It's an array of strings - process as loop with {{.}} support
                                var loopResult = ""
                                for stringValue in stringArray {
                                    var itemContent = content

                                    // Replace {{.}} with the current string value
                                    itemContent = itemContent.replacingOccurrences(of: "{{.}}", with: escapeHTML(stringValue))

                                    loopResult += itemContent
                                }
                                result.replaceSubrange(fullRange, with: loopResult)
                                hasChanges = true
                            } else if let boolValue = value as? Bool {
                                // It's a boolean conditional
                                result.replaceSubrange(fullRange, with: boolValue ? content : "")
                                hasChanges = true
                            } else if let stringValue = value as? String {
                                // An empty string is false, like a missing value
                                result.replaceSubrange(fullRange, with: stringValue.isEmpty ? "" : content)
                                hasChanges = true
                            } else {
                                // Non-nil, non-array, non-bool means true
                                result.replaceSubrange(fullRange, with: content)
                                hasChanges = true
                            }
                        } else {
                            // Key doesn't exist - remove block
                            result.replaceSubrange(fullRange, with: "")
                            hasChanges = true
                        }

                        if hasChanges {
                            break // Start over with updated content
                        }
                    }
                }
            }
        }

        // Process negative conditionals {{^key}}...{{/key}}
        let negativePattern = #"\{\{\^(\w+)\}\}(.*?)\{\{/\1\}\}"#
        if let regex = try? NSRegularExpression(pattern: negativePattern, options: [.dotMatchesLineSeparators]) {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                if let keyRange = Range(match.range(at: 1), in: result),
                   let contentRange = Range(match.range(at: 2), in: result),
                   let fullRange = Range(match.range, in: result) {
                    let key = String(result[keyRange])
                    let content = String(result[contentRange])

                    if let value = context[key] {
                        if let boolValue = value as? Bool {
                            result.replaceSubrange(fullRange, with: !boolValue ? content : "")
                        } else if let stringValue = value as? String {
                            result.replaceSubrange(fullRange, with: stringValue.isEmpty ? content : "")
                        } else {
                            result.replaceSubrange(fullRange, with: "")
                        }
                    } else {
                        result.replaceSubrange(fullRange, with: content)
                    }
                }
            }
        }

        return result
    }

    private func processVariables(_ template: String, context: [String: Any]) -> String {
        var result = template

        // Process simple variables {{key}}
        for (key, value) in context {
            if let stringValue = value as? String {
                result = result.replacingOccurrences(of: "{{\(key)}}", with: escapeHTML(stringValue))
            } else if let styleValue = value as? StyleValue {
                result = result.replacingOccurrences(of: "{{\(key)}}", with: styleValue.css)
            } else if !(value is [Any]) {
                // Only replace non-array values
                result = result.replacingOccurrences(of: "{{\(key)}}", with: String(describing: value))
            }
        }

        // Remove any remaining unmatched variables
        let variablePattern = #"\{\{[^}]+\}\}"#
        if let regex = try? NSRegularExpression(pattern: variablePattern) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }

        return result
    }

    /// Escapes HTML and the braces of template syntax, so that text from the CV is never read as a template tag
    private func escapeHTML(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
            .replacingOccurrences(of: "{", with: "&#123;")
            .replacingOccurrences(of: "}", with: "&#125;")
    }

    private static let maxSkillLevel = 5

    private func createLevelDots(level: Int) -> String {
        let maxLevel = Self.maxSkillLevel
        let filledDot = "●"
        let emptyDot = "○"
        var dots = ""
        for i in 1...maxLevel {
            dots += i <= level ? filledDot : emptyDot
            if i < maxLevel {
                dots += " "
            }
        }
        return dots
    }
}
