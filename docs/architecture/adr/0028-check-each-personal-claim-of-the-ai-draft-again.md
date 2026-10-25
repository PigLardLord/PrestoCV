# 0028. Check each personal claim of the AI draft again with the on-device model

- **Status:** Accepted
- **Date:** 2026-10-24
- **Related:** [ADR 0023](0023-ground-the-ai-draft-in-the-description.md), [ADR 0007](0007-each-package-owns-its-model.md), issues #202, #249

## Context

- **Why a second check.** The word rules of ADR 0023 decide whether a clause claims a fact. Three review rounds on #202 kept finding rarer variants of the same two families that the rules read as facts: wishes and denials. The last variant is text typed without accents. No word rule tells "seria" (serious) from "sería" (would be), or "wurde" (was) from "würde" (would): "Am liebsten wurde ich Spanisch lernen" keeps Spanisch, an open residual risk of ADR 0023. Later rounds added four families that need a reading of the relations inside a clause (whose words, whose title and place, whose verb) and a mark alone on its line, all open residual risks of ADR 0023.
- **What is at stake.** ADR 0023 (f): an invented or misattributed fact blocks the release.
- **What the owner asked (#249).** A second, independent check by the on-device model, measured first and then decided. A spike measured it on 2026-10-19; the owner decided to ship it in version 1 on 2026-10-24, with option (ii) below when the check gives no answer.

## Decision

- **Scope.** After the rules of ADR 0023, `CVGeneratorUseCase.generateCV` asks the claim check about the personal items that the grounded draft still keeps: the skills, the languages, the interests, the headline title and the place (`ClaimCandidates`). It then orders the jobs and validates the draft, as before.
- **What stays out.** Employers, schools, dates, certifications and prose stay with the entry rules of ADR 0023: the model judges them worse than the rules do (50 to 66 false drops on the contract in the spike).
- **An item stays only when both checks keep it.** The check can only withdraw (`ClaimWithdrawal`); a language goes with its level.
- **How the call is made.** One call per draft to Apple's on-device model (`FoundationModelsClaimChecker`), with a fixed instruction, greedy sampling and structured output (`@Generable`). For each item, the model copies the sentence that mentions it, then answers whose the item is (the writer, someone else, or not mentioned) and how the sentence states it (as true, wished, conditional or denied). An item is a fact only when it is the writer's and stated as true. A verdict that the answer leaves out withdraws its item, so the check fails closed.
- **When the check gives no answer (option (ii)).** A failed call and a refusal of the model's guardrail are the same path. The draft keeps its jobs, schools, dates and prose, and every item of the five kinds is withdrawn. `GeneratedDraft.personalItemsUnchecked` is true, and the editor's notice adds a line under the reminder to check the draft: "We could not check your skills, languages, interests, job title and place, so they are left blank. Add them yourself." There is no retry, never a fallback to the rules alone, and never "no draft" for a refusal that would repeat on the same text. The line is shown only then: a check that ran and withdrew some items says nothing more.
- **Cancellation** passes through as `CancellationError`, and gives no draft.
- **Where it lives.** The check, its candidates, the withdrawal and the result type are in the `CVGeneratorAI` package. The package imports no other package (ADR 0007): the app's `ViewModelFactory` gives the use case its `FoundationModelsClaimChecker`. The notice is an `EditorNotice` case chosen in `AIDraft`, outside the views; the banner only shows the lines it is given.
- **Tests.**
  - The unit tests of the use case and of the withdrawal use a fake check, so they need no model: they run on any Mac (the legacy target is Apple-only, ADR 0012). The app's unit tests use a fake check too, on every simulator, iOS 26.5 included.
  - `ClaimCheckEvaluation` runs the real model on Apple hosts, only when asked (`PRESTOCV_CLAIM_EVAL`), over the sets below, three times each, and fails on any false keep or on verdicts that differ between runs.
  - The contract of ADR 0023 still judges the rules alone, so its known issues stay known issues of the rules; (a), composed, fails on any item of theirs that both checks keep. The mark alone on its line inside a quote left that list: a rule of ADR 0023 (c) now holds it.
  - Debug builds only: the launch arguments `-PrestoCVUITestsScriptedDraft nurse` (a scripted answer of the model, for simulators that cannot run it) and `-PrestoCVUITestsClaimCheck fail` (a check that throws) let the UI tests and the end-to-end campaign reach the unchecked draft. No release path reads them.

## The measurement

- **Where it ran.** The Mac mini, macOS 27.0.1, with Apple Intelligence on, on 2026-10-24, with the instruction of `FoundationModelsClaimChecker` and the rules of the same commit. No other host can run it yet: the iOS 26.5 simulator has no on-device model (every call ends in `assetsUnavailable`), and the MacBook has no Apple Intelligence. The runs used `GenerationOptions(sampling: .greedy)`; the code uses its rename, `GenerationOptions(samplingMode: .greedy)`, which Xcode 27.1 asks for. One more composed run over (a) to (d) with the rename gave the same verdicts, quotes and refusals for all 754 drafts.
- **The sets** (`ClaimCheckEvaluation`, `AdversarialClaims`).
  - (a) **The contract.** Every row of `GroundingContractTests` whose draft holds a personal item: 568 drafts and 884 items. The items a row keeps count as claimed (473); the items it drops count as not claimed.
  - (b) **The adversarial set.** 102 sentences with 141 items (57 claimed), in the six languages: the 77 of the spike, and 25 added while the instruction was tuned, for likings beside wishes, obligations, questions, lists under a heading and wishes to improve.
  - (c) **The spike's held-out set.** 42 sentences with 56 items (22 claimed). The instruction of this ADR was tuned with it in view, so it is now a regression set.
  - (d) **The new held-out set.** 42 sentences with 66 items (32 claimed), in the six languages, written before their first run and never used to choose the instruction.
- **Two modes.** Alone, the check judges every item of the set, as when the instruction is tuned. Composed, it judges only what the rules keep, as the product does, and an item stays when both keep it.
- **How the instruction evolved from the spike.** "Known issues kept" counts the rows among the known issues of the rules whose item the check keeps alone: on the product path each would be a false keep. The probe is 60 rows of the contract: the 20 known issues that the rules had then, the 34 rows where v4 or v5 dropped a claimed item, and the 6 rows of third-party contacts.

  | Version | Change | (b) false keeps | (b) false drops | (c) false keeps, drops | Known issues kept | (a) false drops |
  |---|---|---|---|---|---|---|
  | v3 | the spike | 0 | 1 (77 sentences) | 0, 0 | 0 of 1 | 28 of 388 claimed |
  | v4 | employers left out | 0 | 1 (77 sentences) | 0, 0 | 5 | 41 of 472 |
  | v5 | "names" for "mentions"; lists under a heading are the writer's; a question states nothing; "like", "love", "enjoy" and "had to" are facts; a wish to improve takes no fact back; only "I'd like" and "I would like" are wishes; each item judged by its own sentence | 0 | 2, and 1 refusal | not run | 6 | 11 of 472 |
  | v6 | v5, and groups ("the team", "everyone") and quoted words are someone else's | 2 | 8 | 0, 4 | 1 | not run |
  | v7a | v5, and the verb of someone the writer names is not the writer's | 1 | 2 | 0, 0 | 2 | 12 on the probe |
  | v7b | v7a, with "a wish or a condition in another sentence does not change this one" | 4 | 2 | 0, 0 | 1 | 15 on the probe |
  | **v7c** | v7b, without "copy the one that states it most plainly" | **0** | 3 | **0, 0** | 1 | 22 on the probe, 35 of 473 |
  | v7d | v7a, and words between quotation marks stay someone else's over several lines | 4 | 2 | 1, 0 | 1 | 13 on the probe |

  v7c is the only version with no false keep on (b) and (c) and a single known issue kept: the mark alone on its line inside a quote, which no measured version but v4 read right, and which a rule of ADR 0023 (c) now holds. v5 drops the fewest items, but it keeps six known issues.

### Measured: v7c

| Set | Mode | False keeps | False drops | Refusals | Median latency per draft | p95 latency per draft | Same in 3 runs |
|---|---|---|---|---|---|---|---|
| (a) contract, 884 items | alone | 89, all dropped by the rules | 35 (7.4% of 473 claimed) | 5 | 1.41 s | 3.92 s | run once |
| (a) contract | composed | **0** | 34 (7.2%) | 2 | 1.45 s | 4.86 s | run once |
| (b) adversarial, 141 items | alone | **0** | 3 (5.3% of 57) | 0 | 1.47 s | 2.20 s | yes |
| (b) adversarial | composed | **0** | 3, and 6 by the rules | 0 | 1.48 s | 2.09 s | yes |
| (c) the spike's held-out, 56 items | alone | **0** | 0 | 0 | 1.41 s | 2.24 s | yes |
| (c) the spike's held-out | composed | **0** | 0 | 0 | 1.92 s | 2.28 s | yes |
| (d) the new held-out, 66 items | alone | **0** | 0 | 1 | 1.88 s | 2.26 s | yes |
| (d) the new held-out | composed | **0** | 0, and 3 by the rules | 0 | 1.96 s | 2.24 s | yes |

The composed latency counts only the drafts the check is called on: 284 of the 568 of (a), 42 of 102 of (b), 12 of 42 of (c) and 16 of 42 of (d). The rules leave nothing to check in the others.

- **Stability.** The verdicts, the quotes and the kept items were identical in all three runs of (b), (c) and (d), in both modes. (a) ran once in each mode (`PRESTOCV_CLAIM_EVAL_RUNS=1`).
- **Realistic drafts.** The contract's drafts of 5 to 9 items, the size of the real drafts of #202, take 4.0 to 7.4 s alone (median 5.1 s), and 3.9 to 10.2 s composed (median 5.0 s): the row of the first real-model draft of the nurse in Turin took 10.2 s composed for 7 items, and 7.4 s alone for 9. A draft of one item takes 1.4 s, about 0.7 s more for each item after it.
- **False keeps.**
  - Alone, the check keeps 89 items of the contract that the rows drop: futures, job searches, other people's facts, invented values. Composed, none survives: the rules drop them first.
  - The 19 known issues of the rules: composed, a verdict withdraws the item of 17 (the Konjunktiv typed without its umlaut, the speech on the colon's line, the six titles of a person the claim names, the six nouns before a relative of the person, and the relatives of place in English, Spanish and French). The other 2, the relatives of place in Italian and Portuguese, get a refusal of the guardrail, which withdraws every item and shows the notice.
- **False drops on the contract.** 34 items composed, by family:
  - interests after "I like" read as a wish: 14 items in 7 drafts, among them the app's own English example. The spike lost 18. The same sentence is a fact in some drafts and a wish in others;
  - chess, stated as a fact beside a wish to speak Spanish better, read as the wish: 5, one per language of the row;
  - "which I'd like to improve" withdrawing the languages before it: 3;
  - a fact in the sentence after a question, in Italian, Spanish and Portuguese: 3;
  - the obligation "tuve que", "he tenido que": 2;
  - denied high levels and a past wish ("not an expert in Swift", "never been fluent in German", "Ich spreche Spanisch, und davon träume ich nicht mehr"): 3;
  - other single items: 4.

  Alone, one more (35): French after a mark alone on its line, which the composed call, asked about French only, keeps.
- **Against the spike.** On the 317 rows of the spike that are still in the contract, which hold its 388 claimed items, the check drops 26 items, alone and composed, against the spike's 28. The 251 rows added since then by the review rounds of #202 add 8: questions (3), "que" obligations (2), a possessive, a line introduced by a colon, and "Pläne" before Python. The issue's goal of fewer than 28 false drops holds on the spike's rows; on the grown contract it is 34.
- **Refusals.** "Response may contain sensitive or unsafe content":
  - alone, 5 of 568 drafts: "I have no basic German.", "Je n'ai pas de notions d'allemand.", and the relatives of place in Italian, German and Portuguese;
  - composed, 2 of 568: the relatives of place in Italian and Portuguese. The rules drop the items of the others first, so no call is made;
  - (d), alone, "Mon collègue parle couramment l'arabe.", whose item nobody claims; composed, the rules drop it first.

## Consequences

- **What it closes.** On the product path, no false keep on the 1,147 items of the four sets. That covers the families that the word rules cannot read: text typed without accents, the other variants of mood measured, whose words, whose title and place, whose verb, and the relatives of place. The mark alone on its line inside a quote is closed by a rule of ADR 0023 (c), not by the check, which keeps it alone.
- **What stays open.** A message with a lone symbol and no closing mark of its own (ADR 0023, Consequences): neither the rules nor the check tell it from a quote that the symbol closes.
- **What it costs.**
  - **Latency.** About 1.4 s for a draft with one item, and 4 to 10 s for a realistic one (median 5 s), on top of the 7 to 12 s that generation takes on the same Mac.
  - **Losses.** 7.2% of the claimed personal items of the contract are withdrawn on the product path (34 of 473). A withdrawn item is left out of the draft, never changed. The largest family is still interests after "I like" in English (14 items), read as a wish in some drafts and not in others. Next comes an interest stated beside a wish, read as the wish (5).
  - **Refusals.** The guardrail refuses some benign sentences, 2 of the contract's 568 drafts on the product path. Under option (ii) those descriptions still give a draft: its jobs, schools, dates and prose, without the personal items, with the notice.
- **The check is not a replacement for the rules.** Alone, it keeps 89 items of the contract that the rules drop. It is safe only behind them, and the contract of ADR 0023 still judges the rules alone.
- **Model versions.** The model changes with the OS. `ClaimCheckEvaluation` must run again, every set in both modes, on each OS release that may change the model. It ran on macOS 27.0.1 only. An iOS 26 device, which may carry an older model, is the owner's check before release, since the iOS 26.5 simulator has no model.
- **Determinism.** Greedy decoding gave the same verdicts and quotes in every repeated run. Verdicts still depend on the other items of the same call. A composed call holds fewer items than an alone one, and "Parlo inglese e vorrei imparare il russo" keeps "inglese" alone but withdraws it composed, when "russo" is no longer asked. On the product path no such change kept a false item: the composed false keeps are 0 in every set.
- **Tuning.** The instruction was chosen on (a), (b) and (c). Only (d) measures it on wordings it was not tuned on: there the check has no false keep and no false drop.

## Alternatives considered

- **More word rules.** Rejected: three review rounds found new variants each time, and accents cannot be recovered by rule.
- **The model alone, replacing the rules.** Rejected by the measurement: alone it keeps futures, job searches and other people's facts that the rules drop.
- **Including employers and schools.** Rejected by the measurement: 50 to 66 false drops on the contract.
- **No draft when the check gives no answer (option (i)).** Rejected by the owner: a guardrail refusal repeats on the same text, so the person could never get a draft from that description.
- **One call per item.** It avoids verdicts that change with the other items, at about 1 s per item, so 5 to 9 s more for a realistic draft. Not taken: one call per draft already gives no false keep on the product path, and one call per item would double the wait for a realistic draft. Its gain, fewer losses such as the interests after "I like", is not measured; it stays the next step if those losses matter in use.
