# 0035. Judge the AI draft by whether it helps the person get hired

- **Status:** Proposed
- **Date:** 2026-11-05
- **Related:** [ADR 0031](0031-let-the-ai-draft-write-around-the-facts.md) (amended), [ADR 0023](0023-ground-the-ai-draft-in-the-description.md), [ADR 0028](0028-check-each-personal-claim-of-the-ai-draft-again.md), [ADR 0033](0033-change-the-legacy-app-only-to-fix-the-published-version.md), [ADR 0005](0005-remove-ai-tailoring-and-json-resume.md), issues #354, #356, #359, #368, #253, #221

## Context

- **The goal.** The owner set it on 2026-11-05: "fare assumere le persone con cv rifiniti che passino i test, non controllare ogni singola parola" (people get hired with polished CVs that pass the tests, not a check of every word).
- **What a CV must pass.** Three readers, in this order:
  - an applicant tracking system reads its text into fields;
  - a recruiter reads it quickly;
  - an interview or a background check tests what it says.

  A typical skill the person really has helps at all three. An invented fact can pass the first two and fails at the third, where it costs the person the job.
- **What the measure checks today.** ADR 0031 keeps a written sentence only when it passes word rules (`WrittenText`: no number, no word of seniority, no name, no negation, no word of another job), and its GO counts what those rules and the reader classes find. Six cycles of #354 and the round of #359 tuned word rules against reader findings, and the owner's tries of 1.0 found drafts that were safe and not credible (2026-10-28, 2026-11-05).
- **The rules block what the owner asks for.** The owner wrote on 2026-11-05 that an iOS developer of 8 years certainly knows Xcode and Swift and is familiar with Apple's frameworks, and that an electrician of 10 years can carry a system from design to commissioning "a regola d'arte" and knows the norms of the trade: "queste piccolezze spesso fanno la differenza" (these small things often make the difference). Under ADR 0031 a written sentence with "Xcode" or "CEI" goes as a name (rule 6), one with "8 anni" goes for its number (rule 1), and one with "esperto" goes for its seniority word (rule 2).
- **How such systems are measured.** The usual method for a model's output is error analysis first: a domain expert reads about a hundred outputs, names the failures seen, and only those get a check, each one pass or fail and not a score, and a model judge only after it agrees with the expert's labels on data it was not tuned on. A change is compared with the one before on the same inputs, both ways round, with error bars. Sources: Husain and Shankar's evaluation guide; Shankar et al., arXiv 2404.12272 (criteria drift); Miller, arXiv 2411.00640 (error bars and paired differences).
- **The platform.** The draft runs on the device's model. From the 27 releases Apple's Evaluations framework runs evaluations with code checks and model judges in a test target, and the adapters of the model are no longer supported, so a fine-tuned model is no lever. Private Cloud Compute is the owner's decision (#253).

## Decision

**The owner decided on 2026-11-05** to judge the AI draft by whether it helps the person get hired, never to invent a fact, and to infer what the person's years and trade imply. This amends ADR 0031 where it says otherwise; its text stays as it was decided.

### What the draft may infer

The draft infers what any person of that trade, with those years, knows and does. It is draft content, not a fact, and the person edits it:
- **The core tools of the trade:** the tools, languages, frameworks, machines and methods that the trade uses every day. An iOS developer of 8 years: Xcode, Swift, Apple's frameworks.
- **Familiarity with the trade's norms and standards,** by their common names, said as familiarity or as working to them, never as a certification: an electrician works "a regola d'arte, secondo le norme CEI".
- **Responsibility that matches the years:** a job of many years may carry its work from start to end, lead it, or train others. An electrician of 10 years carries a system from design to commissioning.
- **A length of experience and a word of seniority that the facts support:** a number of years the description states, or that its dates give (rounded down); "senior", "esperto" or "experienced" only when those years support it for the trade.

### What the draft never invents

A fact can be checked against a document, a register or a former employer, so it is never invented:
- every fact of ADR 0031: a job the person did not hold, the name, the contacts, the places, the job titles, the employers, the schools, the degrees, the dates, every number and figure, the achievements, the languages and their levels, the interests;
- **a certification, a licence, a registration or a legal qualification** (a certificate, an "abilitazione", a professional register, the right to sign a declaration that the law reserves to a qualified person);
- the name of a customer, a product, a project or a person, and a result with a figure.

**The line between them, proposed to the owner:** a trade's competence is inferred ("progettazione e realizzazione di impianti a regola d'arte secondo le norme CEI"), the legal right to sign for it is not. In Italy the declaration of conformity of a system is signed by a firm qualified under DM 37/2008, a status that a register shows, so the draft never writes it; the person adds it when they hold it.

### Which rules of ADR 0031 change

