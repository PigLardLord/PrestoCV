# 0001. Define and enforce the target architecture before fixing bugs

- **Status:** Accepted
- **Date:** 2026-09-27
- **Related:** [rules](../rules.md), [ADR 0006](0006-enforce-architecture-mechanically.md), GitHub project PigLardLord #6 (issues #1–#57)

## Context

PrestoCV is not in production. A review in September 2026 found 57 backlog items, 8 of them P0: the exported PDF prints wrong data, choosing a design has no effect, saves duplicate CVs, the AI flow never shows its result, and editor changes are lost on back navigation.

Most of these defects share structural causes rather than being isolated mistakes:
- The Clean Architecture exists in folder names only. Business rules sit in view models, a view, a repository and adapters, with four disagreeing definitions of a "valid CV".
- Objects are constructed in four places. The template subsystem is instantiated three times over the same files, and nobody connects installation to registration (#1).
- A CV has four production representations joined by five hand-written, lossy mappers, with string-keyed contracts between them (#2).
- Package boundaries are bypassed. The exporter imports the authoring package for one adapter, and the domain localises through the host app's bundle.

Fixing each bug in the current structure would add more code to the places that caused it.

## Decision

1. Write the target architecture and its rules first (this directory).
2. Make the rules mechanically enforced before code moves ([ADR 0006](0006-enforce-architecture-mechanically.md)).
3. Rebuild context by context into the target structure. Each backlog bug is fixed as part of the step that rebuilds its context, starting with a failing test, not as a patch on the old code.
4. Old code is deleted when its replacement is wired in. Issues made obsolete by the rebuild are closed with a reference to the step that removed them.

Because nothing is released, compatibility with the current code, persisted files and APIs is **not** a constraint.

## Consequences

- No user-visible progress on individual bugs until the first context (Rendering and Design Catalog) is rebuilt.
- The backlog gets reorganised by migration step instead of by bug.
- The cost of the rebuild is paid once, before release, when it is cheapest: no data migrations, no users to keep working.
- Rules that cannot be enforced automatically must stay few, or they will erode the same way the current ones did.

## Validation

This is a process decision, so there is nothing to compile. The prototype checked the premise: the structure fixes defects by construction, not one patch at a time.

The validation prototype, commit `90533fb` of its own repository (`PigLardLord/PrestoCV-adr-prototype`, #65) (Swift 6.3.3, Linux), not yet in this repository; it is committed under `Prototypes/ADRValidation/` once it passes review.

It went through two adversarial reviews and three internal reviews (Swift code, security, documentation). About 80 findings were fixed, each with a test.

These defects cannot be reproduced in the target shape, and each has a test:
- wrong data in the generated HTML (#2), checked against a golden file;
- duplicate saves, including overlapping ones (#4);
- the lost identity of AI-created CVs (#5);
- truncation hidden or invented by a renderer (#8), with the PDF parsed;
- corrupt files that vanish (#11);
- user text re-parsed as template syntax (#21);
- every design-package attack in #9 and in the security review;
- lost updates across windows and processes.

**Scope of this evidence.** The prototype ran on Linux with a fake renderer. It validates the model, the mapping, persistence, presentation and the generated HTML and CSS. It does **not** validate the PDFs of the native renderers, which needs the native contract tests on iOS and macOS ([ADR 0003](0003-one-pdf-renderer-per-platform.md)).

## Alternatives considered

- **Fix P0 bugs first, refactor later.** Rejected: the fixes would land in structures scheduled for deletion, and several P0s cannot be fixed properly without the structural change (a single template catalog for #1, a typed document contract for #2).
- **Incremental refactor without enforcement.** Rejected: that is how the current state came about.
