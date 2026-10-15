import Foundation
import os

actor JSONTemplateLoader: JSONTemplateLoaderProtocol {
    
    private let decoder = JSONDecoder()
    private let logger = Logger(subsystem: "com.PigLardLord.prestocv", category: "templates")
    
    func loadTemplate(from path: String) async -> CVModel? {
        let url = URL(fileURLWithPath: path)
        
        guard let data = try? Data(contentsOf: url),
              let cv = try? decoder.decode(CVModel.self, from: data) else {
            logger.error("Failed to load template from \(url.lastPathComponent, privacy: .public)")
            return nil
        }
        
        return cv
    }
    
    func loadTemplate(from url: URL) async throws -> CVModel {
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(CVModel.self, from: data)
        } catch {
            throw AppError.decodingError("\(url.lastPathComponent): \(error.localizedDescription)")
        }
    }
    
    func loadTemplates(from paths: [String]) async -> [CVModel] {
        var templates: [CVModel] = []
        for path in paths {
            if let template = await loadTemplate(from: path) {
                templates.append(template)
            }
        }
        return templates
    }
    
    func loadTemplateIfMatches(
        path: String,
        matcher: @Sendable (String) -> Bool
    ) async throws -> CVModel? {
        let url = URL(fileURLWithPath: path)
        let fileName = url.deletingPathExtension().lastPathComponent
        
        guard matcher(fileName) else {
            return nil
        }
        
        return try await loadTemplate(from: url)
    }
}