In the new AI Drafting targets (`CVDrafting`, `CVDraftingFoundationModels`, migration step 6):
- **Lifted from `WrittenText`:**
  - the number part of rule 1 and the duration and seniority words of rule 2, replaced by the rule on years and seniority above (an address, a month and a level stay facts);
  - rule 6 (no name) for the name of a tool, a framework, a method or a norm of the trade (the name of an employer, a school, a place or a person stays a fact);
  - rule 3 (no negation) and the word part of rule 5 (another job's words), which become failure modes judged on the whole draft.
- **Lifted from `InferredSkills`:** the digit rule, for the name of a tool or a norm that holds one ("ISO 9001", "CEI 64-8").
- **Kept:** every rule about a fact of the list above; rule 4 (a word the person claims only in a wish, a denial or another person's clause gives nothing); rule 7 (no character the reader cannot see); `InferredSkills`' rules on a level, a language and a qualification word; the counts of ADR 0031 (4 to 8 technologies, 3 to 5 soft skills, a summary of 2 to 4 sentences).
- **How a kept rule is enforced** (a code rule, a list, a narrow on-device question) is chosen by the measurement below: a check guards the person's facts in the app only when its pass or fail agrees with the owner's labels at the rates a judge needs.

The legacy target `CVGeneratorAI` changes only as ADR 0033 allows: a part of this decision reaches version 1.0.x as a fix only when its issue records the owner's decision that it fixes the published version.

### The measurement

It replaces the GO of ADR 0031 for a change of the draft, and keeps its limits on time (95th percentile at most 90 s) and failed runs (none).
- **Inputs:** invented descriptions only, never a real person's text. They cover the trades, the six languages, the length of experience (a first job to 20 years), and sparse and rich descriptions. They are split once: about 20% shown to the judges as examples, 40% for tuning, 40% kept untouched for the GO.
- **Error analysis first.** The owner reads the drafts of at least 100 inputs and labels each pass or fail with a note: would this CV help this person get called, and does it say anything they would have to deny at an interview? The notes are grouped into failure modes, and each mode has a written pass or fail definition. The owner reads a new sample at each release that changes the draft, and the modes are revised.
- **One check per failure mode,** pass or fail, no scores. A mechanical mode is checked by code: a number, a date, a language or a qualification the facts lack, the text read back from the PDF. Any other mode is judged by a model. A model judge counts for GO only when, on the untouched split, its true-positive and true-negative rates against the owner's labels are each at least 0.9.
- **What is judged is what the person gets:** the CV as the editor shows it after the mapping, and its exported PDF, not the model's answer.
- **The tracking-system read:** the text of the exported PDF, read back by the app's import (ADR 0027), gives the same name, contacts, titles, employers, dates and sections, in order, for every input.
- **GO for a change:** no invented fact on the untouched split, every check above its threshold, and a win in a blind comparison with the current draft. The comparison sees the two drafts of one input in both orders and counts a win only when both orders agree; the paired difference over the inputs is reported with its 95% interval, clustered by input, and the interval lies above zero.
- **Where judges and optimizers run:** a model off the device, as a judge or as a prompt optimizer, runs only in development and only on invented inputs. The app never sends a person's text off the device for this; the draft itself stays on the device unless the owner decides #253. Credentials for it are never in the repository.

### Tailoring comes later

Writing the CV for a given job ad is tailoring (#221, #107): it is decided apart, and ADR 0005 stands until then. This decision is about the draft from the person's own description.

## Consequences

- **Easier:** the draft can say what makes a CV credible (the trade's tools, its norms, the scope that the years give) without a word rule against each finding; a change is kept because it measurably helps, not because it passes another rule.
- **Harder:** a model judge has to be calibrated and kept calibrated, and some failures (a seniority word for too few years, a norm of another trade) are judged by a model, not by code.
- **Cost:** about 5 to 7 weeks of work in the new targets, and 3 to 5 hours of the owner's time to label about 150 drafts. The plan, its steps and its levers (a simpler pipeline, examples per language, prompt optimization, the sections shown as they are ready, #356; a list of the tools of each trade, #368) are in the issue that implements this decision.
- **Risk the owner accepts:** an inferred tool or norm can be wrong for this person, as ADR 0031 already accepts for a typical duty; the person edits the draft, and the editor's notice asks them to check it.
- **Checks:** the failure modes, their definitions and the owner's labels of the invented inputs are kept with the evaluation's inputs, and the evaluation's report lists each check's rates and the comparison's interval.

## Alternatives considered

- **Keep the word rules and tune them further.** Each round found a narrower case of the same class (#354, #359), and the rules remove exactly the content the owner asks for.
- **Remove every check and trust the prompt.** The device's model invents employers, dates and levels when nothing stops it (#202, #354); the facts keep their checks.
- **Scores from 1 to 5 by a judge.** Scores drift and do not say what to fix; pass or fail per failure mode, calibrated on the owner's labels, does.
- **A fine-tuned model on the device.** The adapters are no longer supported from the 27 releases.
- **A judge with no calibration.** A model that screens CVs has been reported to prefer CVs written by a model, most of all by itself (arXiv 2509.00462); without agreement measured against the owner's labels a judge's verdict is not evidence.
