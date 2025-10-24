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

                    // Check if metadata contains skill level
                    if let levelStr = item.metadata["level"], let level = Int(levelStr) {
                        skillDict["level"] = level
                        skillDict["hasLevel"] = true
                        skillDict["levelDots"] = createLevelDots(level: level)
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
                        "date": item.startDate ?? ""
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
        let socialSections = document.sections.filter { $0.title == "Online Profiles" || $0.type == .custom }
        if !socialSections.isEmpty {
            var socialItems: [[String: String]] = []
            for section in socialSections {
                // Only process if it's actually a social/online profiles section
                if section.title == "Online Profiles" {
                    for item in section.items {
                        socialItems.append([
                            "platform": item.title,
                            "url": item.url ?? item.subtitle ?? ""
                        ])
                    }
                }
            }
            if !socialItems.isEmpty {
                context["socialLinks"] = socialItems
                context["hasSocialLinks"] = true
            } else {
                context["hasSocialLinks"] = false
            }
        } else {
            context["hasSocialLinks"] = false
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
                            // Arrays are handled by processLoops, don't touch them here
                            // Just leave the content as is
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

    private func processNestedConditionals(_ template: String, context: [String: Any]) -> String {
        var result = template

        // Process {{#key}}...{{/key}} conditionals for non-empty strings
        let conditionalPattern = #"\{\{#(\w+)\}\}(.*?)\{\{/\1\}\}"#
        if let regex = try? NSRegularExpression(pattern: conditionalPattern, options: [.dotMatchesLineSeparators]) {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))

            for match in matches.reversed() {
                if let keyRange = Range(match.range(at: 1), in: result),
                   let contentRange = Range(match.range(at: 2), in: result),
                   let fullRange = Range(match.range, in: result) {
                    let key = String(result[keyRange])
                    let content = String(result[contentRange])

                    if let value = context[key] {
                        // Check if value is non-empty
                        if let stringValue = value as? String, !stringValue.isEmpty {
                            result.replaceSubrange(fullRange, with: content)
                        } else if value is Bool {
                            let boolValue = value as! Bool
                            result.replaceSubrange(fullRange, with: boolValue ? content : "")
                        } else {
                            result.replaceSubrange(fullRange, with: content)
                        }
                    } else {
                        result.replaceSubrange(fullRange, with: "")
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

    private func escapeHTML(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private func createLevelDots(level: Int) -> String {
        let maxLevel = 5
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
