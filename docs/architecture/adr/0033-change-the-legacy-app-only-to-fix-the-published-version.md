# 0033. Change the legacy app only to fix the published version

- **Status:** Accepted
- **Date:** 2026-11-04
- **Related:** [ADR 0022](0022-ship-legacy-app-as-v1.md) (amended), [ADR 0012](0012-legacy-targets-during-migration.md), [ADR 0025](0025-hold-the-legacy-app-to-the-separation-rules.md), [ADR 0027](0027-import-a-cv-from-its-text-with-rules.md), [ADR 0030](0030-log-through-one-interface-that-carries-no-cv-content.md), issues #325, #356, #359, #362, #363

## Context

- **What ADR 0022 decided.** Until version 1 was submitted, a change to a legacy target was allowed when it fixed a bug or added a version 1 feature. It did not say what holds after the submission, so ADR 0012's "never modified except to delete it or to keep the app building" applied again: ADR 0030 and #325 call the legacy code frozen.
- **Version 1 is submitted.** Version 1.0, build 126.1, went to App Review on 2026-11-03. The legacy targets are what users have until the app switches to the new stack at the end of [migration step 5](../README.md#migration-strategy).
- **The owner's try of the release candidate found bugs in the AI draft** (2026-11-03):
  - the current job ends with the app's word for "present", not the CV's (#363);
  - a duty is said twice in two tenses, past jobs keep their duties in the present, a duty goes under the wrong job, and a duty says more than the person said (#362).

  #359 lists the defects that the drafting evaluation found when the full draft was merged (#354).
- **The new stack cannot carry the fixes yet.** The AI draft moves to it in migration step 6, after the switch in step 5. Neither is done, so a fix made only there reaches users after the switch.

## Decision

**The owner decided on 2026-11-04** that the 1.0.1 fixes go into the legacy code, and that "nel codice vecchio possono entrare solo correzioni di bug della versione pubblicata, niente funzioni nuove" (only fixes of bugs of the published version may go into the old code, no new features). This amends [ADR 0022](0022-ship-legacy-app-as-v1.md), whose text stays as it was decided.

- **From the submission of version 1 until the app switches to the new stack,** a change to a legacy target is allowed only when it fixes a bug of the published version, or keeps the app building ([ADR 0012](0012-legacy-targets-during-migration.md)).
- **A bug** is a behaviour of a version 1 feature that:
  - differs from what its ADRs, its documentation or its issue say it does;
  - or loses data, crashes, or breaks a requirement of the platform or the store.

  A fix may add code, rules, data or tests to correct it.
- **A new feature is not a fix,** even when it is small. A feature is something the person can do or see that version 1 does not offer, such as:
  - a screen, a control or a setting;
  - a section of the CV;
  - a way to bring a CV in;
  - a new way to show a result.

  It is built in the new targets, and it reaches users with the new stack.
- **Each fix names its issue and starts with a failing test** ([rules.md](../rules.md), "Bug fixes start with a failing test"). When the issue does not make clear whether a change is a fix or a feature, the owner decides, and the issue records the decision.
- **The rest of ADR 0022 stands:**
  - the legacy targets keep the checks they have today ([ADR 0012](0012-legacy-targets-during-migration.md), [ADR 0025](0025-hold-the-legacy-app-to-the-separation-rules.md)) and get no others;
  - a new target never depends on a legacy target;
  - migration step 7 deletes the legacy code.

## Consequences

- **1.0.1 can fix the draft the owner tried.** #363, #362 and #359 are bugs of the published draft. #359 names the trade-tools source as the lever for its first item, the tools that are verbs, concepts or the machines of another job. That source corrects what the draft writes, so it is a fix under this rule.
- **Features wait for the new stack:**
  - #356, which fills the draft in on screen as each part is ready: it is a new way to show a result;
  - the 1.1 import (#167, #166, #265: a PDF or a scan, LinkedIn's archive, other files): it is a new way to bring a CV in.

    Its readers can be built in the new targets, such as `PrestoCVImporting`, at any time. It reaches users only after migration step 5, because offering it in the legacy app would change a legacy target for a feature.
- **A fix's test moves with its code.** When the code a fix covers moves to the new stack (steps 5 and 6), its test moves too, so the switch does not bring the bug back.
- **"Frozen" in ADR 0030 and #325 now means this ADR's rule.** A fix leaves the legacy code's direct `os.Logger` calls as they are: they move to the interface with their code ([ADR 0030](0030-log-through-one-interface-that-carries-no-cv-content.md)). #325 covers only the new targets, so it does not change.
- **No check enforces it.** The checker cannot tell a fix from a feature, and it does not see the legacy targets. The review of each legacy change checks three things, once, against the review checklist, as ADR 0022 said:
  - the change names its issue;
  - the issue describes a bug of the published version;
  - a test fails without the fix.

## Alternatives considered

- **Freeze the legacy code from the submission.** Rejected by the owner: 1.0.1 could not fix the draft that their try found wanting, and users would keep those bugs until the switch.
- **Fix the bugs only in the new stack.** Rejected: the AI draft moves there in step 6, after step 5, so the fixes would reach users only after the switch.
- **Allow new features in the legacy code too.** Not chosen by the owner, whose decision allows no new features in the old code. The legacy code is deleted in step 7, so a feature built there would be built twice.
- **Let a feature built in the new targets reach users through the legacy app,** with only its wiring (a button, a sheet, the composition) in a legacy target, as the import of version 1 did ([ADR 0027](0027-import-a-cv-from-its-text-with-rules.md)). Not chosen, for the same reason: the wiring is a new feature in the old code. This alternative would let the 1.1 import ship before migration step 5.
