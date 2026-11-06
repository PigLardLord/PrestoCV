# 0036. Build the draft from prepared lines of each trade that the person confirms

- **Status:** Proposed
- **Date:** 2026-11-06
- **Related:** [ADR 0031](0031-let-the-ai-draft-write-around-the-facts.md), [ADR 0033](0033-change-the-legacy-app-only-to-fix-the-published-version.md), [ADR 0023](0023-ground-the-ai-draft-in-the-description.md), [ADR 0028](0028-check-each-personal-claim-of-the-ai-draft-again.md), ADR 0035 (proposed in #374), epic #192, issues #113, #196, #205, #206, #207, #208, #210, #220, #228, #229, #230, #253, #368

## Context

- **The v1 draft writes from a free text on the device.** Since ADR 0031 the on-device model reads the person's description, extracts its facts, then writes a summary, duties and skills around them, and rules remove what states a fact of its own. Tuning it (#354) gave less with each round. After trying the 1.0.1 builds (2026-11-05 and 2026-11-06), the owner found the drafts thin and not credible.
- **The owner's goal (2026-11-06).** From a few lines, a CV that reads like a credible, ready example of the person's trade, which the person then completes with their real data. It shows how a strong CV is written. Not every line has to be the person's own yet, but everything the person enters must be in it. The owner chose:
  - guided questions per job: the facts go straight into their fields, the AI proposes what is typical, and the person confirms it with a tap; legal qualifications are yes/no questions;
  - Apple's Private Cloud Compute on top, with consent that says where the text goes (#253).
- **The owner's limit (2026-11-06).** The CVs of one trade must not all read the same because their lines were prepared in advance: the model should be able to rephrase the lines by what the person wrote.
- **The plan of 2026-10-17 (epic #192).**
  - The spike #229 scored ESCO for CV suggestions, blind, on 12 occupations in three languages. A person kept 43% of the raw ESCO items (45 were wrong), and 97% of the items a strong model wrote from ESCO. The small on-device model is not good enough to write such items; it may run checks. Seniority changes the phrases (42% depend on the band) far more than the skills.
  - The packs of #205: per occupation and market, written by a strong model at batch prices, with skills and CV phrases by band and "no facts in phrases", checked before publishing and reviewed every month. They are signed static files that the app syncs in the background (#230: "No user text, occupation or identifier is sent, and nothing is logged per user").
  - Curated corrections as data (#206), offline matching of the title (#207: the pack aliases matched 38 or 39 of 39 inputs, the ESCO search put the right occupation first for 13), a suggestion engine with no model call (#208), the confirm UI (#210), experience suggestions (#220), and demand data from job ads (#228).
  - The ADR planned by #196, with the owner's decision of 2026-10-25: tools may be proposed; certifications, licences and work experience never.
- **What the on-device model does well and badly.** Probes of 2026-11-06 on the Mac mini, with invented inputs in Italian and English (electrician, cook, iOS developer, warehouse worker, shop assistant), one greedy run each:
  - **Choosing.** Given five ESCO occupations as its only allowed values, it chose the right one for 7 of 7 inputs. Given the O*NET occupations of the official crosswalk, it chose right in 6 of 6. It answered in the person's language in 7 of 7, with English source text in the prompt too. A request took 0.4 to 2.9 s.
  - **Writing the lines of a trade.** Asked for duties from ESCO skills, it copied the skill titles ("Strip wire."). Asked from O*NET tasks, it translated them word for word, in the style of a US job ad, once in the third person.
  - **Knowing a market.** Asked for norms with none given, it left the list empty in 6 of 6 drafts. Made to give some, 7 of 24 were real names, and none of the 8 for the Italian electrician and cook. Given a curated list of each market's core norms, the norms were right: CEI 64-8 and D.M. 37/2008 for an Italian electrician, HACCP for a cook, BS 7671 for a British electrician.
  - **Software and tools.** Its own software list for an iOS developer (Swift, SwiftUI, Xcode) was better than ESCO's for a software developer, which lists VBScript, Perl and COBOL and has Swift and Xcode only as optional. For the trades its tools were weak.
  - **Keeping the person's words.** It dropped a dish the person named, then changed its name in the next round; in another probe it added team leadership and "Senior".
  - **Repeats.** In one list of allowed values, 4 of 6 choices were the same item.
- **Fitting the lines to the person.** Two more probes on the Mac mini, with five invented lines per trade and invented people:
  - **Every line rewritten.** Asked to rewrite the five lines of a job with what the person wrote, it put the person's words in the right line, with sense, for 7 of 10 people (greedy), 1.4 to 4.9 s a request. It also spread them into lines where they make no sense ("Collaborazione con l'impasto durante il servizio"), lost a line and repeated another ("Inventario." twice), switched to the first person, and for both shop assistants only replaced words with synonyms. Three sampled runs per person differed mostly by synonyms that read worse ("Took money at the counter and shut the cash box").
  - **A check of words is not a check of sense.** "Controllo della qualità e della freschezza degli impasti e del forno a legna" has only words of its line and of the person's text.
  - **One line at a time.** Asked to choose the line the person's text is about and rewrite only that one, it returned the line unchanged for 11 of 15 people and the person's text in place of the line for 4; its choices were often not the line the text was about. Asked to write one line of its own, it returned the person's text as written for 9 of 9 Italian people, and in English it added a claim ("managed stock efficiently") or lost the person's words in 4 of 5 answers. The guardrails refused one ordinary request ("led the migration from UIKit to SwiftUI"). A request took 0.6 to 1.4 s.
  - **A strict filter on the first probe.** Keeping a rewritten line only if it starts as its line does, holds a part of the person's text word for word, and has no word from neither, kept a line for 4 of 10 people in the greedy runs ("Installazione di impianti fotovoltaici sui tetti dei capannoni."), each with sense, and no line without sense. It rejected every English fit, whose verbs were synonyms ("Created" for "Built"). In the sampled runs it let one line without sense through ("…gli standard del forno a legna"). It was designed on these answers, so its numbers hold only for them.
- **The sources.**
  - ESCO (CC BY 4.0): occupations and skills in every EU language, a free API that allows one call every 2 s, and outdated software skills.
  - O*NET 31.0 (CC BY 4.0): tasks as full sentences, in English only, and a software list. It has had no hand tools since release 30.3. The official ESCO–O*NET crosswalk found O*NET occupations for 7 of 7 inputs.
  - ROME 4.0 and the "Mots-clés de CV par métier" (Licence Ouverte 2.0): typed CV keywords for 1,911 French jobs, tools, norms and certifications among them.
  - Not usable: Lightcast Open Skills (free for non-profit use only) and BERUFENET (the Bundesagentur für Arbeit keeps exclusive rights).
  - The O*NET and France Travail web APIs need a key. None of the sources offers GraphQL.
- **New occupations.** The sources add occupations only with their releases: O*NET 31.0 has no "prompt engineer", and the ESCO search for it returns the theatre prompter first. The owner asked (2026-11-06) to regenerate the data every one or two months, so that new trades arrive.

## Decision

- **The draft holds three kinds of content.**
  - **The person's own:** their answers to the questions (title, employer, years, place, what they did, the yes/no qualifications), set by code word for word in the field they belong to. No model changes them.
  - **Proposed:** a line of a pack, or a text of Private Cloud Compute, marked as a proposal. It enters the CV only when the person confirms it with a tap; they can edit it after.
  - **To complete:** a slot with a typed placeholder (an employer "Company 1", a figure "[X] %" with its unit, a period) and a coach's tip on what to write there. A placeholder is not CV content: the CV stores the empty slot with its kind, never the placeholder text, and nothing prints it. A proposed line with a slot can be confirmed only once its slot is filled.
  - **Before the export** the app lists the proposals not confirmed and the slots left. The export does not wait for them (the owner, 2026-11-06), and what is left is not printed.
- **Every value keeps its origin** (#196): written, answered, accepted from a pack (as it is or fitted on the device), accepted from Private Cloud Compute, or imported. An accepted pack line keeps its pack item id and its source (#208).
- **The knowledge of a trade is prepared, not generated on the device.** The packs of #205 hold, per occupation and market:
  - **The lines of the experience section** (#205's phrases), written in the market's language as lines of a CV, by band of seniority (#208), with no fact: no number, no name, no employer, no licence. A pack holds more lines per band than a CV shows, and each line in two or three wordings. The pipeline's strong model writes them from ESCO, from the O*NET tasks of the occupation through the official crosswalk, from the ROME data for fr-FR, and from the curated data (#206). An O*NET task is a meaning to write from, never a text to translate.
  - **Achievement templates:** a line with typed slots ("Reduced waste by [X] % in [period]"), proposed as a line, with its slots to complete.
  - **Summary templates,** whose slots code fills from the person's own facts (title, years) and the lines they confirmed.
  - **The tools in two lists,** software and equipment (machines and hand tools). O*NET has software only; the equipment comes from the curated data, the ROME keywords and the strong model.
  - **The norms of the market,** only from the curated data (#206), never from a model.
  - **The legal qualifications and licences** of the trade in that market, from the curated data, asked as yes/no questions and never proposed (#196). A yes is the person's own answer.
  - **The checks before publishing:** those of #205, plus no fact in a line or a template, no word-for-word translation of a source task, every norm and qualification from the curated data, and no repeated line.
- **The packs are regenerated on a schedule.**
  - A batch runs every one or two months (the owner, 2026-11-06). It first compares the inputs of each pack with those of its last published version, which calls no model, and regenerates only the packs whose inputs changed: a release of a source, a change of the curated data, a new title from job ads, a new prompt. A run with no change costs nothing. A paid run stays within the budget of Cost below.
  - The monthly diff review and the 5% sample of #205 stay. When a check fails, or the budget ends before a pack is done, the last published pack stays, and the next run that has a budget tries that pack again, since its inputs still differ.
  - The output is signed static files that the app syncs in the background (#230). Where the batch runs is for the hosting ADR (#205). The keys of the sources that need one stay in the pipeline's secrets.
- **New occupations come from public data, never from the app.** The app sends nothing (#230). A new title comes from job ads (#228, once their terms allow it) or from the review, and a person approves it as a curated alias or a new pack (#206). Until then, a title with no pack goes to the closest occupation (#207), which the person sees and can change.
- **Two people of one trade get different CVs** (the owner's limit above), from four sources:
  - their own text of each job, word for word in its entry;
  - the lines their words pick: code ranks a pack's lines by the person's words and band (#208), so different texts can pick different lines;
  - the wording: code picks one of a line's wordings from the CV's identifier, so another CV of the trade may read another, and one CV keeps its own;
  - the lines fitted to what the person wrote, by the on-device model and by Private Cloud Compute, below.

  The same pack and the same input, the CV's identifier included, give the same proposals (#208), and the fitting runs greedy, so one model version fits them the same way each time. No sampling makes the CVs differ.
- **On the device, code builds the draft; the model chooses, and fits lines only through a check.**
  - Code asks the questions per job and the market's yes/no questions, matches the occupation offline (#207), sets the answers word for word, and ranks the pack's proposals (#208). This works on every device, offline and without Apple Intelligence.
  - Where the on-device model is available, it may choose among values that code gives it: the occupation among the matcher's candidates when the matcher is unsure, and the pack lines that fit what the person wrote for a job. Its answer schema allows only those values (`GenerationGuide.anyOf`), and code removes repeats. A choice only reorders the proposals.
  - It may also fit the proposed lines of a job to what the person wrote, in one greedy request per job. Code keeps a rewritten line only if it starts with the first word of its pack line, holds a part of the person's text word for word, and has no word that is in neither its pack line nor the person's text (the provenance check of #113). Otherwise the pack line stays. A failure, a refusal of the guardrails or the deadline leaves all the pack lines.
  - A kept line is a proposal like any other, with its pack item id; the person confirms it or not. Apart from these lines, the on-device model writes no text that enters the CV.
- **Private Cloud Compute writes only what a pack cannot hold** (v1.2, #253): a CV line from what the person wrote for a job, the pack lines of the job fitted to it, and a summary.
  - It runs only after the person's consent, which says where the text goes. The request carries what the person wrote for the draft and the occupation, never the contacts.
  - What it writes is proposed, under the same rule as a pack line: it states no fact the person did not give. ADR 0023 and ADR 0028 say what a fact is. The person's own text stays beside it.
- **ADR 0031 and ADR 0035.** ADR 0031 stays the rule of the v1 draft in the legacy app, which takes only fixes of the published version (ADR 0033). The new targets do not extract facts from a free text with a model: the questions give them. ADR 0035 (proposed in #374) keeps its measurement for this draft. What it lets the draft infer (the core tools of the trade, its norms, the scope and seniority that the years give) is inferred in the packs and by Private Cloud Compute, never by the on-device model.
- **The releases follow the [vision](../../product/vision.md).**
  - v1.1, the guided start, offline on every device: the questions per job and the market's yes/no questions, the offline match of the occupation (#207), and the skills, tools and norms of the packs as proposals (#208, #210).
  - v1.2: the lines of the experience section with their wordings, their fitting on the device, the achievement and summary templates, the proposals per employer (#220) and Private Cloud Compute (#253). The fitting on the device ships only if, on new invented inputs, its check keeps no line without sense.
  - A pack may hold what a later release shows; the app shows it only from that release.
- **Targets.** The pull requests that create the targets of the packs, the matching, the suggestions and the draft add them to `modules.md` (#205, #207, #208, #220).

## Consequences

- **Easier.**
  - Every device gets credible lines of a trade, offline, and two people of one trade get different ones even with no model. The knowledge is checked once per pack instead of hoped for in each answer.
  - The person's words never change, by construction, not because a rule reads the model's answer afterwards.
  - The draft is code over data: a fixture pack and the person's answers give one draft on every host, Linux included, with no model.
- **Harder.**
  - The batch and its review every one or two months. The curated norms and qualifications need a person who knows each market; a market without them gets no norms and no questions, never invented ones.
  - The packs grow with the lines, their wordings and the templates. The first pack run measures their size against #205's estimate of about 0.6 MB gzip per language.
  - The fitting on the device helps few people: the check that keeps it safe rejected every English fit of the probe, and it does not judge sense, so the person's confirmation stays the last check.
  - The person answers a few questions instead of writing one text: more taps, fewer surprises.
- **Cost (principle 7 of the [vision](../../product/vision.md)).**
  - The packs: about $175 for the first full run at batch prices (#205), whatever the number of users. The wordings add to the share of the lines; the first run measures the total within its budget. A later run pays only for the packs whose inputs changed, as the vision's v1.1 row says, and a run with no change costs nothing.
  - Hosting: static files on a free tier. With no users, 1,000 users or 100,000 users the cost stays 0 on a host whose bandwidth is not metered: 100,000 people who each fetch one language of about 0.6 MB make about 60 GB per run.
  - The device: free. Private Cloud Compute: free under Apple's terms for Small Business Program developers below 2 million first-time downloads, with a daily quota per person.
  - Before revenue, each paid run needs a budget that the owner approves for it. Without one, or once it is spent, the run stops before its next paid call and the last packs stay in use. No paid run starts by the schedule alone.
- **Checks.**
  - A test that the export prints only the person's own and confirmed values, never a placeholder.
  - A test that every answer reaches the CV word for word.
  - A test that the model's choices are among the values given, without repeats, and that the draft without the model differs only in the order of the proposals and in the fitted lines.
  - A table-driven test of the check of fitted lines, with lines it must keep and lines it must reject, the probes' lines with a new word or another form among them.
  - A test that one CV gets the same lines and wordings each time, and that over a fixture of CVs of one trade the lines and wordings differ.
  - The pipeline's checks above, before each pack is published.
  - The measurement of ADR 0035 on drafts built from the packs.
- **Issues.** The probe results go to the existing issues, with no new issue repeating them: #205 (lines from O*NET tasks, templates, two tool lists), #206 (norms and qualifications per market), #208 and #220 (code ranks, the model chooses, the person's line set by code, the wordings and the fitting), #113 (the check of fitted lines), #196 (origins, qualifications as questions) and #228 (new titles).

## Alternatives considered

- **Tune the free-text draft further** (ADR 0031, #354). Each round gave less, and the small model cannot both extract the facts and write the lines of a trade.
- **Let the on-device model write the lines from source tasks in its prompt** (the second probe). It translated them word for word, in the style of a US job ad and in the third person, and changed the person's words.
- **Let the on-device model rewrite the lines freely** (the third probe). It fit the person's words into the right line for 7 of 10 people, but it also put them where they make no sense, lost and repeated lines, and replaced words with synonyms. A check of words cannot judge sense, so only the lines that pass the strict check are kept.
- **Make the CVs differ by sampling** (a temperature). The sampled runs differed by synonyms that read worse, and one line without sense passed the strict check. The variety comes from the packs' lines and wordings, and a CV gets the same draft each time.
- **Ask the model for one line at a time** (the fourth probe). It returned the line unchanged or the person's text as written, chose lines the text was not about, and in English added claims.
- **Propose the raw ESCO lists** (#229). A person kept 43% of them, 45 were wrong, and the software skills are outdated.
- **Call the sources' APIs from the app,** so that the data is always current (the owner's first idea). The keys would ship in the app, ESCO allows one call every 2 s, and #207 promises that the app never calls ESCO. Packs regenerated every one or two months are as current as the sources, which release a few times a year.
- **Learn the missing titles from what the app sends.** Keeping what the app sends is collected data in Apple's privacy details ("Other User Content"), and it breaks the promise of #230. Job ads give new titles with no data of any person.
- **Write the whole draft with Private Cloud Compute.** It needs iOS 27 or later, a device with Apple Intelligence and the owner's entitlement, and it has a daily quota. The guided start must work offline on every device (v1.1).
- **A GraphQL service over the sources.** None of them offers one, and static packs need no query service.
