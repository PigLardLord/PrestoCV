# 0019. Keep a tailoring as an application in CV Authoring

- **Status:** Accepted
- **Date:** 2026-10-03
- **Related:** [ADR 0002](0002-cvpdfexporter-standalone-and-portable.md), [ADR 0007](0007-each-package-owns-its-model.md), [ADR 0009](0009-persisted-schema-v1.md), [ADR 0011](0011-typed-html-builder.md), [ADR 0013](0013-cv-tailoring-context.md), [ADR 0016](0016-api-contract.md), [ADR 0017](0017-hosting-storage-and-cost.md), R1, R2, R3, R6, R7, R8, R10, R12, R13, issues #133, #153, #179, #184, #185, #186, #187, #188, #189, #191, #199

## Context

- [ADR 0013](0013-cv-tailoring-context.md) gives a tailoring two products, a CV and a cover letter. It does not say where the user keeps them.
- The server erases a job as soon as the app confirms that it has saved the result, and 24 hours after the job ends at the latest ([ADR 0016](0016-api-contract.md), [ADR 0017](0017-hosting-storage-and-cost.md), #166). So the result needs a home on the device before the app confirms.
- `CVTailoring` owns no persistence, and it runs on the server as well as in the app ([ADR 0013](0013-cv-tailoring-context.md)). The user's data lives in CV Authoring, in `PrestoCVCore`, behind the repository and the file format of [ADR 0009](0009-persisted-schema-v1.md).
- A tailored CV has the shape of a CV, and the user edits it. A cover letter has a model in Tailoring, but no storage and no layout anywhere: a design styles a CV, and a letter is not one.
- The letter defaults, the salary expectation, the start date and a note, are the same for every letter a person writes. The questions before a tailoring ask only for what they lack (#153).
- The owner decided on 2026-10-02 (#184):
  - what an application is, and that it lives in CV Authoring;
  - that its CV is a `CV` like any other, which belongs to the application and is not listed among the user's CVs;
  - that it is persisted as a file type of its own, with a CV's guarantees;
  - that the letter defaults belong to the person, and that one fixed layout serves every design;
  - that the application's status comes later.
- This ADR's own architecture:
  - which target holds each type, port and file;
  - how the letter is rendered, and where it is mapped;
  - that no target and no edge is added.

## Decision

**The owner's decisions.**

- **An application** is what a tailoring produces and the user keeps:
  - the advert: company, role and text;
  - the tailored CV and its cover letter;
  - when it was made;
  - where it came from: the source CV, the report, the questions and their answers, the prompt version and the provider alias.
- **It lives in CV Authoring.**
  - The tailored CV is a `CV` like any other, and the same editor edits it. It belongs to its application and is not listed among the user's CVs.
  - The letter is an authoring type too.
  - `PrestoCVIntegration` maps Tailoring's model to these types ([ADR 0007](0007-each-package-owns-its-model.md)).
- **It is persisted as its own versioned file type** (R12, [ADR 0009](0009-persisted-schema-v1.md)), with the same guarantees as a CV: atomic writes, quarantine and erase-everything.
- **Letter defaults belong to the person, not to a CV:** the salary expectation, the start date and a note. An application can override them for itself.
- **One fixed letter layout** serves every design (#187).
- **Application status** (sent, interview, offer, rejected) comes later (#199).

**This ADR's own architecture.** The owner's decisions leave open which target holds what. These keep to [ADR 0007](0007-each-package-owns-its-model.md), [ADR 0009](0009-persisted-schema-v1.md) and R1.

- **(a) The domain (`PrestoCVDomain`).**
  - **`Application`** is the aggregate, with a typed `ApplicationID`. It holds:
    - its `CV`, the tailored one, as a value;
    - its `CoverLetter`;
    - the advert's company, role and text;
    - its override of the letter defaults, when the user sets one;
    - its provenance, as plain values (below);
    - `revision`, `createdAt` and `updatedAt`, which only a repository assigns and which are settable only inside the package, as for `CV` (R6). `createdAt` is when it was made.

    Its CV and its letter change through methods, not through fields (R6).
  - **A tailored `CV` keeps its own `CVID` inside the application.**
    - The identity is assigned when the application is created, and no change replaces it.
    - The CV list never holds it, because `CVRepository` is not where it lives.
    - `CV`'s "can be saved" rule holds for it, on create and on every update. R6's property test, that every saveable CV maps to a renderable document, covers it.
  - **`CoverLetter`** is Authoring's own type for the letter the user keeps and edits: whom it is addressed to, its subject and reference, its opening, its body paragraphs, its closing and its attachments. Its parts are value types that validate on creation (R6).
    - It stores no salutation and no valediction. The page writes them, from the recipient's form of address and the language (#141, #187).
  - **`LetterDefaults`** holds the person's salary expectation, start date and note, as value types with their own invariants.
    - One rule of the domain combines the person's defaults with an application's override: a field that the override sets wins. The rule exists once (R6).
  - **The provenance** is plain values, never Tailoring's types (R1): the source CV as the snapshot the tailoring used, the report, the questions and their answers, the prompt version, the provider alias, and the statement references that tie each tailored line to its sources.
    - `PrestoCVIntegration` maps them from Tailoring's types. Authoring stores them, bounds them and gives them back. It does not interpret them.
    - A result names a provider only by its alias ([ADR 0016](0016-api-contract.md)), so no name or identifier of a provider or a model is stored.
- **(b) The application layer (`PrestoCVApplication`).**
  - **`ApplicationRepository`** is an outbound port, owned by the layer that needs it (R3): create, conditional update, load, list and conditional delete. Its errors are typed and it is not cancellable, like `CVRepository`. Listing returns the healthy applications, ordered by last change, with the store's issues.
  - **`ApplicationStoreMaintenance`** is the port of quarantine: restore, erase every copy and purge. It mirrors `CVStoreMaintenance`.
  - **`LetterDefaultsStore`** is a port of its own: load, save and erase the person's defaults. `PrestoCVIntegration` reads it and hands the defaults to the question builder in Tailoring's own type (#153, #186). `AdvertAnalysis` never sees the store.
  - **Use cases:**
    - create from a tailoring result, list by last change, load, update its CV, update its letter, set or clear its override, and delete;
    - load and save the person's letter defaults (#186).
  - **Create** takes values, never Tailoring's types. It assigns the application's identity and its CV's through the injected `IDGenerator`, and the repository assigns the timestamps through `TimeSource` (R2).
  - **Errors** are translated once, into Authoring's typed errors, `tooLarge` among them (R7).
- **(c) Persistence (`PrestoCVPersistence`).**
  - **`ApplicationFileV1`** sits beside `CVFileV1`. It is a DTO, separate from the domain, with the frozen envelope: `schemaVersion`, `id`, `revision`, `createdAt` and `updatedAt`, then the content. The content is the advert, the letter, the override, the provenance and the tailored CV. The CV goes through the same content DTO as `CVFileV1`, so `Period.make` and the size caps exist once (R6, R12).
  - **Its repository** gives it every guarantee that R12 and [ADR 0009](0009-persisted-schema-v1.md) give a CV. It has a directory of its own, with its own lock and its own `Quarantine/`.
    - One file per application, named from its id, with a suffix of its own. A restore accepts only names of that pattern.
    - R12's every outcome: `upgradeRequired`, `unreadable`, `tooLarge`, corrupt (quarantined, reported with its reason and restorable) and `quarantineFailed`.
    - Atomic writes with `complete` protection, and the read-back check with its typed `wouldNotReadBack`.
    - Create, update and delete conditional on the revision, under an exclusive `flock`, with timestamps from `TimeSource` in whole seconds.
  - **`LetterDefaultsFileV1`** holds the person's defaults in one file, with the same envelope, strict decoding, atomic write, read-back check and outcomes. A missing file is empty defaults. A newer, unreadable, oversized or corrupt file is an error, never read as empty (R7).
  - **Erasure.** Erasing an application removes every copy of it: the file, whatever its schema, and its quarantined copies. Erasing everything removes the applications and the letter defaults too. Quarantine is purged after the same retention as the CVs'.
  - The composition root gives the locations and creates each repository and store once (R4).
- **(d) Rendering (`CVDocumentModel`, `CVRendering`).**
  - **`LetterDocument`** is a second published document type of `CVPDFExporter`, beside `CVDocument` (#187). It is plain values and imports no PrestoCV package, so the package stays standalone ([ADR 0002](0002-cvpdfexporter-standalone-and-portable.md)). Like `CVDocument`, it carries a `schemaVersion`, and a letter that arrives as JSON passes a validator of its own before it is rendered (R8).
  - **One built-in stylesheet** renders it. The stylesheet is not a design: it is not in the catalog, nobody installs it, and no design choice can select it. It passes the same CSS policy as a design's, through the same tokenizer and allow-list, and a test holds it.
  - **The typed builder** of [ADR 0011](0011-typed-html-builder.md) produces the markup: closed tags, and per-scalar escaping. The PDF is checked node by node against it (R8). The letter is one A4 page. A letter that does not fit is an error, never a truncated page.
  - **The page writes the salutation and the valediction.** The language conventions, the date format, the salutations and the valedictions, come from data and never from the layout: one JSON file per language and an index, for the six languages of [ADR 0013](0013-cv-tailoring-context.md). A test fails if a language lacks a key, and an unsupported language is a typed error (R13).
- **(e) Integration (`PrestoCVIntegration`).**
  - **Mappers,** one per direction that exists ([ADR 0007](0007-each-package-owns-its-model.md)):
    - the tailoring result → `Application`: the tailored `CV`, the `CoverLetter` and the provenance values;
    - `CoverLetter` and the person's details → `LetterDocument`, the details being those of the application's own CV;
    - the person's `LetterDefaults`, with an application's override applied → the snapshot's letter defaults (#153, #179).

    None goes the other way. Nothing needs it.
  - **They are exhaustive, deterministic and tested** ([ADR 0007](0007-each-package-owns-its-model.md)): a `switch` over every case with no `default`, and no identity created in a mapper, because the create use case assigns it. A Mirror-based test per mapper proves that every populated field reaches its target. Another proves that every bound of a tailoring result fits the bound of the field it maps to, so a result that the tailoring accepts is one the application can keep.
  - **Two modules each export a `CoverLetter` and a `LetterDefaults`:** Tailoring's and Authoring's. The mappers are the only files that import both, and they name the module.
  - **The tailoring workflow** saves the result as an application and only then confirms to the server, which erases its copy (#188, [ADR 0016](0016-api-contract.md)).
- **(f) Glossary terms owned here:**
  - *application* (an Authoring term, not the application layer);
  - *cover letter*, which now serves Authoring too. The word means the same letter in both contexts, and each context holds it as its own type;
  - *letter defaults*.
- **(g) No new target and no new edge.** Every module named above is in [modules.md](../modules.md), and its allow-list already lets it import what this ADR needs. So no allow-list changes, and neither does the checker's `rules.json`. [modules.md](../modules.md) describes the new types in the sections of the existing targets.

## Consequences

- **What it buys:**
  - a tailored CV is edited with the same editor and held to the same "can be saved" rule as any CV;
  - one erasure covers everything the app keeps of a tailoring, including the person's defaults;
  - a letter renders with no design, so the Design Catalog stays about CVs;
  - the result is on the device before the server erases its copy;
  - an application keeps where it came from, as plain values.
- **Costs:**
  - a second aggregate, a second file type, a repository, a maintenance port and a contract suite more to keep;
  - a mapper per direction, in `PrestoCVIntegration`;
  - two modules that export a `CoverLetter` and a `LetterDefaults`, so the mappers name the module;
  - "application" now has two meanings in a codebase that has an application layer. The glossary says which is which, and the code says "application layer" for the layer;
  - the tailored CV's identity lives inside its application. Moving it to the CV list is a later decision, and its own `CVID` keeps that open;
  - salutations and valedictions exist twice: in `TailoringModel`'s word lists (#136) and in the letter's data. #187 decides which is the source, or adds a test that holds the two in agreement for every language, as the review of #134 asks. Neither package may import the other (R1), so such a test lives in the app's integration layer.
- **What the tickets decide:**
  - #185: the exact types and their names, their bounds and the file's caps;
  - #186: the settings screen, and how an override is set;
  - #187: the letter's fields, its stylesheet and its language data;
  - #188: the workflow's states and what it does when a save fails;
  - #191: how the editor reaches an application's CV, and the letter's own editor;
  - #199: the status and its dates, as a new version of `ApplicationFileV1` with its migration (R12).
- **Enforced by:**
  - the compiler: the target graph, and `PrestoCVDomain` importing only Foundation, so the provenance can only be plain values. R5's `internal import` keeps the domain's types, `Application` among them, out of presentation's public API;
  - the checker: the import allow-lists (R1); the detectors `wallClock` and `randomIdentity` on the domain, the use cases and the mappers (R2); `swallowedError` (R7); `localization` (R13); and R14's;
  - tests:
    - (#185) the `ApplicationRepository` contract suite, modelled on the `CVRepository` one and run against an in-memory adapter and the file adapter: round trip with timestamps, create twice, update bumps the revision, stale update and stale delete, update after delete, listing order and concurrent updates;
    - (#185) the file store's own cases: hostile files, oversized files, a newer schema, quarantine and restore, erasure of every copy, and two instances racing;
    - (#185, R12) the read-back check on `ApplicationFileV1`: an application whose file would exceed its cap is refused, and the previous version stays;
    - (#185, #186) the cases of `LetterDefaultsStore`, a cleared default among them, and the rule that combines the defaults with an override;
    - (#185) each invariant of `Application`, `CoverLetter` and `LetterDefaults`, and the rule that a tailored CV keeps its `CVID`;
    - the mappers' Mirror-based completeness tests, and the property that every saveable `CoverLetter` maps to a `LetterDocument` that its validator accepts (R6);
    - (#187) the letter's PDF holds every text node, on iOS and macOS, in each of the six languages; the stylesheet passes the CSS policy; the language data is complete (R13); a letter that does not fit is an error;
  - review: whether a view or a view model holds a rule of the application or of the letter (R5).

## Alternatives considered

- **The application in the Tailoring context.** Rejected: Tailoring owns no persistence and runs on the server, and the user's data lives in Authoring.
- **The tailored CV as an ordinary CV in the list.** Rejected by the owner: it belongs to its application.
- **The letter as a design.** Rejected by the owner: one fixed layout serves every design.
- **Letter defaults per CV.** Rejected by the owner: they belong to the person.
- **Tailoring's own types in the file.** Rejected: Authoring would import `TailoringModel` against R1 and [ADR 0007](0007-each-package-owns-its-model.md), and a change to Tailoring's model would change a persisted file.
