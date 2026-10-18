# CVGeneratorAI

Drafts the fields of a CV from a person's own description, on the device, with Apple's FoundationModels.

This is the legacy generator that the app ships in v1 (ADR 0012). The `CVDrafting` targets
are its planned replacement and are still empty.

## What it does

- **Only what the person said.** The model fills a small schema (`CVData`) in which every detail is optional. The
  instructions forbid inventing anything, and `CVDataSanitizer` enforces it afterwards by checking every retained
  field against the description. The rules are conservative by construction: a token that could be read two ways is
  not accepted.
  - Contact details (email, link, phone) must be whole tokens of the description. A token is a run between white
    space, brackets and quotes, without the punctuation that ends a sentence; an address is never taken out of a
    larger token. They may differ only in case, in a link's scheme, `www.` and trailing slash (its query and
    fragment count), and in a phone's separators and `+` or `00` prefix.
  - Names (people, employers, schools, titles, places, certifications, skills, interests) must occur in it as a
    contiguous phrase of whole words, ignoring case and accents. An entry with nothing identifying left is dropped.
  - Prose (summary, descriptions, achievements) keeps only the sentences that state no contact detail or number the
    description lacks. Numbers are compared with their separators and with every Unicode digit read as 0-9, so `35`,
    `3.5` and `1.000` are three numbers, and `1.000` and `1,000` are one.
  - A skill level or language level stays only if the description states it for that item, by a CEFR code or a level
    word in the same sentence, with no negation or hedge in it ("not fluent", "a bit", "hardly"). A skill is
    otherwise unrated and a language is left out.
  - What an entry says beyond its name (title or degree, dates, figures, place, certification issuer and link, and
    whether a job is current) must come from a clause of the description that names the entry's employer or school.
    A clause ends at a comma, a semicolon or a conjunction (a conjunction inside the name of an employer does not end
    it). Nothing else is read: not capitals, not prepositions, not the sentence the clause stands in, and not the fact
    that the description names one employer only. So an employer the draft leaves out, however it is written ("Beta
    trained 9 nurses." or "...and beta employed me"), can neither take the facts of the entries before it nor lend its
    own. The one carry-over is a lead-in: a first clause that says nothing but a time for the present ("Currently,",
    "Since 2019,") belongs to the clause after it. The entry is found through its employer or school, because a title
    is shared: when another entry has the same employer, by employer and title together; with no employer, by its
    title, and only if that occurs once. A clause that names two employers of the draft backs neither, and a job's text
    that names another employer of the draft is dropped. A fact in a clause that does not name the employer is dropped,
    which thins a draft: the figure after "where", the years in "Before that, from 2012 to 2016,", the year after "and
    graduated", and the title stated only about the person.
  - A level is stated in the clause of its item (or in the next one, when that starts with the level), whether or not
    the draft has the neighbouring items.
  - A job stays current only if a clause naming its employer says it goes on now (or "since" with a year, when the sentence
    holds exactly one).
  - Repeated entries are dropped.
  - Words are read in the description's language. A word that is an employer preposition in another of the six languages,
    and another word in the description's, is that other word: French "j'ai" holds no Italian "ai", English "per shift" no
    Italian "per". A preposition of another language that the description's language does not have keeps its meaning.
- **On device.** The request, the description and the answer never leave the device.
- **Typed outcomes.** Failures are `CVGenerationError` cases that the app explains in the person's language;
  cancellation is `CancellationError`, never an error case. Availability is an `AIAvailability` value with the reason
  when the model cannot run (device not eligible, Apple Intelligence off, model not ready).
- **Language data.** The verbs of English and German are read from the device's lexical class (`LexicalTagger`, the
  device's `DeviceLexicalTagger` in the app), which the device has once it has downloaded the language's data. Without
  it, `generateCV` throws `languageDataUnavailable` with the language, before the model runs, and the sanitiser throws it
  too: such a description is never grounded another way. The app asks the system for the data and tells the person to try
  again in a moment.

## Layout

```
CVGeneratorAI/
├── Models/        # CVData and its parts, CVGenerationRequest, CVGenerationError, AIAvailability, limits
├── Prompt/        # CVPrompt: the fixed instructions and the prompt built from a request
├── Protocols/     # CVGenerationService
├── Services/      # FoundationModelsService, the only implementation
├── Validation/    # CVValidator (request and answer rules) and CVDataSanitizer
└── UseCases/      # CVGeneratorUseCase: check, generate, sanitize, check
```

## Usage

```swift
import CVGeneratorAI

let useCase = CVGeneratorUseCase(service: FoundationModelsService())

guard case .available = useCase.availability() else { return }

let request = CVGenerationRequest(
    userPrompt: "I'm Maria Rossi, a primary school teacher from Bologna. Since 2016 I teach at Scuola Don Milani.",
    fallbackLanguageCode: "it"
)
let cvData = try await useCase.generateCV(from: request)
```

`fallbackLanguageCode` is the app's language: the CV is written in the language of the description, and in this one
only when that language is unclear.

## Testing

```bash
swift test
```

The package builds only on Apple platforms. Tests use `FakeCVGenerationService`; the mapping of the framework's
availability and errors (`FoundationModelsServiceTests`) needs macOS 26 with the FoundationModels framework.

## Requirements

- iOS 26 / macOS 26 with Apple Intelligence for generation
- Swift 6 language mode

## License

Part of the PrestoCV app.
