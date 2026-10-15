# CVGeneratorAI

AI-powered CV generation using Apple's FoundationModels.

## Overview

CVGeneratorAI is a Swift Package that provides tools to generate professional CVs from natural language descriptions. It uses protocol-based architecture to support different AI backends.

## Features

- **Protocol-Based Architecture**: Clean abstraction allows switching between AI implementations
- **Comprehensive Validation**: Input and output validation ensures data quality
- **Type-Safe Models**: All models are Codable, Equatable, and Sendable
- **Well-Tested**: 28 comprehensive tests covering models, services, validation, and use cases
- **SOLID Principles**: Clean architecture with clear separation of concerns

## Architecture

```
CVGeneratorAI/
├── Models/              # Domain models (CVData, Experience, Education, etc.)
├── Protocols/           # Service abstractions
├── Services/            # Service implementations (FoundationModels, Mock)
├── Validation/          # Input/output validation
└── UseCases/            # Business logic orchestration
```

## Usage

### Basic Usage

```swift
import CVGeneratorAI

// Create service (Mock for development, FoundationModels for production)
let service = MockCVGenerationService()

// Create use case
let useCase = CVGeneratorUseCase(service: service)

// Check availability
let available = await useCase.isAvailable()

// Create request
let request = CVGenerationRequest(
    userPrompt: "I am a software engineer with 5 years of experience...",
    personalInfo: PersonalInfo(name: "John Doe", email: "john@example.com"),
    preferences: GenerationPreferences(
        targetRole: "iOS Developer",
        experienceLevel: .senior,
        tone: .professional
    )
)

// Generate CV
let result = try await useCase.generateCV(from: request)
print(result.cvData)
```

### Using FoundationModels (iOS 18.2+)

```swift
if #available(iOS 18.2, *) {
    let service = FoundationModelsService()
    let useCase = CVGeneratorUseCase(service: service)
    // ... use case as above
}
```

## Models

- **CVData**: Complete CV structure with all sections
- **PersonalInfo**: Contact and personal details
- **Experience**: Work experience entries
- **Education**: Educational background
- **Skill**: Skills with proficiency levels
- **Language**: Language proficiency (CEFR-based)
- **Certification**: Professional certifications
- **Project**: Projects and achievements

## Testing

Run tests with:

```bash
swift test
```

Current test coverage: 28 tests covering:
- Model initialization and encoding
- Service behavior (mock and availability)
- Validation (request and CV data)
- Use case orchestration
- Error handling

## Requirements

- iOS 18.0+ / macOS 15.0+
- Swift 6.0+
- FoundationModels (for production AI service)

## Integration

This package is designed to be framework-agnostic. To integrate with your app:

1. Add CVGeneratorAI as a dependency
2. Create an adapter to convert between CVGeneratorAI models and your app's models
3. Use CVGeneratorUseCase in your app's use case layer

## Status

✅ Phase 1: Foundation & Core Models
✅ Phase 2: Service Layer & Testing
✅ Phase 3: Use Cases & Validation
🔄 Phase 4: Main App Integration (pending)

## License

Part of the PrestoCV app.
