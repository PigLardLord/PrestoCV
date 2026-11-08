import Foundation

/// Legacy store files with invented content, in the two shapes the released versions write: 1.0 (no `look`, no
/// document language until the person chose one) and 1.0.1 (`look`). Keys, nesting and the whole-second ISO 8601 times
/// are those of `StoredCV`; the legacy encoder pretty-prints and may leave out any optional key.
enum LegacyFixtures {
    static let idA = "AAAAAAAA-0000-4000-8000-000000000001"
    static let idB = "BBBBBBBB-0000-4000-8000-000000000002"

    static func fileName(_ id: String) -> String { "cv_\(id).json" }

    static func v10(id: String = idA, updatedAt: String = "2026-09-20T10:00:00Z") -> String {
        """
        {
          "certifications": [
            { "description": "Basic course", "id": "\(UUID().uuidString)", "issuer": "Example Institute", "name": "First Aid", "url": "https://example.org/aid", "year": 2019 }
          ],
          "createdAt": "2026-09-01T08:00:00Z",
          "education": [
            { "degree": "BSc Biology", "description": "", "id": "\(UUID().uuidString)", "period": "2012 – 2015", "school": "Example University" }
          ],
          "id": "\(id)",
          "interests": ["Chess", "chess", " Hiking "],
          "languages": [
            { "id": "\(UUID().uuidString)", "level": "B2", "name": "English" },
            { "id": "\(UUID().uuidString)", "level": "Native", "name": "Italian" }
          ],
          "name": "Lab roles",
          "personalInfo": {
            "email": "ada@example.org", "location": "Turin", "name": "Ada Example", "phone": "+39 011 555 0100",
            "portfolio": "https://example.org/ada", "profile": "Careful and curious.", "title": "Lab technician"
          },
          "relevant_experience": [
            { "company": "Example Labs", "description": "Ran assays.", "id": "\(UUID().uuidString)", "location": "Turin", "period": "Mar 2018 – Present", "title": "Technician" }
          ],
          "skills": [ { "id": "\(UUID().uuidString)", "level": 4, "name": "Pipetting" }, { "id": "\(UUID().uuidString)", "level": 0, "name": "Cooking" } ],
          "social": [ { "id": "\(UUID().uuidString)", "platform": "GitHub", "url": "https://example.org/ada-code" } ],
          "updatedAt": "\(updatedAt)"
        }
        """
    }

    static func v101(id: String = idB, look: String = #"{ "design": "modern", "palette": "ocean", "fonts": "classic" }"#,
                     updatedAt: String = "2026-10-20T10:00:00Z") -> String {
        """
        {
          "createdAt": "2026-10-01T08:00:00Z",
          "documentLanguage": "it",
          "id": "\(id)",
          "interests": [],
          "look": \(look),
          "name": "Esempio",
          "personalInfo": { "name": "Bruno Esempio", "title": "Cuoco" },
          "updatedAt": "\(updatedAt)"
        }
        """
    }

    /// A file of 1.0.1 whose body is `fields` (JSON members) around the required id.
    static func minimal(id: String = idA, _ fields: String = "") -> String {
        #"{"id":"\#(id)","updatedAt":"2026-10-02T00:00:00Z","createdAt":"2026-10-01T00:00:00Z"\#(fields.isEmpty ? "" : "," + fields)}"#
    }
}

/// Writes legacy files into a fresh directory.
func legacyDir(_ files: [String: String]) throws -> URL {
    let dir = tempDir()
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    for (name, text) in files { try Data(text.utf8).write(to: dir.appendingPathComponent(name)) }
    return dir
}
