# Evaluations on the real model

Two evaluations call the on-device model itself, so they run only when asked, on a Mac with Apple Intelligence on. Every
other test of the package uses fakes ([Testing](../README.md#testing)).

## The claim check

`ClaimCheckEvaluation` runs the second check ([ADR 0028](../../docs/architecture/adr/0028-check-each-personal-claim-of-the-ai-draft-again.md)) on the real model, only when asked, on a Mac with Apple Intelligence on. It
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

## The drafting evaluation

`DraftingEvaluation` runs the whole path of the app on the real model: the model drafts each of 37 descriptions (the 6
example descriptions of the app; five written ones per language: a plain one, one with sentences that look like facts
and are not, a sparse one of a title and a few words, one that names no role, and one that tells four jobs; and one
description of the app's end-to-end campaign), `CVDataSanitizer` grounds the draft,
the claim check judges its personal items, and `InventedFacts` counts what the result keeps, loses and invents. A skill
that is no phrase of the description is counted as inferred, not invented, unless a trap of the input holds it or it is a
language, a qualification or a name. `WrittenMeasure` and `WrittenCounts` measure what the draft writes around the facts
against the thresholds of [ADR 0031](../../docs/architecture/adr/0031-let-the-ai-draft-write-around-the-facts.md): a summary, a description on each kept job, technologies and soft skills by kind, the
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
