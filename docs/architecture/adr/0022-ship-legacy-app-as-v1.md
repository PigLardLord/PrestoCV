# 0022. Ship the legacy app, fixed, as version 1

- **Status:** Accepted
- **Date:** 2026-10-12
- **Related:** [ADR 0001](0001-architecture-before-bug-fixing.md), [ADR 0009](0009-persisted-schema-v1.md), [ADR 0012](0012-legacy-targets-during-migration.md), issue #98

## Context

- **The plan.** The migration plan (#98, ADR 0001) fixed the app's P0 bugs by switching it to the new stack at the end of migration step 5. Until then, the legacy targets would be "never modified except to delete it or to keep the app building" (ADR 0012).
- **The deadline.** On 2026-10-12 the owner set it: version 1 is on the App Store by the end of that week.
- **The new stack is not ready.** Its domain, persistence and exporter are on `main`. The app shell, the editor and the iOS renderer are not, and building them is more than a week of work.

## Decision

**The owner's decisions:**
- **Base:** version 1 is the **legacy app, fixed**: the `PrestoCV` app target and the legacy targets of `PrestoCVCore`, `CVPDFExporter` and `CVGeneratorAI`.
- **Platform:** iOS only.
- **Scope:** the CV list, the editor, the bundled designs, PDF export and sharing, sample CVs on first run, the document language, duplicate and rename, and a draft written on the device by Apple's Foundation Models, offered only where the device supports it.
- **The `.mcvt` import is removed** for version 1. An imported design could run scripts (#9).

**The rest of this section is this ADR's own:**
- **Legacy targets may be changed for the release.** This amends ADR 0012's "never modified": until version 1 is submitted, a change to a legacy target is allowed when it fixes a bug or adds a version 1 feature. The legacy targets stay exempt from the checker, and a new target still never depends on one.
- **The migration goes on afterwards.** It still ends with the switch to the new stack and the deletion of the legacy code.
- **What version 1 stores is a released format.**
  - The legacy store moves to `Application Support/PrestoCV/CVs`. It writes flat `cv_<uuid>.json` files, with a required `id` and timestamps in whole seconds.
  - From submission on, it is the format users have.
  - So the switch to schema 1 ships a one-time importer from these files, with tests. ADR 0009's "no compatibility with the current format" no longer holds once version 1 is released.
  - The legacy files never carry `schemaVersion: 1`, so the new store cannot mistake one for a schema 1 file.

## Consequences

- **The release:** it is reachable this week, and the P0 bugs are fixed in code that the migration later deletes.
- **The switch:** it gains an importer and its tests.
- **The importer maps the look.** The legacy CV file has gained an optional `look` key (#286): `{"design", "palette", "fonts"}`, each an id as plain text. The key is absent until the person chooses a design, palette or font for that CV, and an absent key is not written. The importer copies it into `CV.design` (`DesignChoice`): `design` is required there, so a look without one is dropped; `palette` and `fonts` are copied when present; an id outside the pattern of a `DesignChoice` (`^[a-z0-9-]{1,64}$`) drops the whole look, and the CV imports with the default design. A CV without a `look` imports without a design choice. The old global choice (`export-preferences.json`) is not imported: it only ever seeded the CVs that had no look.
- **The rules:** the checker does not see the legacy fixes, so each one is reviewed once, against the review checklist.

## Alternatives considered

- **Finish migration step 5 first.** Rejected by the owner: it does not fit the deadline.
- **Release without the AI draft.** Rejected by the owner. It stays, behind a constant that can turn it off, if it is not reliable in time.
