# 0025. Check each personal claim of the AI draft again with the on-device model

- **Status:** Proposed
- **Date:** 2026-10-19
- **Related:** [ADR 0023](0023-ground-the-ai-draft-in-the-description.md), issues #202, #249

## Context

- **Why a second check.** The word rules of ADR 0023 decide whether a clause claims a fact. Three review rounds on #202 kept finding rarer variants of the same two families that the rules read as facts: wishes and denials. The last variant is text typed without accents. No word rule tells "seria" (serious) from "sería" (would be), or "wurde" (was) from "würde" (would): "Am liebsten wurde ich Spanisch lernen" keeps Spanisch, an open residual risk of ADR 0023.
- **What is at stake.** ADR 0023 (f): an invented or misattributed fact blocks the release.
- **What the owner asked (#249).** A second, independent check by the on-device model. It is measured first, then decided in this ADR.

## The spike

- **The check.** One call to Apple's on-device model per draft judges every candidate item:
  - a fixed instruction, greedy sampling, and structured output (`@Generable`);
  - for each item, the model copies the sentence that mentions it, then answers two questions about it:
    - the owner: the writer, someone else, or not mentioned;
    - the mood: stated as true, wished, conditional or denied;
  - an item is a fact only when its owner is the writer and its mood is "stated as true";
  - an item the answer leaves out counts as not mentioned, so the check fails closed.
- **Where it ran.** The Mac mini, macOS 27.0.1, with Apple Intelligence on. The code is on the local branch `spike/claims-model-check`: `ClaimCheck/`, plus the opt-in suite `ClaimCheckEvaluation`.
- **The sets.**
  - (a) **The contract.** Every row of `GroundingContractTests` whose draft holds a personal item: 372 drafts and 651 items. The items a row keeps count as claimed (388); the items it drops count as not claimed (263).
  - (b) **The adversarial set.** 77 sentences with 101 items, in the six languages, written while the instruction was tuned:
    - accentless forms, wishes and conditionals;
    - denials of basic and of high levels;
    - other people's clauses, fronted forms and CV-style fragments.
  - (c) **The held-out set.** 42 sentences with 56 items in the six languages, written after the instruction was frozen.
- **How the instruction evolved.**

  | Version | Change | (b) false keeps | (b) false drops | (a) false drops |
  |---|---|---|---|---|
  | v1 | one stance per item | 7 | 0 | not run |
  | v2 | owner and mood, plus the quote | 0 | 2 | 87 (50 of them employers) |
  | v3 | adds employers, "I like", futures and job searches | 0 | 1 | 87 (66 of them employers) |

  The model reads "at Acme" as someone else's, so employers and schools are left out of the check.

### Measured: v3, judging skills, languages, interests, the headline title and the place

| Set | False keeps | False drops | Errors | Median latency per draft | p95 latency per draft | Same in 3 runs |
|---|---|---|---|---|---|---|
| (b) adversarial, 101 items | **0** | 1 (0.99%) | 0 | 1.14 s | 1.78 s | yes |
| (c) held-out, 56 items | **0** | 0 | 0 | 1.14 s | 1.87 s | yes |
| (a) contract, 651 items | see below | 28 (7.2% of 388 claimed) | 2 | 1.14 s | 4.19 s | not run |

- **Stability.** The verdicts and the quotes were identical in all three runs of (b) and of (c).
- **The real drafts.** The seven drafts of the first real-model run (#202) hold 5 to 9 items each. The check takes 4.0 to 6.7 s for each (median 5.05 s). On them it would withdraw nothing that the rules keep.
- **False keeps on the contract.**
  - Alone, the model keeps 50 items that the rows drop, and 5 more on rows of accepted losses: futures, job searches, third persons, invented values.
  - Behind the rules, none of these survives, because the rules drop them already.
  - The one item the rules still leak, "Am liebsten wurde ich Spanisch lernen", the model withdraws.
- **False drops on the contract**, 28 items:
  - interests "In my free time I like chess and hiking" read as a wish: 18. This is the app's own English example in two of the drafts, while the same sentence was judged a fact in the drafts with other items;
  - "which I'd like to improve" withdrawing the languages before it: 3;
  - denied high levels ("not an expert", "never been fluent"): 2;
  - a list after "Compétences :": 2;
  - other single items: 3.
- **Errors.** Two calls were refused with "Response may contain sensitive or unsafe content": "I have no basic German." and "Je n'ai pas de notions d'allemand." That is 2 of 372 drafts.

## Decision (proposed)

- **Scope.** After the rules of ADR 0023, the use case asks the claim check about the personal items the rules keep: skills, languages, interests, the headline title and the place.
- **What stays out.** Employers, schools, dates and prose stay with the entry rules of ADR 0023. The model judges them worse than the rules do.
- **An item stays only when both keep it.** The check can only withdraw.
- **How the call is made.** One call per draft, with a fixed instruction, greedy sampling and structured output. A verdict that is missing withdraws its item.
- **When the call fails, the owner decides between:**
  - **(i) no draft**, and the person is asked to try again, as #249 proposes. A guardrail refusal repeats on the same text, so retrying gives the same refusal;
  - **(ii) the draft without its personal items**: every item the check would have judged is withdrawn, and the rest of the draft stays. This never falls back to the rules alone.
- **Tests.** A fake check in the unit tests of the use case. The evaluation suite runs the real model on Apple hosts over (b) and (c), and any false keep fails it. The contract of ADR 0023 stays as it is: it judges the rules.

## Consequences

- **What it closes.** The accentless family and the other mood variants measured: 0 false keeps on 157 adversarial and held-out items, across the six languages. The known issue of ADR 0023 ("wurde" for "würde") is withdrawn.
- **What it costs.**
  - **Latency.** About 1 s for a short draft, and 4 to 7 s for a realistic one, on top of the 7 to 12 s that generation takes on the same Mac.
  - **Losses.** 7.2% of the claimed personal items of the contract are withdrawn. The visible one is interests after "I like" in English, which the check reads as a wish ("I'd like") in some drafts and not in others. One more iteration of the instruction, or one call per item, may reduce it; neither is measured yet.
  - **Refusals.** The guardrail refuses some benign negations of a language: 0.5% of the contract's drafts. Under (i) those descriptions give no draft at all.
- **The check is not a replacement for the rules.** Alone, the model keeps futures, job searches and other people's facts that the rules drop. It is safe only behind them.
- **Model versions.** The model changes with the OS. The evaluation suite must run again on each OS release, and on iOS 26 devices, which may carry an older model. The spike ran on macOS 27.0.1 only.
- **Determinism.** Greedy decoding gave identical answers in every repeated run, but verdicts depend on the other items in the same call (the "I like chess" case above).

## Alternatives considered

- **More word rules.** Rejected: three review rounds found new variants each time, and accents cannot be recovered by rule.
- **The model alone, replacing the rules.** Rejected by the measurement: it keeps 50 non-claims of the contract that the rules drop.
- **One call per item.** It avoids verdicts that change with the other items. It costs about 1 s per item, so 5 to 9 s for a realistic draft. Not measured.
- **Including employers and schools.** Rejected by the measurement: 50 to 66 false drops on the contract.
