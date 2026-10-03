# 0020. Import an existing CV as a draft, checked against its own text

- **Status:** Accepted
- **Date:** 2026-10-03
- **Related:** [ADR 0005](0005-remove-ai-tailoring-and-json-resume.md), [ADR 0007](0007-each-package-owns-its-model.md), [ADR 0013](0013-cv-tailoring-context.md), [ADR 0014](0014-server-modular-monolith.md), [ADR 0015](0015-inference-providers-and-data-policy.md), [ADR 0016](0016-api-contract.md), [ADR 0017](0017-hosting-storage-and-cost.md), R1, R2, R3, R5, R7, R8, R11, R13, issues #18, #57, #93, #133, #139, #140, #156, #190, #192, #193, #194, #195, #196, #198

## Context

- Most users already have a CV (owner, 2026-10-02). Today the only ways to start are to type it all in or to describe it to a model. #57 asked for an import, and #192 turns that request into a design.
- AI Drafting already produces a `CVDraft` from a description with Apple's on-device model (#93), and the user reviews a draft before it becomes a CV (#18).
- A model that structures a document can invent a figure, an employer or a date. [ADR 0013](0013-cv-tailoring-context.md) holds a tailored CV to its source with a deterministic gate, because that defect costs a user the most. An imported CV must meet the same bar.
- The checks live in `CVTailoring`. R1 keeps the four context packages from importing one another. In the app, translation between contexts happens only in `PrestoCVIntegration` ([ADR 0007](0007-each-package-owns-its-model.md)). On the server, it happens only in a target that [modules.md](../modules.md) designates ([ADR 0014](0014-server-modular-monolith.md)).
- The on-device model is not on every device, and its context is small, so a long CV may not fit. The server, with the providers of [ADR 0015](0015-inference-providers-and-data-policy.md), can structure a text. A CV is personal data, so a PDF or an image must stay on the device.
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
  - how the check is made on each side, and the one new edge it needs in the app;
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
  - **It is untrusted input** (R8), validated when it is made: bounded in blocks and in characters, and refusing control characters. The bounds are #194's, and the server's request holds the same ones.
  - **The use case that imports a document,** `DraftFromDocument`. It validates the document, structures it through a port, checks the draft through a second port, and sends the failures back to the structurer at most twice. Then it returns the draft, or fails with every failure listed (R7). It validates the draft on every path, as `DraftCV` does. It is the one loop, for the device and for the server.
  - **The ports it owns (R3):**
    - `DocumentExtracting`: the bytes of a PDF or of an image in, an `ExtractedDocument` out;
    - `DocumentStructuring`: an `ExtractedDocument` and the failures of the last attempt in, a `CVDraft` out. Both use untyped `throws`, so cancellation passes;
    - `DraftChecking`: a draft and its document in, the failures out;
    - `ArchiveReading`: an archive's bytes in, the bytes of the files that the mapping reads out.
  - **Failures are values with codes** (R7), like the provenance gate's. Each names the field and what it states that the text does not. The app words them for the user (R13), and each structurer words them for its model.
  - **The mapping of LinkedIn's CSV files to a draft,** `DraftFromLinkedInArchive` (#193). It parses the CSV strictly and within bounds (R8). A date such as "Jan 2020" becomes a partial date, so a draft's dates grow from a year to a year or a month.
  - **A description stays as it is** (`DraftCV`), on the device. It is the user's own words, not a document, and the review marks what the model inferred (#18). Only extracted text goes to the server.
