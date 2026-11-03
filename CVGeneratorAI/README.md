# CVGeneratorAI

Drafts the fields of a CV from a person's own description, on the device, with Apple's FoundationModels.

This is the legacy generator that the app ships in v1 (ADR 0012). The `CVDrafting` targets
are its planned replacement and are still empty.

## What it does

- **The facts are what the person said.** The model fills a small schema (`CVData`) in which every detail is optional.
  The instructions forbid inventing any fact, and `CVDataSanitizer` enforces it afterwards by checking every retained
  fact against the description. The rules are conservative by construction: a token that could be read two ways is
  not accepted.
  - Contact details (email, link, phone) must be whole tokens of the description. A token is a run between white
    space, brackets and quotes, without the punctuation that ends a sentence; an address is never taken out of a
    larger token. They may differ only in case, in a link's scheme, `www.` and trailing slash (its query and
    fragment count), and in a phone's separators and `+` or `00` prefix.
  - Names (people, employers, schools, titles, places, certifications, skills, interests) must occur in it as a
    contiguous phrase of whole words, ignoring case and accents. An entry with nothing identifying left is dropped.
  - Prose (summary, descriptions, achievements) keeps only the sentences that state no contact detail or number the
    description lacks, and achievements are quotes (the summary and the role descriptions also keep the plain sentences
    below). Numbers are compared with their separators and with every Unicode digit read as 0-9, so `35`,
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
  - Words are read in the description's language. A word that is an employer preposition, a negation or a hedge in another
    of the six languages, and another word in the description's, is that other word: French "j'ai" holds no Italian "ai",
    English "per shift" no Italian "per", German "seit Mai" no Italian "mai" (never). A word of another language that the
    description's language does not have keeps its meaning.
  - Skills, interests, languages and the person's headline title and place count only in a clause of the person that claims
    them. A clause that denies, doubts, wishes or supposes ("I have never used Python", "I would like to work as a nurse in
    Turin", "I'd like to", "I'd work", "Ich würde", "Ich hätte gern", "Sarei", "Me encantaría", "Sogno di", "If I had time,
    I would play chess") claims nothing, and so does a clause that depends on it, or that states nothing as a fact before it
    ("Spanisch zu lernen, davon träume ich"); "can", "mostly" and "partly" still claim ("I can speak French"), and a
    negation that governs a high level denies only the level ("I am not an expert in Swift" keeps Swift), while one of a
    low level or of the ability denies the item ("I have no basic knowledge of German", "I cannot speak German even at a
    basic level"). A question claims nothing ("Do I speak French?"), nor do the words inside quotation marks (a mark at the
    end of a line opens a quote on the next one; a single mark after a letter or a digit may be an apostrophe, "patients'
    records", "un po'", and closes none: a quote that only such a mark may close, or only a mark that a quote inside it took,
    runs to the end of its line), nor the line
    after a colon line that another person speaks ("My colleague wrote:"), nor what follows a relative that brings in
    another subject ("I work with a colleague who speaks French"); "which I use", "che uso", "tengo que hablar" and an item
    before the relative still claim, and a word that only ends like an infinitive keeps no person ("qui prépare", "che
    appare"). "plan", "plans" and "planning" withdraw only as verbs ("I am planning to learn Rust"), not as nouns ("route
    planning", "care plans", "einen Plan erstellt"); an intention said by a phrase withdraws like a wish ("Ho intenzione
    di", "J'ai l'intention d'", "Ich plane", "Ich habe vor, …").
  - A skill that is also one of the draft's interests, and that the person mentions only as leisure ("In my free time I like
    chess and hiking"), is a hobby, and is dropped; the interest stays. A skill the person claims anywhere else ("proficient
    in Python", a job's clause, a list of skills) stays. Another person's clause ("My sister teaches chess") counts for
    neither.
  - An employer or a school loses a leading indefinite article written in lower case ("a nursery" is "nursery"); an article
    with a capital is part of a name ("UNA Hotels").
  - A degree that only says graduating ("diplôme", "Abschluss", "laurea" or "my degree" alone) is dropped; the school stays.
- **Written around the facts (ADR 0031).** When the draft keeps a fact about the person (a title, a job or a school), the
  model also writes, in the language of the description, a summary of 2 to 4 sentences, the responsibilities typical of
  each job's title, and skills of two kinds (`Skill.kind`): technologies (tools, software, methods) and soft skills. With
  no such fact it writes nothing around it, and the draft is judged on its facts: "this is a test of the app" gives
  `emptyResult`.
  - A sentence of the summary or of a role description that quotes nothing stays only when it is plain (`WrittenText`): in
    the language of the description, with no address, no number in digits or words, no month, no negation, no word of
    duration, seniority or level that the description does not write, no word that the description holds only where the
    person claims nothing (another person's clause, a wish, a denial), for a job no word of another job's title or
    employer, and no name. A name is a capital after the first word, a word of capitals, or a word that neither the closed
    vocabulary nor the device's dictionary knows; in German, where every noun has a capital, a word the device tags as a
    name (`NLTagger`, `nameType`) or one the vocabulary and the dictionary do not know as written. The person's title and
    the titles and degrees of the draft are no names. A summary that keeps no sentence is nil.
  - The dictionary is the port `WordList`: `DeviceWordList` (`UITextChecker` on iOS, `NSSpellChecker` on macOS) in the
    app. Where the device has no dictionary of a language, the other rules still apply.
  - A skill the description names is a fact and follows the rules above. One it does not name is inferred and stays
    (`InferredSkills`) without a level, as a name of at most 4 words and 40 characters with no digit, no word of level,
    duration or seniority the description does not write, no language, no word of a qualification, no employer, school,
    place, person or interest of the draft, and no word the description holds only where the person claims nothing. The
    draft keeps at most 8 technologies and 5 soft skills, the named ones first, and no skill twice.
- **A second check of the personal items (ADR 0028).** After the rules, the on-device model reads the description again
  and judges each skill the description names, each language, interest, the headline title and the place that the
  grounded draft still keeps (an inferred skill is no candidate): whose it
  is (the writer's, someone else's, or not mentioned) and how the description states it (as true, wished, conditional or
  denied). An item stays only when it is the writer's and stated as true, so the check can only withdraw; a language's
  level goes with its language. It asks the model (`FoundationModelsClaimChecker`) in batches of at most 8 items, one
  after the other, with a fixed instruction, greedy sampling and structured output, and it reads the answer with
  `ClaimAnswer`: the items must be numbered 1 to n, each once, and an item is a fact only when the model quotes words of
  the description that contain it, otherwise it is withdrawn. Employers, schools, dates and prose stay with the rules.
  When the check gives no answer (a failed call, a refusal of the model's guardrail, an answer that does not number its
  items 1 to n, or no end within its 60 seconds, `ClaimCheckLimits`), the draft keeps its jobs, schools, dates and
  prose, every item of the five kinds is withdrawn (the inferred skills too), and `GeneratedDraft.personalItemsUnchecked` is true, so that the app
  can ask the person to add them; there is no retry and no fallback to the rules alone. Such a draft may be empty, and
  is still a draft. Cancellation passes through.
- **The order of a CV.** The use case lists the jobs that go on now first, then the others by their latest year (the end,
  else the start), the newest first, as the grounded draft gives the years. A job with no year keeps its place among the
  others, and so do jobs of the same year.
- **On device.** The request, the description and the answer never leave the device.
- **Typed outcomes.** Failures are `CVGenerationError` cases that the app explains in the person's language;
  cancellation is `CancellationError`, never an error case. Availability is an `AIAvailability` value with the reason
  when the model cannot run (device not eligible, Apple Intelligence off, model not ready).
- **Language data.** The verbs of English and German are read from the device's lexical class (`LexicalTagger`, the
  device's `DeviceLexicalTagger` in the app), which the device has once it has downloaded the language's data. Without
  it, `generateCV` throws `languageDataUnavailable` with the language, before the model runs, and the sanitiser throws it
  too: such a description is never grounded another way. The app asks the system for the data and waits for it for 60
  seconds at most, with the screen saying so; when the data comes it generates once more, and when it does not it tells
  the person the other ways to write the CV.

## Layout

```
CVGeneratorAI/
├── ClaimCheck/    # ClaimChecking, the candidates of a draft, the withdrawal, FoundationModelsClaimChecker
├── Models/        # CVData and its parts, GeneratedDraft, CVGenerationRequest, CVGenerationError, AIAvailability, limits
├── Prompt/        # CVPrompt: the fixed instructions and the prompt built from a request
├── Protocols/     # CVGenerationService
├── Services/      # FoundationModelsService, the only implementation
├── Validation/    # CVValidator (request and answer rules), CVDataSanitizer, WrittenText, InferredSkills, WordList
└── UseCases/      # CVGeneratorUseCase: check, generate, sanitize, check the claims again, order the jobs (JobOrder), check
```

## Usage

```swift
import CVGeneratorAI

let useCase = CVGeneratorUseCase(service: FoundationModelsService(), claimChecker: FoundationModelsClaimChecker())

guard case .available = useCase.availability() else { return }

let request = CVGenerationRequest(
    userPrompt: "I'm Maria Rossi, a primary school teacher from Bologna. Since 2016 I teach at Scuola Don Milani.",
    fallbackLanguageCode: "it"
)
let draft = try await useCase.generateCV(from: request)
// draft.cvData is the grounded and checked CV; draft.personalItemsUnchecked says that the second check gave no answer.
```

`fallbackLanguageCode` is the app's language: the CV is written in the language of the description, and in this one
only when that language is unclear.

## Testing

```bash
swift test
```

The package builds only on Apple platforms. Tests use `FakeCVGenerationService` and `FakeClaimChecker`; the mapping of
the framework's availability and errors (`FoundationModelsServiceTests`) needs macOS 26 with the FoundationModels
framework.

`ClaimCheckEvaluation` runs the second check on the real model, only when asked, on a Mac with Apple Intelligence on. It
measures the contract (a), the adversarial set (b), the held-out set of the spike (c), the held-out set written after
the instruction was frozen (d) and drafts of 22, 32 and 42 personal items (e), three times each. It fails on verdicts
that differ between runs, and on any item that the draft keeps although the description does not claim it (a false
keep):

```bash
PRESTOCV_CLAIM_EVAL=abcde PRESTOCV_CLAIM_EVAL_OUT=/tmp/claim-eval swift test --filter ClaimCheckEvaluation
```

By default it runs the path of the product: the rules, then the check of what they keep. `PRESTOCV_CLAIM_EVAL_MODE=alone`
judges every listed item without the rules, as when the instruction is tuned; then a false keep of the contract is only
measured, since the rules drop those items before the check.

### The drafting evaluation

`DraftingEvaluation` runs the whole path of the app on the real model: the model drafts each of 30 descriptions (the 6
example descriptions of the app and four written ones per language: a plain one, one with sentences that look like facts
and are not, a sparse one of a title and a few words, and one that names no role), `CVDataSanitizer` grounds the draft,
the claim check judges its personal items, and `InventedFacts` counts what the result keeps, loses and invents. A skill
that is no phrase of the description is counted as inferred, not invented, unless a trap of the input holds it or it is a
language, a qualification or a name. `WrittenMeasure` and `WrittenCounts` measure what the draft writes around the facts
against the thresholds of ADR 0031: a summary, a description on each kept job, technologies and soft skills by kind, the
written sentences in the description's language, the tools of another trade (each input's `offField` words) and the time
at the 95th percentile. It needs a Mac with Apple Intelligence on, and it runs only when asked:

```bash
PRESTOCV_DRAFT_EVAL=1 PRESTOCV_DRAFT_EVAL_REV=$(git rev-parse --short HEAD) swift test --filter DraftingEvaluation
```

| Variable | Meaning |
| --- | --- |
| `PRESTOCV_DRAFT_EVAL` | The switch. Unset, empty, `0`, `false`, `no` and `off` are off; anything else is on. |
| `PRESTOCV_DRAFT_EVAL_RUNS` | Runs of every input. 3 by default; a whole number of at least 1. |
| `PRESTOCV_DRAFT_EVAL_OUT` | The folder of the run set. It must be absent or empty: a second invocation never adds to the files of the first. By default a new folder `draft-<revision>-<date>-<time>` in the temporary directory. |
| `PRESTOCV_DRAFT_EVAL_REV` | The revision under test. Without it the revision is `unknown`, and the set is never GO. |
| `PRESTOCV_DRAFT_EVAL_ONLY` | Comma-separated input ids, for a re-run after a fix. The set is then partial, and never GO. |
| `PRESTOCV_DRAFT_EVAL_READY` | The folder of a finished run set, to check whether it is GO (below). Needs no model and runs on any host. |

The folder holds `manifest.json` (written before the first run and updated after each one), `<input>-run<n>.json` (the
model's draft, the grounded draft, the final draft, the calls of the claim check, the seconds and the load), `summary.json`,
`summary.txt` and `review.json`. A set that stopped halfway has no summary, and cancelling the test writes none.

- **A pass is "no hard finding", not GO.** The first line of `summary.txt` says which. The test fails on a field the counter
  proves invented, on a tool of another trade or anything written around a description with no role, on a run that threw, was refused (`contentNotAllowed`) or whose claim check gave no answer (the cause is
  recorded), and on an example that loses its name, its title or a job. Fields the counter can only send to review (prose,
  and a word that may be a skill, a language or a hobby) cannot fail the test; they go to `review.json`, once per input and
  value, with the entry that owns them.
- **GO needs a reading.** A person reads `review.json`, which also lists each distinct final draft that writes around the
  facts once, for its pertinence to the role and the field, and records the decision on every item in `adjudication.json` beside
  it: `{"reviewer": "...", "revision": "...", "entries": [{"key": "...", "decision": "accept" | "reject", "note": "..."}]}`.
  `PRESTOCV_DRAFT_EVAL_READY=<folder> swift test --filter DraftingReadiness` then fails with every reason the set is not GO: a
  hard finding, a missed threshold, a partial or unfinished set, an unrecorded revision, an item nobody decided, a decision of another revision, or
  a rejected item.
- **The sample is smaller than the runs.** The model runs with greedy sampling, so the runs of an input are the same draft.
  `summary.txt` says how many distinct drafts the set holds; the counts are over runs and the times stay valid.

The measure, the summary, the review items and the folder rules are plain code with tests that run everywhere
(`DraftingMeasure`, `DraftingSummary`, `DraftingReview`, `DraftingRunFolder`); only the file that calls the model is gated.

## Requirements

- iOS 26.5 / macOS 26 with Apple Intelligence for generation
- Swift 6 language mode

## License

Part of the PrestoCV app.
