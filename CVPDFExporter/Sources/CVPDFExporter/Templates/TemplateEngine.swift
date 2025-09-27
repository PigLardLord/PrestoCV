import Foundation

// MARK: - Template Engine Protocol

/// Protocol for rendering templates with CV data
public protocol TemplateEngine: Sendable {
    func render(template: Template, data: CVDocument, customization: CustomizationOptions) async throws -> String
}

// MARK: - Mustache Template Engine

/// Template engine implementation using Mustache-style templates
public final class MustacheTemplateEngine: TemplateEngine, @unchecked Sendable {

    public init() {}

    public func render(template: Template, data: CVDocument, customization: CustomizationOptions = CustomizationOptions()) async throws -> String {
        var html = template.htmlContent

        // Prepare context from CV data and customization
        let context = prepareContext(from: data, customization: customization)

        // Process template
        html = processTemplate(html, with: context)

        return html
    }

    // MARK: - Private Methods

    private func prepareContext(from document: CVDocument, customization: CustomizationOptions) -> [String: Any] {
        var context: [String: Any] = [:]

        // Personal info
        context["name"] = document.personalInfo.name
        context["email"] = document.personalInfo.email
        context["phone"] = document.personalInfo.phone ?? ""
        context["location"] = document.personalInfo.location ?? ""
        context["website"] = document.personalInfo.website ?? ""
        context["summary"] = document.personalInfo.summary ?? ""

        // Conditionals
        context["hasSummary"] = document.personalInfo.summary != nil
        context["hasPhone"] = document.personalInfo.phone != nil
        context["hasLocation"] = document.personalInfo.location != nil
        context["hasWebsite"] = document.personalInfo.website != nil

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
                        "endDate": item.endDate ?? ""
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
            var skillGroups: [[String: Any]] = []
            for section in skillSections {
                for item in section.items {
                    var skillGroup: [String: Any] = [
                        "category": item.title
                    ]
                    if !item.tags.isEmpty {
                        skillGroup["skills"] = item.tags
                    }
                    skillGroups.append(skillGroup)
                }
            }
            context["skills"] = skillGroups
            context["hasSkills"] = !skillGroups.isEmpty
        } else {
            context["hasSkills"] = false
        }

        // Add customization values
        let colors = customization.colorPalette.colors
        context["colorPrimary"] = colors.primary
        context["colorSecondary"] = colors.secondary
        context["colorAccent"] = colors.accent
        context["colorBackground"] = colors.background
        context["colorText"] = colors.text

        let fonts = customization.fontScheme.fonts
        context["fontHeading"] = fonts.heading
        context["fontBody"] = fonts.body
        context["fontSize"] = fonts.size

        return context
    }

    private func processTemplate(_ template: String, with context: [String: Any]) -> String {
        var result = template

        // Process loops first ({{#array}}...{{/array}})
        result = processLoops(result, context: context)

        // Process conditionals ({{#key}}...{{/key}} and {{^key}}...{{/key}})
        result = processConditionals(result, context: context)

        // Process simple variables ({{key}})
        result = processVariables(result, context: context)

        return result
    }

    private func processConditionals(_ template: String, context: [String: Any]) -> String {
        var result = template

        // Process positive conditionals {{#key}}...{{/key}}
        let positivePattern = #"\{\{#(\w+)\}\}(.*?)\{\{/\1\}\}"#
        if let regex = try? NSRegularExpression(pattern: positivePattern, options: [.dotMatchesLineSeparators]) {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                if let keyRange = Range(match.range(at: 1), in: result),
                   let contentRange = Range(match.range(at: 2), in: result),
                   let fullRange = Range(match.range, in: result) {
                    let key = String(result[keyRange])
                    let content = String(result[contentRange])

                    if let value = context[key] {
                        if let boolValue = value as? Bool {
                            result.replaceSubrange(fullRange, with: boolValue ? content : "")
                        } else if value is [[String: Any]] {
                            // Skip arrays - they're handled by processLoops
                            continue
                        } else {
                            // Non-nil value means condition is true
                            result.replaceSubrange(fullRange, with: content)
                        }
                    } else {
                        result.replaceSubrange(fullRange, with: "")
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

    private func processLoops(_ template: String, context: [String: Any]) -> String {
        var result = template

        // Process array loops {{#array}}...{{/array}}
        let loopPattern = #"\{\{#(\w+)\}\}(.*?)\{\{/\1\}\}"#
        if let regex = try? NSRegularExpression(pattern: loopPattern, options: [.dotMatchesLineSeparators]) {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                if let keyRange = Range(match.range(at: 1), in: result),
                   let contentRange = Range(match.range(at: 2), in: result),
                   let fullRange = Range(match.range, in: result) {
                    let key = String(result[keyRange])
                    let itemTemplate = String(result[contentRange])

                    if let array = context[key] as? [[String: Any]] {
                        var loopResult = ""
                        for item in array {
                            var itemContent = itemTemplate
                            // Replace variables in item template
                            for (itemKey, itemValue) in item {
                                itemContent = itemContent.replacingOccurrences(
                                    of: "{{\(itemKey)}}",
                                    with: String(describing: itemValue)
                                )
                            }
                            loopResult += itemContent
                        }
                        result.replaceSubrange(fullRange, with: loopResult)
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
                // Escape HTML by default (use {{key}} for escaped, {{{key}}} for unescaped)
                let escapedValue = escapeHTML(stringValue)
                result = result.replacingOccurrences(of: "{{\(key)}}", with: escapedValue)
                // Support triple mustache for unescaped HTML
                result = result.replacingOccurrences(of: "{{{\(key)}}}", with: stringValue)
            } else if !(value is [Any]) {
                // Only replace non-array values
                result = result.replacingOccurrences(of: "{{\(key)}}", with: String(describing: value))
            }
        }

        return result
    }

    private func escapeHTML(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
