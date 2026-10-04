# 0020. Import an existing CV as a draft, checked against its own text

- **Status:** Accepted
- **Date:** 2026-10-03
- **Related:** [ADR 0005](0005-remove-ai-tailoring-and-json-resume.md), [ADR 0007](0007-each-package-owns-its-model.md), [ADR 0013](0013-cv-tailoring-context.md), [ADR 0014](0014-server-modular-monolith.md), [ADR 0015](0015-inference-providers-and-data-policy.md), [ADR 0016](0016-api-contract.md), [ADR 0017](0017-hosting-storage-and-cost.md), R1, R2, R3, R4, R5, R7, R8, R11, R12, R13, issues #18, #57, #93, #133, #139, #140, #142, #155, #156, #165, #166, #167, #176, #179, #190, #192, #193, #194, #195, #196, #198

## Context

- Most users already have a CV (owner, 2026-10-02). Today the only ways to start are to type it all in or to describe it to a model. #57 asked for an import, and #192 turns that request into a design.
- AI Drafting already produces a `CVDraft` from a description with Apple's on-device model (#93), and the user reviews a draft before it becomes a CV (#18).
- A model that structures a document can invent a figure, an employer or a date. [ADR 0013](0013-cv-tailoring-context.md) holds a tailored CV to its source with a deterministic gate, because that defect costs a user the most. An imported CV must meet the same bar.
- The checks live in `CVTailoring`. R1 keeps the four context packages from importing one another. In the app, translation between contexts happens only in `PrestoCVIntegration` ([ADR 0007](0007-each-package-owns-its-model.md)). On the server, it happens only in a target that [modules.md](../modules.md) designates ([ADR 0014](0014-server-modular-monolith.md)).
- The on-device model is not on every device, and its context is small, so a long CV may not fit. The server, with the providers of [ADR 0015](0015-inference-providers-and-data-policy.md), can structure a text. The owner's rule (#192): "Images and PDFs never leave the device. Only the extracted text goes to the server, and only for that fallback."
- LinkedIn lets a member download their data as a ZIP of CSV files. Its Member Data Portability API is for later (#198).
- The owner decided on 2026-10-02 (#192):
  - that AI Drafting grows into import, and what the sources are;
  - that an import says nothing its document does not say, and that `PrestoCVIntegration` runs the check with `CVTailoring`'s content checks;
  - that structuring runs on the device first, and on the server otherwise;
  - that images and PDFs never leave the device;
  - the order of LinkedIn's routes, and that scraping never happens;
  - that JSON Resume waits until users ask for it.
- This ADR's own architecture:
  - where the extracted text, the import use cases and their ports live;
  - which target extracts, and where the camera is;
  - which target reads LinkedIn's archive;
  - how the check is made: one public entry point in `CVTailoring`, and a mapping into it on each side;
  - what happens after a failed check, and for a language the checks do not read;
  - the one rule that decides between the device and the server;
  - the server's draft job, its API and its edges.

## Decision

**The owner's decisions.**

- **AI Drafting grows into import.** Every source produces a `CVDraft`, which the user reviews (#18) before it becomes a CV. The sources are:
  - a description, as today;
  - a PDF: an old CV, or LinkedIn's "Save to PDF" of a profile (#194);
  - a photo or a scan (#194);
  - LinkedIn's data archive (#193).
- **An import says nothing the document does not say.** The draft is checked against the extracted text: its figures, names, dates and employers must appear there. `PrestoCVIntegration` runs the check with `CVTailoring`'s content checks (#139), because R1 forbids the drafting package from importing the tailoring package. A failure goes back to the model at most twice.
- **On the device first.** Text extraction always runs on the device. Structuring the text runs on the device with Apple's on-device model when it is available and the text fits (#195). Otherwise it runs on the server (#196), through the same jobs, provider policy and consent as a tailoring.
- **Images and PDFs never leave the device.** Only the extracted text goes to the server, and only for that fallback.
- **LinkedIn:** the data archive now (#193). The official Member Data Portability API comes later (#198): it needs a verified business and LinkedIn's approval, and it serves only members in the EEA. Scraping never happens: it breaks LinkedIn's terms.
- **JSON Resume** stays out until users ask for it ([ADR 0005](0005-remove-ai-tailoring-and-json-resume.md)).

**This ADR's own architecture.** The owner's decisions leave open where the pieces live and how they meet. These are consistent with [ADR 0007](0007-each-package-owns-its-model.md), [ADR 0013](0013-cv-tailoring-context.md), [ADR 0014](0014-server-modular-monolith.md), [ADR 0015](0015-inference-providers-and-data-policy.md) and [ADR 0016](0016-api-contract.md).

- **(a) Drafting grows, and its model stays its own.** `CVDrafting` stays pure Swift and Linux ✓, and gains:
  - **`ExtractedDocument`:** what extraction reads from a PDF or an image, with its structure (#194). It is a list of blocks in reading order, each a title, a paragraph, a list of items or a table of rows. It holds text only: no pixels, no coordinates, no file. It is the input of the structurer and the text the check reads. Its format is documented beside the type (#194).
  - **It is untrusted input** (R8), validated when it is made: bounded in blocks and in characters. It refuses control characters, and no text of a block holds a line break, whether it is a title, a paragraph, a list item or a table cell: the adapter ends a block at each one. The line breaks are U+000A, U+000D (alone or before U+000A), U+0085, U+2028 and U+2029. The mapping into `TailoringModel` does not split blocks. It cleans each block with `TextRules.removingHidden` before anything is read, so the checks read the text as it displays (#139). The bounds are #194's, and the server's request holds the same ones.
  - **The use case that imports a document,** `DraftFromDocument`. It validates the document, structures it through a port, checks the draft through a second port, and sends the failures back to the structurer at most twice. Then it returns the draft, or fails with every failure listed (R7). It validates the draft on every path, as `DraftCV` does. It is the one loop, for the device and for the server.
  - **A draft from an import is bounded by what a CV holds,** not by the bounds of a description's draft: a long CV has many jobs and skills. The bounds are copies of Authoring's caps, because `CVDrafting` cannot import Authoring, and a test in `PrestoCVIntegration` holds them equal. A value over a bound is a typed error that names the field, never a silent truncation (#193, #195).
  - **The ports it owns (R3):**
    - `DocumentExtracting`: the bytes of a PDF or of an image in, an `ExtractedDocument` out;
    - `DocumentStructuring`: an `ExtractedDocument` and the failures of the last attempt in, a `CVDraft` out. Both use untyped `throws`, so cancellation passes;
    - `DraftChecking`: a draft and its document in, the failures out;
    - `ArchiveReading`: an archive's bytes in, the bytes of the files that the mapping reads out.
  - **Failures are values with codes** (R7). Each names the field and what it states that the text does not. The app words them for the user (R13), and each structurer words them for its model.
  - **The mapping of LinkedIn's CSV files to a draft,** `DraftFromLinkedInArchive` (#193). It parses the CSV strictly, and bounds the number of rows and the length of a field (R8). A date such as "Jan 2020" keeps its month: a draft's dates have year or month precision.
  - **A description stays as it is** (`DraftCV`), on the device. It is the user's own words, not a document, and the review marks what the model inferred (#18). Only extracted text goes to the server.
- **(b) Extraction runs on the device, in `CVImportVision`.** It is a new target of `CVGeneratorAI` (planned, #194): an outbound adapter that implements `DocumentExtracting`.
  - #194 chooses, per PDF, between the text layer, which PDFKit reads in the order #194 chooses per PDF, and Vision. A text layer is not always in reading order, as in a two-column CV. A PDF with no text layer is a scan and goes through Vision, and so does every image. Vision's `RecognizeDocumentsRequest` (iOS 26) returns titles, paragraphs, lists and tables, so the structurer reads that structure, not flat text (#194).
  - It is Apple-only (iOS 26, macOS 26). The package's manifest declares it only on Apple hosts, as it declares `CVDraftingFoundationModels`, and every file of it is wrapped in its platform condition (R11). It imports `CVDrafting`, PDFKit and Vision, and no PrestoCV package (R1). It opens no connection.
  - **The bytes it reads are untrusted** (R8). A size cap comes first. An image's pixel dimensions are read from its header and bounded before the image is decoded. Then the pages, and the text it yields.
  - **It sits in `CVGeneratorAI`** because AI Drafting grows into import (owner), and the adapter implements a port of `CVDrafting`. A package of its own would own no model.
  - **It is a target of its own,** not part of `CVDraftingFoundationModels`. R3 puts an adapter in a target of its own, and this one imports different frameworks (PDFKit and Vision, where the other imports FoundationModels) and implements a different port. It must also work on a device that has no model: the server fallback needs the text, and the device extracts it.
  - **The camera is a view, not an adapter.** VisionKit's document camera on iOS, Continuity Camera on macOS and the file and photo pickers are view controllers and shims. They live in the app target's `Platform/` folder, which gains VisionKit, and they hand bytes to the view model's intent (R5). The adapter presents nothing.
  - **The checker learns two frameworks.** #194 adds `Vision` and `VisionKit` to the checker's list of known frameworks, with a self-test, when it creates the target's entry in `rules.json`.
- **(c) LinkedIn's data archive is read on the device, with no model.** The mapping is in `CVDrafting` (a). `CVImportArchive` is a new target of `CVGeneratorAI` (planned, #193): an outbound adapter that implements `ArchiveReading`.
  - It reads the ZIP in memory under three limits (R8): the archive's size, its uncompressed size and its number of entries. It counts the bytes it actually inflates and stops at the limit, whatever the archive's headers declare. It writes nothing to disk, so a path inside the archive is never followed.
  - It returns the bytes of the six files the mapping reads (`Profile.csv`, `Positions.csv`, `Education.csv`, `Skills.csv`, `Languages.csv`, `Certifications.csv`) and of no other. It matches names exactly and inflates nothing else, because an archive holds much that is not a CV. A missing file is not an error.
  - The six files are the owner's list. They carry no contact details, so an archive's draft has none, and the user adds them in the review.
  - **Linux ✓ is the requirement,** so that the hostile-archive tests run in the Linux job. #193 chooses the ZIP reader and proves that it builds and tests on Linux. If none does, #193 changes modules.md, says why, and makes the target Apple-only with every file wrapped in its platform condition (R11).
  - No model is involved, so nothing of the archive leaves the device, and there is nothing to check against: every value of the draft is a cell of a file.
- **(d) The check.** The owner's text says that `PrestoCVIntegration` runs it with `CVTailoring`'s content checks. This ADR gives it a single entry point.
  - **One public entry point, in `CVTailoring`.** `Provenance` publishes it for the import check (#195, on #140's readers). Given the draft's texts and fields, mapped into `TailoringModel`'s values, the extracted text, a language and `asOf`, it returns typed failures (R7). Behind it:
    - **Figures and dates.** A figure that the draft states must be one that the text states. A year alone is held as a figure, with the provenance gate's reading of stated figures, in which a year is a figure. **A date's month is held too:** the text must write that month beside the same year, as a name or an abbreviation from the language's `dates.months`, or as a numeral month in a numeric date (`06/2019`, `2019-06`, `6.2019`). A draft date with a month that the text does not write beside that year fails, like any other date that the text does not state.
    - **Names.** The gate's reader of names (#140) holds an employer, a school, a certifying body, a person, a product or a technology: one that the text does not state fails. A structured field of the draft, a company or a school, is read whole, and must appear whole in the text.
    - **Spans.** `ContentChecks` refuses an exact count of years or months that the calendar will overtake (#139), against `asOf`.
  - **Both integration layers only map.** `PrestoCVIntegration` implements `DraftChecking` in the app. It maps the draft and the extracted text into `TailoringModel`'s values, finds the language, calls the entry point with `asOf` from the injected `TimeSource` (R2), and maps the failures back into `CVDrafting`'s own. It cleans the draft's values with `TextRules.removingHidden`, as it cleans the extracted text, so a hidden character that the model copies does not end the import with a mapping error. That is a translation between two contexts, which [ADR 0007](0007-each-package-owns-its-model.md) puts there, and it touches no infrastructure, so it needs no adapter target. `ServerApplication` does the same on the server, with the injected clock. R1 and [ADR 0014](0014-server-modular-monolith.md) let a translation between two context packages on the server live in a target that [modules.md](../modules.md) designates. This ADR designates `ServerApplication` for this one.
  - **One new edge in the app.** The entry point is in `Provenance`, so `PrestoCVIntegration` gains `Provenance`, and nothing more of `CVTailoring`: it has `AdvertAnalysis`, `ContentChecks` and `TailoringModel` already. The entry point's failures reuse the gate's failure type, which names `ContentChecks` types, so a layer that maps them back needs `ContentChecks` too. `ServerApplication` gains it for that reason. It is still not `Tailoring`: the gate is not the loop, and no app target imports the loop ([ADR 0013](0013-cv-tailoring-context.md)). [modules.md](../modules.md) states the edge. `rules.json` keeps `PrestoCVIntegration`'s allow-list as it is until the workflow exists, and the checker lets it be stricter.
  - **Two mappings, one corpus.** The mappings are separate code in separate packages, as the app's and the server's mappings of a CV are. One corpus of drafts, texts and verdicts, committed once under `CVGeneratorAI/Corpus/`, outside every target, runs through both. The tests of `PrestoCVIntegration` and of `ServerApplication` read it by its path, as `ServerHTTP`'s tests read the spec ([ADR 0016](0016-api-contract.md)).
  - **What it holds.** It refuses a draft that states a figure, a name, a date or an employer that the text does not, and an exact count of years or months that the calendar will overtake. It does not see what a draft leaves out, or a true name paired with the wrong job. It also keeps #140's known gap: a technology or a name that is written in lower case, or that opens a sentence, passes. The review covers these (#18).
  - **A failure goes back to the model at most twice** (owner). Then the import fails with every failure listed, and no draft reaches the user. The owner fixes the retries, and this ADR fixes the end, as [ADR 0013](0013-cv-tailoring-context.md) does for a tailoring.
  - **Languages.** The word lists are per language, one file each ([ADR 0013](0013-cv-tailoring-context.md)). A text in a language that has a file is checked. A text in any other language is a typed error, never an unchecked pass.
  - **Both sides find the language the same way, inside `CVTailoring`:** `AdvertAnalysis`'s detection (#138). It refuses a text that does not read as a language with a file: the share of the detected language's stopwords must reach a threshold that #195 sets and tests on the shared corpus. The corpus holds texts in German, Spanish, French, Italian and Portuguese, and they are refused while English is the only file. #138 notes that an advert in another language reads as English today, and #152's mismatch decision can use the same refusal. `PrestoCVIntegration` has the edge to `AdvertAnalysis` already, and `ServerApplication` gains it.
- **(e) The device or the server is one rule.** It is a pure function in `PrestoCVIntegration`, tested as a table of cases, and documented where it is made (#195).
  - It takes whether the on-device model is available, how much of its context the text takes, and a reserve for the draft. It answers the device or the server.
  - The availability port of `CVDrafting` reports the model's room and measures a text against it, as numbers of the consumer's language (R3). No framework type leaves the adapter.
  - **Availability and fit decide, and so does what the structurer reports of them.** A structurer's error that means the text did not fit, or that the model is unavailable, feeds the same rule: the import goes to the server, with consent. Only a failed check ends an import, and it does not move to the server.
  - **Consent comes first** (#190). When the rule says "server", the workflow needs the user's consent to the policy's current version, through a consent port that `PrestoCVIntegration` owns (R3). Without it, nothing leaves the device, and the import ends with a typed outcome that the app words (R13).
  - **#195 builds with fakes.** It declares the draft job's port and the consent port in `PrestoCVIntegration`, and fakes both in its tests. #196 implements the draft job's port in `PrestoCVAPIAdapter`, and #190 implements the consent. So #195 does not wait for #190 or #196: the fakes stand in.
  - A view, a view model or an adapter never decides (R5).
- **(f) The server's draft job** (#196) is a new job kind, `draft`, in `ServerApplication`, beside the tailoring.
  - **Its lifecycle is a tailoring's:** the same states, the same queue, where a task carries the job's ID and nothing else, and the same erasure, on the app's confirmation and 24 hours after the job ends at the latest ([ADR 0017](0017-hosting-storage-and-cost.md)). The job holds the extracted text and its result, and both go with it. It starts under an idempotency key, and only its owner reads it. The worker's route runs either kind.
  - **It has its own quota:** its own counts and its own limits, per device and for everyone, in configuration. The owner sets the hosted defaults (#165, #196). The credit limit of the hosted router's key is shared, and bounds both kinds of work ([ADR 0017](0017-hosting-storage-and-cost.md)).
  - **It goes through the same registry and policy** ([ADR 0015](0015-inference-providers-and-data-policy.md)). `ServerInference` implements `DocumentStructuring` over the registry's selection and fallback, so the first available provider that meets the policy answers. The adapter holds the draft's versioned prompt and schema, and decodes the model's reply through one anti-corruption layer (R8). It never logs the text or the reply. The model a draft uses is configuration, as a tailoring's is (#155). The job records the prompt's version, and the result names providers and models only by alias ([ADR 0016](0016-api-contract.md)).
  - **It has the same consent.** A start carries the policy version that the app showed the user. Start refuses another one, the job records it, and the worker refuses to run it under another ([ADR 0015](0015-inference-providers-and-data-policy.md)).
  - **The API.** `POST /v1/drafts`, `GET /v1/drafts/{id}` and `DELETE /v1/drafts/{id}` are additive to v1 ([ADR 0016](0016-api-contract.md), (f)). A start carries the headers that a tailoring's start carries. Its body holds an `ExtractedDocument`, bounded as the type is, and nothing else of the document. `DELETE` cancels a draft and confirms that the app has saved its result, as a tailoring's does. `ServerHTTP` validates a request into an `ExtractedDocument`, and a test proves that the spec's bounds equal the type's.
  - **The check runs on the server** (d), inside the same loop of `CVDrafting`. It is a gate on both sides.
  - **The app does not check again a draft that the server returns. That is this ADR's choice.** A field app can hold older word lists than the server, so it could refuse what the server accepts. It cannot send failures back to a model, so a refusal could only end the import.
  - **Only an `ExtractedDocument` can go.** In the app, a port that `PrestoCVIntegration` owns (R3) carries the draft job: start, read, cancel and confirm, in the drafting model and typed errors. Cancel and confirm are the same `DELETE`. The port takes an `ExtractedDocument` and nothing else, so an image or a PDF cannot be sent by mistake. `PrestoCVAPIAdapter` implements it. The app runs no loop on this path: it starts the job, reads it and ends it.
  - **The edges are planned** (#196). All of them reach Linux ✓ targets, and none reaches `PrestoCVApp` or `PrestoCVCore`:
    - `ServerApplication` imports `CVDrafting`, `ContentChecks`, `Provenance` and `AdvertAnalysis`;
    - `ServerInference`, `ServerHTTP`, `ServerStorePostgres` and the `PrestoCVServer` executable import `CVDrafting`: the first implements its port, the second maps the API's types to its model, the third builds its rows from it (R12), and the fourth wires its ports;
    - `PrestoCVAPIAdapter` imports `CVDrafting`.
  - [ADR 0014](0014-server-modular-monolith.md) already authorised the edge to `CVDrafting`. R1's rule that only `ServerHTTP` and `PrestoCVAPIAdapter` translate the API's types now covers the drafting model as well as the tailoring model.
- **(g) Composition and review.**
  - `PrestoCVComposition` creates `CVImportVision`, `CVImportArchive` and the structurer (R4). The checker's `infrastructureTypes` lists their types once they exist.
  - `DraftCVWithAI` grows into the import workflow. As today, it returns an unsaved CV with its gaps. For a document, it also returns the extracted text and, for each field of the draft, the blocks of the text behind it, or none. The workflow finds them, and the view model only presents them (R5). The review (#18) marks the fields that have none, and shows the blocks behind a field. The text lives for the review and is not saved.
- **Left to the tickets:**
  - the bounds of `ExtractedDocument` and of an archive (#193, #194), and the format of the extracted text (#194);
  - the ZIP reader (#193);
  - the entry point's exact signature, and the detection's refusal of a language without a file (#195, #140, #138);
  - how the workflow finds the blocks behind a field (#18, #195);
  - the hosted defaults of the draft quota (#165, #196);
  - the draft job's prompt and schema (#196).

## Consequences

- **What becomes possible:**
  - a user with no CV in the app reaches a reviewed CV from a LinkedIn archive, a PDF or a scan, with little typing (#57);
  - no figure, name, date or employer that the document lacks reaches the review;
  - one draft, one review and one retry loop serve every source, on the device and on the server;
  - an image or a PDF stays on the device, by the type of the port that reaches the server.
- **R1 and R8 change.** R1's rules for the API's generated types name the drafting model as well as the tailoring model, and it names the one translation between two context packages that modules.md designates on the server. R8 lists imported documents, and the text extracted from them, among untrusted input.
- **modules.md lists `CVImportVision` and `CVImportArchive`,** and the edges of (d) and (f): `Provenance` for `PrestoCVIntegration`, and `CVDrafting` for `ServerApplication`, `ServerInference`, `ServerHTTP`, `ServerStorePostgres`, `PrestoCVServer` and `PrestoCVAPIAdapter`, with `ContentChecks`, `Provenance` and `AdvertAnalysis` for `ServerApplication`. The checker's `rules.json` declares the two new targets not yet implemented, and keeps the allow-lists of the targets that exist as they are. The checker lets `rules.json` be stricter than modules.md. The glossary gains **Import** and **Extracted text**.
- **Costs:**
  - **Extraction is Apple-only.** It needs iOS 26 or macOS 26, and a Linux backend cannot extract. That is acceptable, because extraction always runs on the device.
  - **OCR quality bounds a scan's draft.** A draft cannot correct a misread name, because the corrected name is not in the text. The check refuses it, so the draft keeps the misreading and the user corrects it in the review.
  - **The check is a gate on what a draft states.** It does not see what a draft omits, or a true employer paired with the wrong dates. The review is where the user catches both.
  - **The spans rule can refuse a faithful sentence.** An exact count such as "5 years of experience" is refused because the calendar will make it false, even when the document says it. The failure goes back to the model, which can write it as a floor ("5+ years"). The rule stays ([ADR 0013](0013-cv-tailoring-context.md), #139).
  - **Languages wait for their files.** A document in a language without a word-list file cannot be imported. Only English ships today, so a text in German, Spanish, French, Italian or Portuguese is refused until its file lands, and German's waits for #142. The user can still describe the CV.
  - **A second job kind** means a second quota, a second prompt and schema to keep, and more endpoints. The evaluation harness reports on drafts too (#156), and a prompt change needs a run of it before it ships.
  - **Consent before any text leaves the device** (#190). A user who declines gets no import on a device that has no model, or for a text that does not fit.
  - **Two mappings of the check** exist, one in each integration layer, onto one entry point. The shared corpus holds them equal.
  - **LinkedIn can change its archive without notice.** The fixtures are invented archives in the format as it is today. A change is found when an import comes out thin or fails, and the documentation test keeps the supported columns honest.
  - **A third-party ZIP reader, if #193 uses one,** is declared in `CVGeneratorAI`'s manifest. A server that imports `CVDrafting` may then resolve it and pin it in its `Package.resolved`, and builds none of it.
  - **The order of the tickets.** #195 builds the entry point on #140's readers, so it waits for #140 as well as for #139. #196 waits for #195.
  - **The app's `Platform/` folder grows** by the capture shims, which hold no rule.
- **Enforced by:**
  - the compiler, through the target graph:
    - `CVDrafting` imports Foundation only, so it cannot reach `CVTailoring`, PDFKit or Vision. `CVImportVision` and `CVImportArchive` import `CVDrafting` and no PrestoCV package;
    - the port that reaches the server takes an `ExtractedDocument`, so an image or a PDF cannot be sent;
  - the checker, once the targets exist:
    - the allow-lists of [modules.md](../modules.md), and `--packages` for the manifests (R1). They keep the loop off the device, so `Provenance` is the one edge added, and no app target imports `Tailoring` ([ADR 0013](0013-cv-tailoring-context.md));
    - the Linux CI job builds `CVGeneratorAI` with `CVImportVision` declared only on Apple hosts, and the macOS job builds it. R11's detector keeps platform conditions out of `CVDrafting` and `PrestoCVIntegration`. That every file of the adapter is wrapped in its platform condition is held by review, as for the other Apple-only adapters;
    - R2's detectors on `CVDrafting`, `PrestoCVIntegration` and `ServerApplication`, so the check reads its date from the injected time source;
    - R4's detectors on the adapters, with their types in `infrastructureTypes`;
    - R7's `swallowedError`, and R13's `localization` outside the app target, so the failures stay codes;
  - tests:
    - #193: a complete, a partial and a hostile archive, each tested, with the limits, the bytes actually inflated and no file written to disk. CSV rows and fields over their bounds, and a value over a bound, give a typed error that names the field. The supported files and their columns are documented beside the parser, and a test fails if the parser reads a column that the documentation does not name;
    - #194: invented PDFs and images, a two-column CV and a scan among them, an image whose header declares dimensions over the bound and is refused before it is decoded, a block that ends at each of the five line breaks and a text that holds one refused by `ExtractedDocument`, and the format of `ExtractedDocument` documented;
    - #195: the entry point in `CVTailoring`'s tests, with drafts that add a figure, a name, a date, a month or an employer, and a faithful draft that passes. A month is held beside its year in each written form: a name, an abbreviation, and the numerals `06/2019`, `2019-06` and `6.2019`. The threshold of the language detection, on the shared corpus, with texts in German, Spanish, French, Italian and Portuguese refused. A hidden character that the model copies does not end the import. The mapping of each integration layer, exhaustively. A scripted structurer, covering a pass, a retry, a failure after two retries, a text too long for the device, and an error that means "did not fit". The table of the device-or-server rule. A workflow test that, with consent declined, the server's port is never called, with the fakes of the draft job's port and the consent port;
    - #196: the draft job kind tested like tailorings are: the contract suites, idempotency, ownership, expiry, deletion, cancel and the quota. The spec's bounds equal the type's. The router and adapter tests. The evaluation harness (#156);
    - the corpus of drafts, texts and verdicts under `CVGeneratorAI/Corpus/`, read by the tests of `PrestoCVIntegration` and of `ServerApplication`;
  - review:
    - that no view or shim holds a rule (R5);
    - that every file of `CVImportVision`, and of `CVImportArchive` if it ends up Apple-only, is wrapped entirely in its platform condition (R11);
    - that no other port of the app carries a document's bytes off the device, and that the extraction adapters open no connection. Foundation allows a `URLSession`, so only review sees it;
    - that translation between the drafting and the tailoring models stays in the designated targets: `PrestoCVIntegration` and `ServerApplication`. `PrestoCVAPIAdapter`, `ServerHTTP`, `ServerInference`, `ServerStorePostgres` and `PrestoCVServer` may each import both, and the allow-lists cannot tell a mapping of the API from a translation between the contexts;
    - that no provider name or model identifier enters the draft's prompt, its tests or its documentation ([ADR 0015](0015-inference-providers-and-data-policy.md)).

## Alternatives considered

- **Scraping LinkedIn.** Rejected by the owner: it breaks LinkedIn's terms.
- **Sending a PDF or an image to the server.** Rejected by the owner: images and PDFs never leave the device. Only the extracted text goes, and only for the fallback.
- **Importing straight into a CV, without review.** Rejected: every draft meets the review of #18, which exists so that the user sees what a model inferred.
- **A separate import context.** Rejected: every source produces the same draft and meets the same review, so AI Drafting grows, as the owner decided.
- **JSON Resume.** Rejected by the owner until users ask for it ([ADR 0005](0005-remove-ai-tailoring-and-json-resume.md)). If they do, it is one more source of drafts, so it needs no new context.
- **Copying the content checks into `CVDrafting`.** Rejected: a rule exists once, in `CVTailoring`, and R1 forbids the import.
- **A shared package of checks that both contexts import.** Rejected: [ADR 0007](0007-each-package-owns-its-model.md) has no shared kernel.
- **A check that warns and lets the user override it.** Rejected, as [ADR 0013](0013-cv-tailoring-context.md) rejects it for a tailoring: an import that states what its document does not is the defect the check exists to prevent.
- **After two retries, dropping what fails and sending the rest to the review, marked.** Rejected: the owner's rule is that an import says nothing the document does not say, and a draft that states a figure or a name the text lacks would reach the user.
- **Falling back to the server when the device's check fails.** Rejected: a text leaves the device only in the case the owner names, and with consent. A second model does not make a text say what it does not.
- **Extraction on the server, or in a hosted OCR service.** Rejected by the owner: images and PDFs never leave the device.
- **Reading the archive on the server.** Rejected: only the extracted text goes to the server (owner), and no model is involved here, so nothing of an archive, which holds far more than a CV, needs to leave.
- **One target for extraction and the on-device structurer.** Rejected: R3 asks for a target per adapter, the frameworks and the ports differ, and extraction must work on a device that has no model.
