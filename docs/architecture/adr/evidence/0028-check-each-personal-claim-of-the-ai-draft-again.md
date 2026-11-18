# Evidence for ADR 0028: Check each personal claim of the AI draft again with the on-device model

The measurements behind [ADR 0028](../0028-check-each-personal-claim-of-the-ai-draft-again.md). Every input was invented: no person's data was used. The sets (a) to (e) and the two modes are defined in the ADR's [The measurement](../0028-check-each-personal-claim-of-the-ai-draft-again.md#the-measurement). The ADR says what was decided and why; this file keeps the numbers it rests on, as they were measured.

- **Where it ran.** A Mac mini, macOS 27.0.1, with Apple Intelligence on, on 2026-10-25, with the instruction of `FoundationModelsClaimChecker` (v7c, unchanged since 2026-10-24), the rules of the same commit, batches of 8 and the time limit of 60 seconds. No other host can run it yet: the iOS 26.5 simulator has no on-device model (every call ends in `assetsUnavailable`), and the other Mac at hand, a MacBook Pro, has no Apple Intelligence. The code uses `GenerationOptions(samplingMode: .greedy)`, the name Xcode 27.1 asks for; the runs of 2026-10-24 used its old name, `sampling:`, and one more run with the new name gave the same verdicts, quotes and refusals for all 754 drafts.
- **How the instruction evolved from the spike.** Measured on 2026-10-24, with one call for the whole draft; the instruction has not changed since, and the batches did not change what a call is asked. "Known issues kept" counts the rows among the known issues of the rules whose item the check keeps alone: on the product path each would be a false keep. The probe is 60 rows of the contract: the 20 known issues that the rules had then, the 34 rows where v4 or v5 dropped a claimed item, and the 6 rows of third-party contacts.

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

  v7c is the only version with no false keep on (b) and (c) and a single known issue kept: the mark alone on its line inside a quote, which no measured version but v4 read right, and which a rule of [ADR 0023](../0023-ground-the-ai-draft-in-the-description.md) (c) now holds. v5 drops the fewest items, but it keeps six known issues.

## Measured: v7c, in batches of 8

"No answer" counts the drafts whose check gave no answer: they lose every item of the five kinds, and the editor says so. It is the cost of the strict reading of the answer (the ADR's [Consequences](../0028-check-each-personal-claim-of-the-ai-draft-again.md#consequences)). The latency is per draft; composed, it counts only the drafts the check is called on.

| Set | Mode | False keeps | False drops | No answer | Median latency | p95 latency | Same in repeated runs |
|---|---|---|---|---|---|---|---|
| (a) contract, 890 items | alone | 76, all dropped by the rules | 33 (6.9% of 475 claimed) | 16 of 571 | 1.42 s | 3.92 s | run once |
| (a) contract | composed | **0** | 32 (6.7%), 1 of them by its quote | 30 of 286 called | 1.48 s | 4.89 s | run once |
| (b) adversarial, 141 items | alone | **0** | 4 (7.0% of 57) | 0 of 102 | 1.45 s | 2.21 s | run once |
| (b) adversarial | composed | **0** | 4, 1 of them by its quote, and 6 by the rules | 3 of 42 called | 1.46 s | 2.12 s | yes, 3 runs |
| (c) the spike's held-out, 56 items | alone | **0** | 1 | 0 of 42 | 1.42 s | 2.24 s | run once |
| (c) the spike's held-out | composed | **0** | 1, by its quote | 0 of 12 called | 1.94 s | 2.29 s | yes, 3 runs |
| (d) the new held-out, 66 items | alone | **0** | 1 | 2 of 42 | 1.92 s | 2.25 s | run once |
| (d) the new held-out | composed | **0** | 1, by its quote, and 3 by the rules | 1 of 16 called | 1.98 s | 2.30 s | yes, 3 runs |
| (e) long drafts, 96 items | alone | **0** | 0 | 0 of 3 | 35.3 s | 61.6 s | run once |
| (e) long drafts | composed | **0** | 0 | 0 of 3 | 31.2 s | 60.5 s | yes, 2 runs |

- **Stability.** The verdicts, the quotes and the kept items were identical in every repeated run of the composed mode: three of (b), (c) and (d), two of (e). Alone, each set ran once, and (a) once in each mode (`PRESTOCV_CLAIM_EVAL_RUNS=1`).
- **After the clause rule of the quote proof.** The composed mode ran again over (a) to (e) once the proof refused a quote that leaves out a word of negation, wish or condition of its clause (the ADR's [Decision](../0028-check-each-personal-claim-of-the-ai-draft-again.md#decision)). Every verdict, quote and kept item was identical to the run before it: the same 32, 4, 1 and 1 false drops, no false keep, the same 30, 3, 0 and 1 drafts with no answer for (a) to (d), and none in (e). The latencies were in the same range (contract: median 1.47 s, p95 5.0 s; long drafts: median 31.0 s, p95 59.8 s). The rule cost no item on these sets. What it refuses is held by the tests of `ClaimAnswerTests`.
- **Realistic drafts.** The contract's drafts of 5 to 9 judged items, the size of the real drafts of #202, take 3.7 to 8.3 s alone (25 drafts, median 5.1 s) and 3.9 to 10.4 s composed (24 drafts, median 5.0 s). The row of the first real-model draft of the nurse in Turin took 10.4 s composed, for 7 items in one batch. A draft of one item takes about 1.4 s.
- **Long drafts.** The time grows faster than the number of items judged. Composed: 14 to 15 s for 16 items, 31 s for 26, 58 to 60.5 s for 36. Alone: 18 s for 22, 35 s for 32, 62 s for 42. The composed times include the rules, which took 0.02 s, 0.2 s and 1.06 s for 22, 32 and 42 items: the check itself took 57 to 59.4 s for the largest, under the limit of 60 s, which stops it when it passes.
- **False keeps.**
  - Alone, the check keeps 76 items of the contract that the rows drop: futures, job searches, other people's facts, invented values. Composed, none survives: the rules drop all 76 first.
  - The 19 known issues of the rules: composed, a verdict withdraws the item of 16 (the Konjunktiv typed without its umlaut, the six titles of a person the claim names, the six nouns before a relative of the person, and the relatives of place in English, Spanish and French). The other 3 give no answer, and the items are withdrawn with the others: the relatives of place in Italian and Portuguese (a refusal of the guardrail) and the speech on the colon's line (an answer that does not number its items). Alone, a verdict withdraws 17 and the 2 refusals the others.
- **False drops on the contract.** 32 items composed, by family:
  - interests after "I like" read as a wish: 14 items in 7 drafts, among them the app's own English example. The spike lost 18. The same sentence is a fact in some drafts and a wish in others;
  - chess, stated as a fact beside a wish to speak Spanish better, read as the wish: 2 (English and Spanish);
  - "which I'd like to improve" withdrawing the languages before it: 3;
  - a fact in the sentence after a question, in Italian, Spanish and Portuguese: 3;
  - the obligation "tuve que", "he tenido que": 2;
  - denied high levels and a past wish ("not an expert in Swift", "never been fluent in German", "Ich spreche Spanisch, und davon träume ich nicht mehr"): 3;
  - other single items: 5, among them "francês" in a list of languages in Portuguese, which the model stated as a fact with a quote that the proof refused.

  Alone, one more (33): French after a mark alone on its line, which the composed call, asked about French only, keeps.
- **Against the spike.** The comparison with the spike's 28 false drops was made on 2026-10-24, with one call per draft: on the 317 rows of the spike that are still in the contract, which hold its 388 claimed items, the check dropped 26 items, against 28; the 251 rows added since then by the review rounds of #202 added 8, 34 in all. The batched run was not split by the age of the rows: it drops 32 of 475 claimed items, and loses 33 more in the drafts with no answer. The issue's goal of fewer than 28 false drops holds on the spike's rows only when those drafts are not counted.
- **Refusals.** "Response may contain sensitive or unsafe content":
  - alone, 5 of 571 drafts of (a): "I have no basic German.", "Je n'ai pas de notions d'allemand.", and the relatives of place in Italian, German and Portuguese; and in (d) "Mon collègue parle couramment l'arabe.", whose item nobody claims;
  - composed, 2 of 571: the relatives of place in Italian and Portuguese. The rules drop the items of the others first, so no call is made.
- **Answers that do not number their items.** Alone, 11 of 571 drafts of (a) and 1 of 42 of (d); composed, 28 of the 286 drafts called in (a), 3 of 42 in (b) and 1 of 16 in (d), the same drafts in every run. (The ADR's [Consequences](../0028-check-each-personal-claim-of-the-ai-draft-again.md#consequences).) The amendment of 2026-10-26 closes this cause; the figures of this section were measured before it, and the next section measures it again.

## Measured again: an answer of fixed length (2026-10-26)

- **What changed.** Only the structure of the answer: the dynamic schema of the ADR's [Decision](../0028-check-each-personal-claim-of-the-ai-draft-again.md#decision), in place of a list the model could make as long as it liked. The instruction (the same SHA-256), the sampling, the batches of 8, the time limit and the strict reading of the answer are those of the tables above. The schema is part of the prompt (`includeSchemaInPrompt`), so the prompt is not the same text. Same host and OS as above (a Mac mini, macOS 27.0.1), composed mode, three runs of each set, the verdicts identical in every run.
- **The cause.** Asked about one item that two sentences mention, the model wrote one entry for each sentence, numbered 1 twice or 1 and 2. The strict reading threw `invalidAnswer` and the draft lost every personal item. A probe over five descriptions of the evaluation, one candidate each: before the change every one of them got two entries; after it, one, the same item with the same quote of the first.
- **Sets with an earlier run at the commit before the change.** The earlier run is that of 2026-10-26, with the same instruction and the strict reading.

  | Set | Draft with no answer | False keeps | False drops | Median latency | p95 latency |
  |---|---|---|---|---|---|
  | (b) adversarial, 141 items | 3 of 102 before, **0** after | 0, 0 | 4 before, 5 after | 1.49 s, 1.53 s | 2.13 s, 2.26 s |
  | (c) the spike's held-out, 56 items | 0, 0 | 0, 0 | 1, 1 | 1.97 s, 2.01 s | 2.32 s, 2.41 s |
  | (d) the new held-out, 66 items | 1 of 42 before, **0** after | 0, 0 | 1 before, 0 after | 1.98 s, 2.19 s | 2.31 s, 3.50 s |

  The fifth false drop of (b) is an item of a draft that gave no answer before: its items were all withdrawn as unchecked, and now one is judged and withdrawn by the quote proof (a language stated before a wish). No false keep appeared.
- **The contract, on the same rows.** The 836 drafts of the contract (1,688 items, 740 of them claimed) that exist at both commits, run at the commit before the change (one run, the verdicts being the same in every run) and after it (three runs). No false keep at either. The contract has grown since the first table (571 drafts), so this comparison is on its own rows, not on that table's.

  | | Before | After |
  |---|---|---|
  | Drafts with no answer | 83 | 2, both refusals of the guardrail (the relatives of place in Italian and Portuguese, as before) |
  | Claimed items withdrawn | 119 (16.1%) | 59 (8.0%) |
  | of them, by a verdict or the quote proof (false drops) | 33 | 59 |
  | of them, as items of a draft with no answer | 86 | 0 |
  | Median latency, p95 latency | 1.37 s, 3.27 s | 1.40 s, 3.09 s |

  The false drops by a verdict grew from 33 to 59, which the items judged now are not the only cause of. Of the 29 false drops that are new, 4 are items of drafts that gave no answer before, and 25 are items of drafts checked at both commits whose verdict changed with the prompt (the schema is part of it): the verdict "another person's" went from 5 items to 22. 16 of the 25 are one family, a French language in the rows "a mark alone on its line before a quote of another pair inside a quote closes nothing", which the check now reads as another person's although the rules keep it. 3 of the 33 earlier false drops are kept now. The 59 are 34 languages, 19 interests, 4 skills, a title and a place (the 33 were 13 languages, 16 interests and 4 skills); the families of the first table (interests after "I like", a fact beside a wish, a fact after a question, an obligation) are still among the largest. These are losses, not leaks: the check only removes, and no false keep appeared. The rows of the contract test the rules with unusual text, so the figure is a ceiling for the check on such text, not a rate for real descriptions; on (b), (c) and (d), the sets written as people write, the same change moved the false drops by +1, 0 and -1. The French family is the cost of this change that is not yet closed.
- **What the figures say.** The drafts that gave no answer because the answer had the wrong number of entries are gone: the 3 of (b), the 1 of (d) and the 81 of the contract's 836 drafts (83 with the 2 refusals) at the commit before the change; the 28 of the 286 called drafts of the first table were the same cause. A check that gives no answer is now a refusal of the model's guardrail, a failed call or the time limit. The cost is not zero: the items that used to go with the drafts that gave no answer are now judged, and the check withdraws some of them (the fifth false drop of (b), 4 of the contract's 29 new ones). Counted over all the claimed items of the contract, the loss halves, from 16.1% to 8.0%.
- **Not measured again.** The long drafts (e): the batches of 8 and the time limit are those of the first table, and the latency of the other sets did not grow, but the table of (e) above was not repeated. Another OS release: as in the ADR's [Consequences](../0028-check-each-personal-claim-of-the-ai-draft-again.md#consequences).
