# 0031. Let the AI draft write around the facts

- **Status:** Accepted
- **Date:** 2026-10-27
- **Related:** [ADR 0023](0023-ground-the-ai-draft-in-the-description.md) (amended), [ADR 0028](0028-check-each-personal-claim-of-the-ai-draft-again.md) (amended), [ADR 0022](0022-ship-legacy-app-as-v1.md), issues #202, #203, #354

## Context

- **The draft only extracts.** Under ADR 0023 every value of the draft is a quote of the description: the summary and the role descriptions keep only the clauses they quote, and a skill stays only when the description names it. The instructions said "Use only what the description says" and "The summary restates the description". So the summary was dropped almost always, the role descriptions were mostly dropped, and no skill was added.
- **What the owner found.** The owner tried the AI draft on a Mac with Apple Intelligence on 2026-10-27: it wrote no summary and inferred no technology or skill. The purpose of the draft is the opposite: a complete, credible CV from a few words, which the person then corrects. The draft must hold a summary, a description of each job, and skills of two kinds that fit the person's role and field: technologies (tools, software, methods) and soft skills.
- **What stays at stake.** An invented fact about the person (a name, an employer, a date, a figure, a language, a certification) is still what blocks the release (ADR 0023 (f)). A summary or a skill that the person reads, judges and corrects is not such a fact, as long as it states none.
- **When.** The owner chose to change this before the version 1 submission, which moves by about a week (#354).

## Decision

- **The facts stay grounded, as ADR 0023 and ADR 0028 decide.** The name, the contacts, the home place, the job titles, the employers, the job places, the schools, the degrees, the dates and "current", every number, figure and percentage, the achievements (quoted), the certifications, the languages and their levels, and the interests. No rule of either ADR about them changes, and no row of the grounding contract about them changed.
- **Two passes (`CVGeneratorUseCase`).** The first call extracts the facts with the extraction instructions and `@Guide` texts of #202 (`CVPrompt`, `CVData`), unchanged. The second call (`CVGenerationService.writeDraft`, `DraftWritingPrompt`) sees only the facts the sanitizer kept (`DraftBrief`: the language, the headline title, the numbered titles of the roles and whether each has ended, the studies, the named skills), never the description, and writes the text below (`DraftWriting`). Both outputs are grounded together against the description. Each call has a limit (`DraftingLimits`: 90 s for the first, 45 s for the second); a first call past it fails at `model` with `generationFailed`, a second call past it or failing leaves the facts without written text (`draft.unwritten`). A `serviceFailed` call is tried once more (`draft.retried`). The second answer is bounded in its schema: at most 10 roles, 4 to 8 technologies, 3 to 5 soft skills, 900 tokens.
- **The model writes around them, in the language of the description.** The second pass's instructions (`DraftWritingPrompt`) and its schema ask for:
  - a summary of 2 to 4 sentences on the person's profession and strengths;
  - for each job, 1 or 2 sentences on the responsibilities typical of its title in its field;
  - technologies (4 to 8) and soft skills (3 to 5) that fit the person's roles, studies and field, without a level and none already listed; the sanitizer gives each its `kind` (`Skill.kind`: `technology` or `softSkill`);
  - in none of them a number, a date, or the name of a company, a school, a place or a person, and no "years of experience", "senior", "expert" or "experienced".

  The first pass's instructions keep every fact rule of #202 ("Use only what the description says"), and the second pass's say never to add a language, job, study, certification, hobby, achievement or result. The instruction of the claim check (ADR 0028) does not change.
- **A written sentence is kept only when it states no fact of its own (`WrittenText`).** The summary and each role description are read sentence by sentence. A sentence stays when the rules of ADR 0023 keep it (a quote) or when it is plain: in the language of the description, and with
  1. no address, and no number in digits or in words ("five", "cinque");
  2. no month, and no word of duration, seniority or level that the description does not write ("years", "senior", "expert");
  3. no negation;
  4. no word that the description holds only in a clause that claims nothing for the person (another person's, a wish, a denial, a supposition): "I would like to become a head nurse" gives no "head";
  5. for a job, no word of another job's title or employer, and no restatement of what the description says of another job alone: each clause quoting a sentence that names another employer and not its own ("onde desenvolvo aplicativos para lojas" is Sulware's, not the earlier agency's, #354);
  6. no name. In English, Italian, Spanish, French and Portuguese a capital after the first word is a name, and so is a first word, or any other word, that neither the closed vocabulary nor the device's dictionary knows. In German, where every noun has a capital, a word the device tags as a name (`NLTagger`, scheme `nameType`) is one, and so is a word that the vocabulary and the dictionary do not know as written. In every language a word of capitals ("ACME") is a name. The person's title and the titles and degrees of the draft are the person's own words, and no names.

  A summary that keeps no sentence is nil; the draft is never dropped whole for its text. "A summary holds no number" (ADR 0023 (d)) stays.
- **The dictionary is a port (`WordList`).** The app passes the device's spelling dictionary (`DeviceWordList`: `UITextChecker` on iOS, `NSSpellChecker` on macOS) from its composition root. Where the device has no dictionary of the language, the other rules still apply. The tests use a table of words (`TableWordList`) and no tagger of names, so a contract row has one verdict on every host.
- **Named and inferred skills.** A skill that the description names is a fact: every rule of ADR 0023 and ADR 0028 applies to it as before (claimed by the person, not a hobby, not denied, not wished, not another person's, a level only when stated, the claim check). A skill that the description does not name is inferred, and stays (`InferredSkills`), without a level, only as a plain name of at most 4 words and 40 characters with
  - no digit, and no word of level, duration or seniority that the description does not write ("Advanced Excel", "Senior Java");
  - no language ("Business English"): the languages are the person's facts and are listed apart;
  - no word of a qualification ("Certified Scrum Master", "Abilitazione"): a qualification is a fact;
  - no employer, school, place or person of the draft, and no interest of it;
  - no word that the description holds only in a clause that claims nothing for the person ("I would like to learn Kubernetes").

  The draft keeps at most 8 technologies and 5 soft skills, the named ones of each kind first, and no skill twice.
- **No fact, no inference.** The model writes around the facts only when the draft keeps one about the person: a title, a job or a school. Without one, the summary keeps only its quotes, and none that says what the person likes or quotes a sentence of the description that does (`LeisureMentions.speaksOfLiking`: "Me gusta pasear con mi perro" is no role, #354), and the skills only those the description names, and the validator judges the draft on its facts (`CVValidator`): "this is a test of the app" gives `emptyResult`, never a made-up summary and skills.
- **The claim check judges only named skills.** `ClaimCandidates` keeps the headline title and place, the languages, the interests and the skills the description names. An inferred skill is no candidate: no clause of the description mentions it, so the check would withdraw every one. When the check gives no answer (ADR 0028, option (ii)), every skill goes, named and inferred, and the summary and the role descriptions stay. The line that asks the person to add the skills, languages, interests, title and place stays true and unchanged.
- **The app.** `AIDraftMapper` puts the technologies first, then the soft skills; the stored CV does not change. The editor's notice (`editor.notice.ai_draft`, in the six languages of the app) says that the AI wrote the summary, the role descriptions and the skills, that they are suggestions, and that what the person did not mention is left blank. No field is marked on its own in version 1.

### What it supersedes

- **ADR 0023 (b), for the skills the description does not name.** They are inferred, as above; a named skill is still a quote.
- **ADR 0023 (c), for the role description.** A role description also keeps its plain sentences. The rules of a job's facts, its achievements and its dates, stay.
- **ADR 0023 (d), for the summary and the role descriptions.** A clause of them no longer has to be a quote; a sentence that is no quote must be plain. Achievements are still quotes, and a summary still holds no number.
- **The scope line of ADR 0028.** "The skills" it judges are the skills the description names.

### Tests

- **The grounding contract (`GroundingContractTests`).** New rows, red before their code: plain summaries and typical duties in the six languages (`written-summary-plain-words-*`, `written-role-typical-duties-*`), and a sentence that goes for a digit, a number word, a month, a length, a rank, a field of experience, a negation, a wish, a denial, another person's word, a name, a word no dictionary knows, a German name or acronym, another employer, or a tool the person denies (`written-text-*`, `written-role-*`); inferred skills kept, or dropped for a level, a language, a qualification, a place, a digit, a length, a denial, the caps, a named twin or an interest (`inferred-skill-*`), and `inferred-skill-no-fact-no-inference`. From #354: a title the person states as the headline when its job goes (`a-stated-title-alone-is-the-headline-*`, `a-title-not-stated-is-no-headline-*`, `a-title-the-person-had-*`, `a-stated-title-leaves-the-headline-alone`); a quote of what the person likes as the summary with no role (`a-summary-of-what-the-person-likes-is-no-role-*`, `a-summary-of-a-hobby-*`); the duties of another job (`the-duties-of-another-job-are-not-restated-*`, `the-duties-said-of-the-job-itself-stay`) and the present title on an ended job whose clause leaves a word unexplained (`the-present-title-is-no-title-of-an-ended-job-*`); "I plan the night shifts" as an activity (`i-plan-the-*`). The rows that dropped a summary or a role description only for being no quote keep it now, each with a line that cites this ADR: `example-de`, `probe-de`, `probe-es`, `probe-long-en`, `probe-sparse-it` and `first-run-on-the-real-model-nurse-in-turin-en`. No row about a fact changed, and `rowCountNeverDrops` still holds.
- **Units.** `WrittenTextTests` with a table of words and a fake tagger of names, the sentence in another language among them, and the device's dictionary and tagger on Apple hosts; the claim candidates without inferred skills; the use case's path with no answer, which withdraws every skill and keeps the text; the prompt's new pieces (`CVPromptTests`); the mapper's order (`AIDraftMapperTests`).
- **The evaluation of the real model (`DraftingEvaluation`, `InventedFacts`).** "Invented" counts facts only: a skill that is no phrase of the description is counted as `inferred`, and is still invented when a trap of the input holds it, or when it is a language, a qualification or a name; a skill's `kind` states no fact. New measures per distinct draft of an input with a role, study or field (`WrittenMeasure`, `WrittenCounts`): a summary of 2 to 4 sentences and at least 120 characters, a description of at least 40 characters on each kept job, the technologies and soft skills by kind, the written sentences in the description's language, the tools of another trade (each input's `offField` words) and the time. The inputs add, per language, a sparse description and one with no role. The acceptance step records a verdict for every distinct final draft on pertinence (`ReviewItem.Kind.pertinence`), the reading of these questions: each technology could be on a CV of that role and field, each soft skill fits the role, each role description matches its title, the summary is one plausible person's in the right language, and nothing contradicts a fact of the description.

## The measurement

**GO**, the thresholds of #354, over the distinct final drafts of a run set on the real model:
- 0 invented facts, 0 failed runs, 0 tools of another trade, 0 missed examples, 0 rejected pertinence items;
- a summary in at least 90% of the drafts of inputs with a role, study or field, and in every draft of an example;
- a description on at least 90% of the kept jobs;
- at least 4 technologies and 3 soft skills in at least 90% of the drafts (3 and 2 for a sparse description);
- every written sentence in the description's language;
- at most 90 s a draft at the 95th percentile, the claim check included; above it, the guide counts go down to 6 technologies and 4 soft skills, and the set is measured again.

**Measured: NO-GO at revision a1e64ab5** (macOS 27.0.1 build 26A434, Xcode 27.1, 30 inputs, 3 runs each, 90 runs; the model is deterministic, so the 3 runs of an input are identical).
- Invented facts: 3 runs (1 input, 1 job title said in a sentence that names no employer). Failed runs: 9 (3 inputs: the model returned nothing). Missed examples: 3 runs (1 example lost its title). Tools of another trade: 3 runs (1 input with no role wrote a summary from its interests).
- A summary in 5 of 23 distinct drafts of inputs with a role, study or field (3 of the 6 examples; every example needs one). A description on 12 of 37 kept jobs. Enough technologies and soft skills in 6 of 23 drafts.
- Every written sentence in the description's language: 75 of 75.
- Time: median 13.7 s, 95th percentile 18.9 s, maximum 21.7 s, within the 90 s budget.
- Claim check (3 sets, 3 runs each): 0 false keeps and 0 errors; 6 false drops of 263 items (5 in the adversarial set, 1 in the held-out set, 0 in the frozen set), all of a language.
- A person read all 28 distinct final drafts (`verdicts.md` of the evaluation folder): 2 accepted, 26 rejected, plus 3 inputs with no draft.

The thresholds are not met on the summary, the role descriptions and the skills: the model leaves them empty or short far more often than 10% of the time. The next step is a change to the prompt or the schema, then a new measurement. The owner's try on the release candidate is the human check before submission.

## Consequences

- **What it gives.** A draft from a few words holds a summary, the duties of each job and skills of both kinds, which the person corrects instead of writing. The facts keep every guarantee of ADR 0023 and ADR 0028.
- **What stays open, and is accepted.** A written duty or skill can be plausible and wrong for this person: a responsibility the person never had, a tool they never used. No rule can tell it, since such a text states no fact the description could contradict. The owner accepts this risk; the notice tells the person that the summary, the role descriptions and the skills are suggestions to check, and the pertinence reading measures it before release.
- **Names.** The name rule reads words, not meaning. A name that the dictionary knows as a common word and that has no capital where the rule looks ("rose", "berlin" in lower case) passes; in German, where capitals tell nothing, the device's tagger decides, and it is imperfect. The evaluation sends German capitalised words of written text to review.
- **Losses.** The rules are strict on purpose: a sentence with a word that neither the vocabulary nor the device's dictionary knows goes, so technical role text loses sentences, most in German. "A summary in 90% of the drafts" measures it; the fix is the vocabulary or the dictionary rule, never a sentence let through unchecked. Tool names belong in the skills, and the instructions say so.
- **Devices.** The dictionaries of `UITextChecker` and `NSSpellChecker` differ by device and language, so the same text may keep a sentence on one device and not on another. Where a language has no dictionary, only the other rules apply.
- **Time.** The model writes more tokens. The draft already took up to a minute, plus the claim check (60 s at most); the 95th percentile is measured, and the guide counts are the lever.
- **The store listing.** No text of the listing or of the review notes promises a correct draft: the facts come from the description, and the summary, the role descriptions and the skills are written by the on-device model (`docs/release/store-listing.md`).

## Alternatives considered

- **Keep the draft extractive.** Rejected by the owner: a draft without a summary and skills is not the complete CV the feature promises.
- **A model judge for the written text.** A second call that asks the model whether a sentence states a fact. Not taken: the claim check showed that a verdict changes with its batch and needs its own measurement, and a word rule that only removes is checkable on every host. It stays an option if the rules lose too much.
- **Marking each written field in the editor.** Not taken for version 1: one notice covers the three kinds of written text, and a mark per field needs a design of its own. It belongs to the redesign.
- **One call for the facts and the written text.** Taken first, measured NO-GO at a1e64ab5 and replaced by the two passes: with the writing instructions in the same call, the model copied the description into the summary and the role descriptions and extracted worse than main (31 of the 158 example facts of #202 lost), and one input ran 265 s and ended in `serviceFailed`. A second call adds its time to the wait; its limit and bounded schema cap it.
- **Sending inferred skills to the claim check.** Rejected: no clause of the description mentions them, so the check would withdraw every one.