- **(b) Extraction runs on the device, in `CVImportVision`.** It is a new target of `CVGeneratorAI` (planned, #194): an outbound adapter that implements `DocumentExtracting`.
  - PDFKit reads a PDF's text layer in reading order. A PDF with no text layer, and every image, go through Vision's `RecognizeDocumentsRequest` (iOS 26), which returns titles, paragraphs, lists and tables. The structurer reads that structure, not flat text (#194).
  - It is Apple-only (iOS 26, macOS 26), and every file is wrapped in its platform condition (R11). It imports `CVDrafting`, PDFKit and Vision, and no PrestoCV package (R1). It opens no connection.
  - **It sits in `CVGeneratorAI`** because AI Drafting grows into import (owner), and the adapter implements a port of `CVDrafting`. A package of its own would own no model.
  - **It is a target of its own,** not part of `CVDraftingFoundationModels`, because extraction must work on a device that has no model: the server fallback needs the text, and the device extracts it.
  - **The camera is a view, not an adapter.** VisionKit's document camera on iOS, Continuity Camera on macOS and the file and photo pickers are view controllers and shims. They live in the app target's `Platform/` folder, which gains VisionKit, and they hand bytes to the view model's intent (R5). The adapter presents nothing.
- **(c) LinkedIn's data archive is read on the device, with no model.** The mapping is in `CVDrafting` (a). `CVImportArchive` is a new target of `CVGeneratorAI` (planned, #193): an outbound adapter that implements `ArchiveReading`.
  - It reads the ZIP in memory under three limits (R8): the archive's size, its uncompressed size and its number of entries. It writes nothing to disk, so a path inside the archive is never followed.
  - It returns the bytes of the six files the mapping reads (`Profile.csv`, `Positions.csv`, `Education.csv`, `Skills.csv`, `Languages.csv`, `Certifications.csv`) and of no other. It matches names exactly and inflates nothing else, because an archive holds much that is not a CV. A missing file is not an error.
  - **Linux ✓ is the requirement,** so that the hostile-archive tests run in the Linux job. #193 chooses the ZIP reader and proves that it builds and tests on Linux. If none does, #193 returns to this file, and the target becomes Apple-only with every file wrapped in its platform condition (R11).
  - No model is involved, so nothing of the archive leaves the device, and there is nothing to check against: every value of the draft is a cell of a file.
- **(d) The check.**
  - **On the device,** `PrestoCVIntegration` implements `DraftChecking`. That is a translation between two contexts, which [ADR 0007](0007-each-package-owns-its-model.md) puts there, and it touches no infrastructure, so it needs no adapter target. It maps the draft and the extracted text into `CVTailoring`'s types, and runs `ContentChecks`: the figures as the CV writes them, and the spans that stay true, against a date passed in from the injected `TimeSource` (R2, #139). It also runs the reading of names that the provenance gate uses (#140), so an employer, a school or a technology that the text does not state fails.
  - **One new edge.** The reader of names is the gate's, in `Provenance`. So `PrestoCVIntegration` gains `Provenance`, and nothing more of `CVTailoring`. It is still not `Tailoring`: the gate is not the loop, and no app target imports the loop ([ADR 0013](0013-cv-tailoring-context.md)). [modules.md](../modules.md) states the edge. `rules.json` keeps `PrestoCVIntegration`'s allow-list as it is until the workflow exists, and the checker lets it be stricter.
  - **On the server,** `ServerApplication` implements `DraftChecking` the same way. R1 and [ADR 0014](0014-server-modular-monolith.md) let a translation between two context packages on the server live in a target that [modules.md](../modules.md) designates. This ADR designates `ServerApplication` for this one: a draft and its text, into the content checks and the reading of names.
  - **Two mappings, one corpus.** They are separate code in separate packages, as the app's and the server's mappings of a CV are. One corpus of drafts, texts and verdicts, committed once, runs through both: each package's tests read it by its path, as `ServerHTTP`'s tests read the spec ([ADR 0016](0016-api-contract.md)).
  - **What it holds.** It refuses a draft that states a figure, a name, a date or an employer that the text does not, and an exact count of years or months that the calendar will overtake. It does not see what a draft leaves out, or a true name paired with the wrong job. The review covers both (#18).
  - **A failure goes back to the model at most twice** (owner). Then the import fails with every failure listed, and no draft reaches the user. The owner fixes the retries, and this ADR fixes the end, as [ADR 0013](0013-cv-tailoring-context.md) does for a tailoring.
  - **Languages.** The word lists are per language ([ADR 0013](0013-cv-tailoring-context.md)). A text in one of the six languages is checked. A text in any other language is a typed error, never an unchecked pass. German is one until #142 reads its names. How the text's language is found is #195's.
- **(e) The device or the server is one rule.** It is a pure function in `PrestoCVIntegration`, tested as a table of cases, and documented where it is made (#195).
  - It takes whether the on-device model is available, how much of its context the text takes, and a reserve for the draft. It answers the device or the server.
  - The availability port of `CVDrafting` reports the model's room and measures a text against it, as numbers of the consumer's language (R3). No framework type leaves the adapter.
  - **Only availability and fit decide.** A failed check does not move an import to the server: the import fails. The server gets text only in the case the owner names.
  - **Consent comes first** (#190). When the rule says "server", the workflow needs the user's consent to the policy's current version. Without it, nothing leaves the device, and the import ends with a typed outcome that the app words (R13).
  - A view, a view model or an adapter never decides (R5).
- **(f) The server's draft job** (#196) is a new job kind, `draft`, in `ServerApplication`, beside the tailoring.
  - **Its lifecycle is a tailoring's:** the same states, the same queue, where a task carries the job's ID and nothing else, and the same erasure, on the app's confirmation and 24 hours after the job ends at the latest ([ADR 0017](0017-hosting-storage-and-cost.md)). The job holds the extracted text and its result, and both go with it. It starts under an idempotency key, and only its owner reads it. The worker's route runs either kind.
  - **It has its own quota:** its own counts and its own limits, per device and for everyone, in configuration. The owner sets the hosted defaults (#165, #196). The credit limit of the hosted router's key is shared, and bounds both kinds of work ([ADR 0017](0017-hosting-storage-and-cost.md)).
  - **It goes through the same registry and policy** ([ADR 0015](0015-inference-providers-and-data-policy.md)). `ServerInference` implements `DocumentStructuring` over the registry's selection and fallback, so the first available provider that meets the policy answers. The adapter holds the draft's versioned prompt and schema, and decodes the model's reply through one anti-corruption layer (R8). It never logs the text or the reply. The model a draft uses is configuration, as a tailoring's is (#155). The job records the prompt's version, and the result names providers and models only by alias ([ADR 0016](0016-api-contract.md)).
  - **It has the same consent.** A start carries the policy version that the app showed the user. Start refuses another one, the job records it, and the worker refuses to run it under another ([ADR 0015](0015-inference-providers-and-data-policy.md)).
  - **The API.** `POST /v1/drafts`, `GET /v1/drafts/{id}` and `DELETE /v1/drafts/{id}` are additive to v1 ([ADR 0016](0016-api-contract.md), (f)). A start carries the headers that a tailoring's start carries. Its body holds an `ExtractedDocument`, bounded as the type is, and nothing else of the document. `DELETE` also confirms that the app has saved the result. `ServerHTTP` validates a request into an `ExtractedDocument`, and a test proves that the spec's bounds equal the type's.
  - **The check runs on the server** (d), inside the same loop of `CVDrafting`. It is a gate on both sides, and the app does not check again a draft that the server returns.
  - **Only an `ExtractedDocument` can go.** In the app, a port that `PrestoCVIntegration` owns (R3) carries the draft job: start, read and confirm, in the drafting model and typed errors. It takes an `ExtractedDocument` and nothing else, so an image or a PDF cannot be sent by mistake. `PrestoCVAPIAdapter` implements it. The app runs no loop on this path: it starts the job, reads it and confirms the result.
  - **The edges are planned** (#196). All of them reach Linux ✓ targets, and none reaches `PrestoCVApp` or `PrestoCVCore`:
    - `ServerApplication` imports `CVDrafting`, `ContentChecks` and `Provenance`;
    - `ServerInference`, `ServerHTTP`, `ServerStorePostgres` and the `PrestoCVServer` executable import `CVDrafting`: the first implements its port, the second maps the API's types to its model, the third builds its rows from it (R12), and the fourth wires its ports;
    - `PrestoCVAPIAdapter` imports `CVDrafting`.
  - [ADR 0014](0014-server-modular-monolith.md) already authorised the edge to `CVDrafting`. R1's rule that only `ServerHTTP` and `PrestoCVAPIAdapter` translate the API's types now covers the drafting model as well as the tailoring model.
- **(g) Composition and review.**
  - `PrestoCVComposition` creates `CVImportVision`, `CVImportArchive` and the structurer (R4). The checker's `infrastructureTypes` lists their types once they exist.
  - `DraftCVWithAI` grows into the import workflow. As today, it returns an unsaved CV with its gaps. For a document, it also returns the extracted text, and the review (#18) marks what the text does not back and shows the text behind a field. The text lives for the review and is not saved.
- **Left to the tickets:**
  - the bounds of `ExtractedDocument` and of an archive (#193, #194), and the format of the extracted text (#194);
  - the ZIP reader (#193);
  - how a text's language is found (#195);
  - the hosted defaults of the draft quota (#165, #196);
  - the exact shape of the draft job's port in the app, and the draft's prompt and schema (#196).

## Consequences

- **What becomes possible:**
  - a user with no CV in the app reaches a reviewed CV from a LinkedIn archive, a PDF or a scan, with little typing (#57);
  - no figure, name, date or employer that the document lacks reaches the review;
  - one draft, one review and one retry loop serve every source, on the device and on the server;
  - an image or a PDF stays on the device, by the type of the port that reaches the server.
- **R1 and R8 change.** R1's rules for the API's generated types name the drafting model as well as the tailoring model, and it names the one translation between two context packages that modules.md designates on the server. R8 lists imported documents, and the text extracted from them, among untrusted input.
- **modules.md lists `CVImportVision` and `CVImportArchive`,** and the edges of (d) and (f): `Provenance` for `PrestoCVIntegration`, and `CVDrafting` for `ServerApplication`, `ServerInference`, `ServerHTTP`, `ServerStorePostgres`, `PrestoCVServer` and `PrestoCVAPIAdapter`, with `ContentChecks` and `Provenance` for `ServerApplication`. The checker's `rules.json` declares the two new targets not yet implemented, and keeps the allow-lists of the targets that exist as they are. The checker lets `rules.json` be stricter than modules.md. The glossary gains **Import** and **Extracted text**.
- **Costs:**
  - **Extraction is Apple-only.** It needs iOS 26 or macOS 26, and a Linux backend cannot extract. That is acceptable, because extraction always runs on the device.
  - **OCR quality bounds a scan's draft.** A draft cannot correct a misread name, because the corrected name is not in the text. The check refuses it, so the draft keeps the misreading and the user corrects it in the review.
  - **The check is a gate on what a draft states.** It does not see what a draft omits, or a true employer paired with the wrong dates. The review is where the user catches both.
  - **Six languages, and German waits.** A document in any other language cannot be imported, and neither can a German one until #142. The user can still describe it.
  - **A second job kind** means a second quota, a second prompt and schema to keep, and more endpoints. The evaluation harness reports on drafts too (#156), and a prompt change needs a run of it before it ships.
  - **Consent before any text leaves the device** (#190). A user who declines gets no import on a device that has no model, or for a text that does not fit.
  - **Two mappings of the check** exist, one in each integration layer. The shared corpus holds them equal.
  - **LinkedIn can change its archive without notice.** The fixtures are invented archives in the format as it is today. A change is found when an import comes out thin or fails, and the documentation test keeps the supported columns honest.
  - **A third-party ZIP reader, if #193 uses one,** is declared in `CVGeneratorAI`'s manifest. A server that imports `CVDrafting` then resolves it and pins it in its `Package.resolved`, and builds none of it.
  - **#195 and #196 wait for #140** as well as for #139, because the check needs the reader of names.
  - **The app's `Platform/` folder grows** by the capture shims, which hold no rule.
- **Enforced by:**
  - the compiler, through the target graph:
    - `CVDrafting` imports Foundation only, so it cannot reach `CVTailoring`, PDFKit or Vision. `CVImportVision` and `CVImportArchive` import `CVDrafting` and no PrestoCV package;
    - the port that reaches the server takes an `ExtractedDocument`, so an image or a PDF cannot be sent;
  - the checker, once the targets exist:
    - the allow-lists of [modules.md](../modules.md), and `--packages` for the manifests (R1). They keep the loop off the device, so `Provenance` is the one edge added, and no app target imports `Tailoring` ([ADR 0013](0013-cv-tailoring-context.md));
    - R11's `platformCondition` on `CVImportVision`, and on `CVImportArchive` if it ends up Apple-only;
    - R2's detectors on `CVDrafting` and `PrestoCVIntegration`, so the check reads its date from the injected time source;
    - R4's detectors on the adapters, with their types in `infrastructureTypes`;
    - R7's `swallowedError`, and R13's `localization` outside the app target, so the failures stay codes;
  - tests:
    - #193: a complete, a partial and a hostile archive, each tested, with the limits and no file written to disk. The supported files and their columns are documented beside the parser, and a test fails if the parser reads a column that the documentation does not name;
    - #194: invented PDFs and images, a two-column CV and a scan among them, and the format of `ExtractedDocument` documented;
    - #195: a scripted structurer, covering a pass, a retry, a failure after two retries and a text too long for the device. The table of the device-or-server rule. The check against the text with drafts that add a figure, a name, a date or an employer. A workflow test that, with consent declined, the server's port is never called;
    - #196: the draft job kind tested like tailorings are: the contract suites, idempotency, ownership, expiry, deletion and the quota. The server's check runs the same corpus as the device's. The spec's bounds equal the type's. The router and adapter tests. The evaluation harness (#156);
    - the corpus of drafts, texts and verdicts, read by both packages' tests;
  - review:
    - that no view or shim holds a rule (R5);
    - that no other port of the app carries a document's bytes off the device, and that the extraction adapters open no connection. Foundation allows a `URLSession`, so only review sees it;
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
- **Falling back to the server when the device's check fails.** Rejected: a text leaves the device only in the case the owner names, and with consent. A second model does not make a text say what it does not.
- **Extraction on the server, or in a hosted OCR service.** Rejected by the owner: images and PDFs never leave the device.
- **Reading the archive on the server.** Rejected: it holds far more than a CV, and no model is involved.
- **One target for extraction and the on-device structurer.** Rejected: extraction must work on a device that has no model.
