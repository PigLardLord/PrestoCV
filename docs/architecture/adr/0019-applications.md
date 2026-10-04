# 0019. Keep a tailoring as an application in CV Authoring

- **Status:** Accepted
- **Date:** 2026-10-04
- **Related:** [ADR 0002](0002-cvpdfexporter-standalone-and-portable.md), [ADR 0007](0007-each-package-owns-its-model.md), [ADR 0009](0009-persisted-schema-v1.md), [ADR 0011](0011-typed-html-builder.md), [ADR 0013](0013-cv-tailoring-context.md), [ADR 0015](0015-inference-providers-and-data-policy.md), [ADR 0016](0016-api-contract.md), [ADR 0017](0017-hosting-storage-and-cost.md), R1, R2, R3, R4, R5, R6, R7, R8, R10, R12, R13, R14, issues #91, #133, #134, #136, #141, #153, #166, #176, #179, #184, #185, #186, #187, #188, #189, #191, #199

## Context

- [ADR 0013](0013-cv-tailoring-context.md) gives a tailoring two products, a CV and a cover letter. It does not say where the user keeps them.
- The server erases a job as soon as the app confirms that it has saved the result, and 24 hours after the job ends at the latest ([ADR 0016](0016-api-contract.md), [ADR 0017](0017-hosting-storage-and-cost.md), #166). So the result needs a home on the device before the app confirms, and the user has to keep it within that window.
- `CVTailoring` owns no persistence, and it runs on the server as well as in the app ([ADR 0013](0013-cv-tailoring-context.md)). The user's data lives in CV Authoring, in `PrestoCVCore`, behind the repository and the file format of [ADR 0009](0009-persisted-schema-v1.md).
- A tailored CV has the shape of a CV, and the user edits it. A cover letter has a model in Tailoring, but no storage and no layout anywhere: a design styles a CV, and a letter is not one.
- The letter defaults, the salary expectation, the start date and a note, are the same for every letter a person writes. The questions before a tailoring ask only for what they lack (#153).
- The owner decided on 2026-10-02 (#184):
  - what an application is, and that it lives in CV Authoring;
  - that its CV is a `CV` like any other, which belongs to the application and is not listed among the user's CVs;
  - that it is persisted as a file type of its own, with a CV's guarantees;
  - that the letter defaults belong to the person, and that one fixed layout serves every design;
  - that the application's status comes later.
- On 2026-10-04 the owner decided three questions that the first decisions left open:
  - when the override of the letter defaults is set;
  - what "erase everything" erases;
  - whether erasing a CV erases the applications made from it.
- This ADR's own architecture:
  - which target holds each type, port and file;
  - how the letter is rendered, and where it is mapped;
  - how the person's defaults are stored;
  - that no target and no edge is added.

## Decision

**The owner's decisions of 2026-10-02.**

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

**The owner's decisions of 2026-10-04.**

- **The override of the letter defaults is set before the tailoring.** For one tailoring, the user may override the person's defaults. The override enters the snapshot, and the application keeps it as provenance. After that the letter's text is edited directly, and nothing re-reads the defaults for a kept application. So an override changes one tailoring only (#186).
- **"Erase everything" is a total erase.** An erase-all use case in `PrestoCVApplication` erases every CV, every application and the letter defaults, with their quarantined copies, each store under its own lock. A partial failure is a typed outcome that names what remains. #91 implements it.
- **Erasing a CV does not erase the applications made from it.** An application is data of its own, and it may have been sent. It is erased alone, or by the erase-all. The app says that the applications remain.

**This ADR's own architecture.** The owner's decisions leave open which target holds what. These keep to [ADR 0007](0007-each-package-owns-its-model.md), [ADR 0009](0009-persisted-schema-v1.md) and R1.

- **(a) The domain (`PrestoCVDomain`).**
  - **`Application`** is the aggregate, with a typed `ApplicationID`. It holds:
    - its `CV`, the tailored one;
    - its `CoverLetter`;
    - the advert's company, role and text;
    - its provenance, as plain values (below);
    - `revision`, `createdAt` and `updatedAt`, which only a repository assigns and which are settable only inside the package, as for `CV` (R6). `createdAt` is when the user kept it. That is a reading of the owner's "when it was made", not the owner's own words.

    Its CV and its letter change through methods, not through fields (R6).
  - **Inside an application the CV is part of the application's aggregate.** Its revision and timestamps are the application's: the application repository stamps them and stores them once, in the envelope. An edit of its CV is conditional on the application's revision. So is an edit of its letter, and the two share that revision: an edit of the CV and an edit of the letter made from the same revision conflict (#191).
  - **A tailored `CV` keeps its own `CVID` inside the application.**
    - The identity is assigned when the application is created, and no change replaces it.
    - The CV list never holds it, because `CVRepository` is not where it lives.
    - `CV`'s "can be saved" rule holds for it, on create and on every update. R6's property test, that every saveable CV maps to a renderable document, covers it.
  - **`CoverLetter`** is Authoring's own type for the letter the user keeps and edits: whom it is addressed to, its subject and reference, its opening, its body paragraphs, its closing and its attachments. Its parts are value types that validate on creation (R6).
    - It stores no salutation and no valediction. The page writes them, from the recipient's form of address and the language (#141, #187).
  - **`LetterDefaults`** holds the salary expectation, the start date and the note as the user's own text, bounded. They are not typed values: the user writes them as they want them said.
    - A tailoring's override is a `LetterDefaults` value too. One rule of the domain combines it with the person's defaults: a field that the override sets wins. The rule exists once (R6). `PrestoCVIntegration` applies it when it builds the questions and the snapshot, so the override is entered before the questions are built.
    - An override sets a field and cannot clear one. If a letter should not say what a default says, the person edits the letter afterwards.
  - **The provenance** is plain values, never Tailoring's types (R1):
    - the source CV's `CVID`, so that the app can say which CV an application came from, and the snapshot the tailoring used, stored as its lines;
    - the report;
    - the questions, as the codes and values that Tailoring gives, and their answers. They are worded at the edge (R13), and #185 picks the exact type;
    - the override of the letter defaults that the tailoring was made with, and the letter defaults as the snapshot held them, after the override, so that a kept application says what its letter was held to whatever the person's defaults become. The second adds to the owner's decision of 2026-10-04, which names the override only;
    - the prompt version and the aliases of the attempt that passed, which the result carries (#176). A result names a provider and a model only by their aliases ([ADR 0015](0015-inference-providers-and-data-policy.md), [ADR 0016](0016-api-contract.md)), so no name or identifier of either is stored;
    - the job's identifier, an opaque value. It is the one provenance value that the repository reads: it checks it under its lock, so that create is idempotent per job (#188);
    - the statement and answer references that tie each tailored line to its sources, kept as positions into the stored snapshot's statements.

    The provenance describes the result as produced, not the CV after the user's edits. `PrestoCVIntegration` maps it from Tailoring's types. Authoring stores it, bounds it and gives it back. It does not interpret it.
- **(b) The application layer (`PrestoCVApplication`).**
  - **`ApplicationRepository`** is an outbound port, owned by the layer that needs it (R3): create, conditional update, load, list and conditional delete. Its errors are typed and it is not cancellable, like `CVRepository`. Listing returns the healthy applications, ordered by last change, with the store's issues. #191 may sort them otherwise for display.
  - **`ApplicationStoreMaintenance`** is the port of quarantine: restore, erase every copy and purge. It mirrors `CVStoreMaintenance`.
  - **`LetterDefaultsStore`** is a port of its own: load, save conditional on a revision, and erase. Restore and purge from its quarantine are on the port or on a maintenance port beside it, as #185 chooses. `PrestoCVIntegration` reads it, applies the tailoring's override, and hands the defaults to the question builder in Tailoring's own type (#153, #186). `AdvertAnalysis` never sees the store.
  - **Use cases:**
    - create from a tailoring result, list by last change, load, update its CV, update its letter, and delete;
    - load and save the person's letter defaults (#186);
    - erase-all (#91): it erases every CV, every application and the letter defaults, with their quarantined copies, each store under its own lock. A partial failure is a typed outcome that names what remains. Each store's maintenance port gains an erase-all of its own, so that a file no listing returns, a corrupt or newer-schema one, goes too.
  - **Create** takes values, never Tailoring's types. It assigns the application's identity and its CV's through the injected `IDGenerator`, and the repository assigns the timestamps through `TimeSource` (R2). Create for a job that the store already holds returns that application: the repository checks the job's identifier under its lock, so two creates for one job leave one application.
  - **Errors** are translated once, into Authoring's typed errors, `tooLarge` among them (R7).
- **(c) Persistence (`PrestoCVPersistence`).**
  - **`ApplicationFileV1`** sits beside `CVFileV1`. It is a DTO, separate from the domain, with the frozen envelope: `schemaVersion`, `id`, `revision`, `createdAt` and `updatedAt`, then the content. The content is the advert, the letter, the provenance and the tailored CV. The CV has no envelope of its own, so the content holds the CV's `CVID` beside its content DTO.
    - The CV's content goes through the same content DTO as `CVFileV1`, so `Period.make` and the size caps exist once (R6, R12). #185 extracts that DTO without changing `CVFileV1`'s JSON.
  - **Its repository** gives it every guarantee that R12 and [ADR 0009](0009-persisted-schema-v1.md) give a CV. It has a directory of its own, with its own lock and its own `Quarantine/`.
    - One file per application, named from its id, with a suffix of its own. A restore accepts only names of that pattern.
    - R12's every outcome: `upgradeRequired`, `unreadable`, `tooLarge`, corrupt (quarantined, reported with its reason and restorable) and `quarantineFailed`.
    - Atomic writes with `complete` protection, and the read-back check with its typed `wouldNotReadBack`.
    - Create, update and delete conditional on the revision, under an exclusive `flock`, with timestamps from `TimeSource` in whole seconds.
  - **`LetterDefaultsFileV1`** holds the person's defaults in one file, and follows R12 in full. It has a directory of its own, with its own lock and its own `Quarantine/`.
    - The frozen envelope is `schemaVersion`, `revision` and `updatedAt`, then the three texts. Decoding is strict, writes are atomic with the read-back check, and sizes are capped.
    - A save is conditional on the revision: a stale save is a conflict. The first save expects no file.
    - A missing file is empty defaults. A newer, unreadable or oversized file is reported by its own outcome, never read as empty (R7).
    - A corrupt file is moved to `Quarantine/` and reported with its reason. The store remembers it: while a quarantined copy stands and no new file replaces it, every load reports `corrupt`, never empty defaults, until the user restores the copy or saves new defaults. Restore is validated as for CVs, and purge applies the same retention.
  - **Erasure.**
    - Erasing an application removes every copy of it: the file, whatever its schema, and its quarantined copies.
    - **Erasing a CV does not erase the applications made from it** (the owner, 2026-10-04). The app says that they remain.
    - The erase-all use case removes every CV, every application and the letter defaults, with their quarantined copies. Each store runs it under its own lock, so a failure in one store does not stop the others, and the outcome names what remains.
  - The composition root gives the locations and creates each repository and store once (R4).
- **(d) Rendering (`CVDocumentModel`, `CVRendering`).**
  - **`LetterDocument`** is a second published document type of `CVPDFExporter`, beside `CVDocument` (#187). It is plain values and imports no PrestoCV package, so the package stays standalone ([ADR 0002](0002-cvpdfexporter-standalone-and-portable.md)). It carries a `schemaVersion`, a `language` and the recipient's form of address, which the page needs to write the salutation, the valediction and the date. A letter that arrives as JSON passes a validator of its own, beside `CVDocumentValidator`, before it is rendered (R8).
  - **The letter's markup is a structure of its own,** specified in [markup-contract.md](../markup-contract.md) beside the CV's, and pinned by a golden HTML file (R10).
    - Its classes are not in the table of what a design may select, and a design's CSS cannot select them.
    - Its built-in stylesheet is not a design: it is not in the catalog, nobody installs it, and no design choice can select it. It passes the same tokenizer and property allow-list as a design's, checked against the letter structure's selectors.
    - Its colours and fonts are the stylesheet's fixed values. They come from no design and no palette (#187).
  - **The typed builder** of [ADR 0011](0011-typed-html-builder.md) produces the markup: closed tags, and per-scalar escaping. The PDF is checked node by node against it (R8). The letter is one A4 page. A letter that does not fit is an error, never a truncated page.
  - **The page writes the salutation, the valediction and the date.** The language conventions, the date format, the salutations and the valedictions, come from data and never from the layout: one JSON file per language and an index, for the six languages of [ADR 0013](0013-cv-tailoring-context.md). A test fails if a language lacks a key, and an unsupported language is a typed error (R13).
- **(e) Integration (`PrestoCVIntegration`).**
  - **Mappers,** one per direction that exists ([ADR 0007](0007-each-package-owns-its-model.md)):
    - the tailoring result → the values that create takes: the tailored CV's content with no identity, the `CoverLetter`, the advert's company, role and text, and the provenance;
    - `CoverLetter` and the person's details → `LetterDocument`. The details are those of the application's own CV, and so is the language: a tailoring writes the letter in the CV's language ([ADR 0013](0013-cv-tailoring-context.md));
    - the person's `LetterDefaults`, with a tailoring's override applied → the question builder's defaults and the snapshot's letter defaults (#153, #179).

    None goes the other way. Nothing needs it.
  - **They are exhaustive, deterministic and tested** ([ADR 0007](0007-each-package-owns-its-model.md)): a `switch` over every case with no `default`, and no identity created in a mapper, because the create use case assigns it. A Mirror-based test per mapper proves that every populated field reaches its target. A property proves that every result the gate accepts maps to values that Authoring accepts, and whose file stays within the cap.
  - **The review's letter preview** (#189) renders the unsaved mapped values: `CoverLetter` → `LetterDocument` works on a letter before it is kept.
  - **Two modules each export a `CoverLetter` and a `LetterDefaults`:** Tailoring's and Authoring's. Translation lives in the mappers, and the compiler forces the module name in any file that imports both.
  - **The tailoring workflow** saves the result as an application and only then confirms to the server, which erases its copy (#188, [ADR 0016](0016-api-contract.md)).
- **(f) Glossary terms owned here:**
  - *application* (an Authoring term, not the application layer);
  - *cover letter*, which now serves both contexts. The word means the same letter in both, and each context holds it as its own type;
  - *letter defaults*.
- **(g) No new target and no new edge.** Every module named above is in [modules.md](../modules.md), and its allow-list already lets it import what this ADR needs. So no allow-list changes. The checker's `rules.json` changes in one place: `infrastructureTypes` gains `FileApplicationRepository` and `FileLetterDefaultsStore` when #185 adds them, so that only the composition root creates them (R4). [modules.md](../modules.md) describes the new types in the sections of the existing targets.

## Consequences

- **What it buys:**
  - a tailored CV is edited with the same editor and held to the same "can be saved" rule as any CV;
  - one erase-all covers every CV, every application and the person's defaults, and a partial failure says what remains;
  - a letter renders with no design, so the Design Catalog stays about CVs;
  - the result is on the device before the server erases its copy, if the user keeps it within the server's window;
  - an application keeps where it came from, as plain values.
- **Costs:**
  - a second aggregate, a second file type, a repository, a maintenance port and a contract suite more to keep, and a third file type for the defaults, with its own quarantine;
  - a mapper per direction, in `PrestoCVIntegration`;
  - two modules that export a `CoverLetter` and a `LetterDefaults`, so any file that imports both names the module;
  - an edit of an application's CV and an edit of its letter share one revision, so they conflict with each other (#191);
  - "application" now has two meanings in a codebase that has an application layer. The glossary says which is which, and the code says "application layer" for the layer;
  - the tailored CV's identity lives inside its application. Moving it to the CV list is a later decision, and its own `CVID` keeps that open;
  - the CV's content is written by two file types. A new version of the CV's content is a new version of both `CVFileV1` and `ApplicationFileV1`, each with its migration (R12);
  - the user has to keep a result within the server's window, or its copy is gone;
  - salutations and valedictions exist twice: in `TailoringModel`'s word lists (#136) and in the letter's data. #187 decides which is the source, or adds a test that holds the two in agreement for every language, as the review of #134 asks. Neither package may import the other (R1), so such a test lives in the app's integration layer.
- **What the tickets decide:**
  - #185: the exact types and their names, their bounds and the file's caps, and whether restore and purge of the defaults sit on `LetterDefaultsStore` or beside it;
  - #186: the settings screen, and how an override is entered before the questions are built;
  - #187: the letter's fields, its structure and selectors, its stylesheet, its language data, and where the CSS policy takes the letter's selector set;
  - #188: the workflow's states and what it does when a save fails;
  - #91: the erase-all's typed outcome, and the erase-all of each store;
  - #191: how the editor reaches an application's CV, the letter's own editor, and the list's display order;
  - #199: the status and its dates, as a new version of `ApplicationFileV1` with its migration (R12).
- **Enforced by:**
  - the compiler: the target graph, and `PrestoCVDomain` importing only Foundation, so the provenance can only be plain values. R5's `internal import` keeps the domain's types, `Application` among them, out of presentation's public API;
  - the checker: the import allow-lists (R1); the detectors `wallClock` and `randomIdentity` on the domain, the use cases and the mappers (R2); `swallowedError` (R7); `localization` (R13); R14's; and R4's `infrastructureConstruction`, with `FileApplicationRepository` and `FileLetterDefaultsStore` in `infrastructureTypes` once #185 adds them;
  - tests:
    - (#185) the `ApplicationRepository` contract suite, modelled on the `CVRepository` one and run against an in-memory adapter and the file adapter: round trip with timestamps, create twice, update bumps the revision, stale update and stale delete, update after delete, listing order and concurrent updates, plus creating twice from one job, which returns the first application, and concurrent creates for one job, which leave one;
    - (#185) the file store's own cases: hostile files, oversized files, a newer schema, quarantine and restore, erasure of every copy, and two instances racing;
    - (#185, R12) the read-back check on `ApplicationFileV1`: an application whose file would exceed its cap is refused, and the previous version stays;
    - (#185, #186) the cases of `LetterDefaultsStore` and its file: a stale save is a conflict; a corrupt file is quarantined, and every load reports `corrupt` until a restore or a new save; a newer, unreadable and oversized file; restore, purge and erasure of every copy; two instances racing; the read-back check; a cleared default; and the rule that combines the defaults with an override;
    - (#153, #186) the questions ask only for what the defaults lack once the override is applied;
    - (#185) each invariant of `Application`, `CoverLetter` and `LetterDefaults`, the rule that a tailored CV keeps its `CVID`, including through a round trip of the file, and that an override sets a field and cannot clear one;
    - (#185, #91) the erase-all: it removes every CV, every application and the defaults with their quarantined copies; with one store failing, the others are erased and the outcome names what remains; erasing a CV leaves its applications;
    - (#191) saving an application's CV from the editor goes through the application's update, a stale edit of the CV or of the letter is a conflict on the application's revision, so is an edit of the one after an edit of the other from the same revision, and the CV listing never holds its `CVID`;
    - the mappers' Mirror-based completeness tests, the property that every result the gate accepts maps to values that Authoring accepts within the file cap, and the property that every saveable `CoverLetter` maps to a `LetterDocument` that its validator accepts (R6);
    - (#187) the letter's PDF holds every text node, on iOS and macOS, in each of the six languages; the letter's golden HTML file; its stylesheet passes the CSS policy against the letter's selectors; a design stylesheet that names a letter class is rejected; the language data is complete (R13); a letter that does not fit is an error;
    - (#187) one test per attack on the letter validator, as for `CVDocumentValidator` (R8): an oversized field, control characters, bidirectional overrides, an unsupported version and an unsupported language;
  - review: whether a view or a view model holds a rule of the application or of the letter (R5).

## Alternatives considered

- **The application in the Tailoring context.** Rejected: Tailoring owns no persistence and runs on the server, and the user's data lives in Authoring.
- **The tailored CV as an ordinary CV in the list.** Rejected by the owner: it belongs to its application.
- **The letter as a design.** Rejected by the owner: one fixed layout serves every design.
- **Letter defaults per CV.** Rejected by the owner: they belong to the person.
- **An override that a kept application re-applies to its letter.** Rejected by the owner (2026-10-04): the override is set before the tailoring, and the letter's text is edited directly afterwards.
- **Erasing a CV with the applications made from it.** Rejected by the owner (2026-10-04): an application is data of its own, and it may have been sent.
- **Tailoring's own types in the file.** Rejected: Authoring would import `TailoringModel` against R1 and [ADR 0007](0007-each-package-owns-its-model.md), and a change to Tailoring's model would change a persisted file.
