# 0023. Ground the AI draft by quoting the description and explaining every word

- **Status:** Accepted
- **Date:** 2026-10-13
- **Related:** [ADR 0022](0022-ship-legacy-app-as-v1.md), issues #16, #17, #18, #34 and #35

## Context

- **The decision that drives this.** Version 1 drafts a CV from the user's own description with Apple's on-device model. On 2026-10-13 the owner postponed the release so that the draft ships, and asked for test-driven development to stop regressions.
- **The model.** The on-device model is small. It paraphrases, leaves out jobs the user mentioned, and invents names, numbers and employers.
- **What nine review rounds showed.** They reviewed a sanitiser that recognises employers, places and names in free text. They kept finding the same two kinds of defect:
  - **invented data reaching the editor:** people, employers or numbers the user never wrote;
  - **facts moving between jobs:** one job's dates or results attributed to another job, especially when the model left that other job out.
- **Why patching did not work.** Each fix depended on capitalisation, prepositions or the model's own list of jobs, and each opened a new case. One round removed a regression test to get its change through.

## Decision

- **(a) The contract comes first, as tests.**
  - **The table.** `GroundingContractTests` is a data-driven table. Each row holds a description (in any of the six languages), the model's draft, and the draft expected after grounding.
  - **What it covers.** Every counterexample found in the review rounds is a row, and so are the positive controls: the app's example description in six languages, each with a faithful draft.
  - **Rows are never removed.** A row is never removed or weakened. A new finding adds a row, which fails, before any fix.
- **(b) Facts are quotes.** A structured value is kept only if it occurs verbatim in the description. This covers:
  - name, email, phone and link;
  - title, employer, school, degree, location;
  - dates, certification, skill, language, interest, figure.

  Case, diacritics and white space are ignored. Digits are folded only for numbers, never inside addresses. Addresses are compared as whole tokens. Each kept value records where it occurs in the description.
  - **Dates the model writes in another form.** If the model writes a date in another form ("2016-01-01"), the value is cut to what the description wrote (the year "2016"). If that part is not a quote either, the date is dropped.
  - **The literal "null"** stands for an empty field.
  - **The person's own fields** (name, contacts, location, title) need no backing clause, because they describe the person, not a job. They must still be quoted from a clause that speaks for the person (c) or from a verbless clause. So "My sister's email is anna@example.com" gives no email. A contact (email, phone, link) is the person's only in three shapes:
    - a verbless clause ("Email: me@example.com");
    - the person's possession of the field ("My email is me@example.com");
    - a verb of contacting whose object is the person ("You can reach me at…", "Contact me at…", "Contattami a…"), or the person as the subject of being reachable, from a short closed list per language ("I can be reached at…", "Sono raggiungibile a…", "Ich bin erreichbar unter…", "Je suis joignable à…").

    In each shape, the clause names no other person. Beyond the shape's own words (the label's field; the possessive with its field and "to be"; the reader's lead-in, such as "You can", "Feel free to" or "Non esitate a", with the verb of contacting and the person as its object), each word of the clause is a contact or field word, a number or the contact itself, a function or time word, or one of the person's own quotes (name, place, title). A name or any other noun gives no contact: "Reference: Anna Verdi, anna@example.com" and "Puoi contattarmi tramite Anna a anna@example.com" give no email. Any other clause gives no contact, even one the person speaks. So "I can put you in touch with my manager at boss@example.com" and "I can put you in touch with the recruiter at rec@example.com" give no email.
    - **References.** A pasted CV often ends with its references, names and addresses on separate lines. From the first sentence that holds a reference word, from a short closed list per language (reference, referee, recommendation; referente, referenza, raccomandazione; Referenz, Referenzperson, Empfehlung; referencia, recomendación; référence, recommandation; referência, recomendação), to the end of the description, no contact is the person's, in any shape. So "Email: me@example.com. References available on request." keeps the email, and "References. Anna Verdi, manager at Acme. anna@acme.com" gives none.
    - **A verbless contact** (a label, or an address on its own) is the person's only when the sentence before it, if there is one, names no other person: none of its clauses speaks for someone else, names another person or holds a reference word. And every verbless clause it leans on that stands alone, a sentence with no verb ("Anna Verdi.") or a verbless clause at the start of the contact's own sentence that no clause with a verb precedes ("Anna Verdi; Email: …"), is explained: contact or field words, numbers, function or time words, or the person's own quotes (name, place, title). An unexplained word, a name above all, gives no contact: "Anna Verdi. Email: anna@example.com" and "I'm Maria Rossi. Anna Verdi; Email: anna@example.com" give no email. A verbless fragment that follows a clause with a verb in its sentence belongs to that clause (c), so "I'm Anna Verdi, a nurse in Turin. Email: …" keeps its contacts. In such a fragment, a capitalised word that is not the first word of its sentence is a quote of the draft that the description backs (the person's name, place or title, an employer, a school…) or a contact or field word; otherwise the sentence names someone else, and no verbless contact leans on it: "I'm Maria Rossi, a friend of Anna Verdi. Email: anna@example.com" gives no email. So "Reference: Anna Verdi. Email: anna@example.com" and "Anna is a nurse. Email: anna@example.com" give no email, and neither does "My sister is a nurse. Email: me@example.com": a loss, not a leak (f).
  - **Another entry's quoted words.** A job's title, or a degree, is dropped when it is quoted only in a clause that backs another entry.
    A clause that names no entry, and whose words are all explained by the closed vocabulary, the entry's own quotes or the person's own quotes, backs no other entry: a title quoted there stays.
- **(c) A job's facts need a clause where every word is explained.**
  - **Clauses.** The description is split into clauses, at sentence ends, semicolons, commas, and the coordinating conjunctions of the six languages.
  - **Which facts.** A job's dates, its "current", its figures, its achievements and its location count only when they come from a clause that backs the job.
  - **When a clause backs a job.** The clause must name the job's employer, or its title when the job has no employer. And every word in it must be explained: it either belongs to the **closed vocabulary**, or lies inside one of that job's own quoted values.
  - **The closed vocabulary.** These are short lists, written by hand and kept in the code, one per language: function words, CV verbs, time and level words, and the few words of studying and graduating ("degree", "Abschluss", "diplôme", "laurea"…).
  - **Clauses that join a backing clause.** A clause that names no employer still backs job E when two conditions hold. It sits in the same sentence as, and next to, a clause that backs E. And every one of its words is explained by the closed vocabulary or by E's own quotes. So:
    - "from 2012 to 2016," before the employer's clause keeps its years;
    - ", and trained 3 new teachers" after it keeps its achievement, when that achievement is quoted;
    - a neighbour clause with an unexplained word joins nothing.
  - **A joining clause** can be explained only by two things:
    - the closed vocabulary;
    - one of E's achievement quotes that lies inside that clause and contains none of the six languages' employer prepositions ("at", "for", "with", "da", "presso", "per", "bei", "für", "en", "para", "chez", "pour", "em", "na", "no" and the like).
      - **The description's language decides.** When that language is known, a preposition of another language that is an ordinary word of the description's language does not count as an employer preposition. Examples: French "ai" in "j'ai formé", English "per" in "12 patients per shift". A preposition that the description's language does not have still counts, so "trained 3 cooks chez Gamma" in an English description explains nothing. When the language is unknown, the union applies.
      - **The same reading for negations and hedges.** A negation or hedge of another language that is an ordinary word of the description's language is read as that ordinary word. Examples: German "Mai" (a month, not Italian "never"), English "fast" (not German "almost"), Portuguese "no" (not English "no").

    E's location, description, title or other quotes never explain a joining clause. So a draft that copies another employer's name into one of E's values cannot pull that employer's clause in.
  - **What a joining clause can give.**
    - **Dates and "current"** come from a joining clause only when it is a pure time phrase: years, and words of a short time-phrase list per language. That list holds the prepositions and adverbs of time and the conjunctions that join them ("from", "to", "since", "until", "and", "currently"; "dal", "al", "fino"; "seit", "bis", "von"…). The rest of the closed vocabulary does not count, because a word of it can be a name. So "from 2012 to 2016" and "since 2016" are time phrases, and "and at Next in 2020" is not: "at" and "next" are not in the list.
    - **A graduation phrase** is a pure time phrase that also holds words of graduating ("graduated", "laureata", "laureato", "Abschluss", "abgeschlossen", "diplômé", "obtenu", "graduado", "graduada", "formei", "formado"…). It joins only an education entry, and gives that entry its end date: "…and graduated in 2012" gives the degree 2012. Next to a job's clause it joins nothing, so a job never takes a graduation year. An achievement quote that holds a word of graduating never explains a job's clause either.
    - **An achievement.** A joining clause explained by an achievement quote gives that achievement alone, never a date, "current" or another figure. The quote must begin with a CV verb of the closed vocabulary ("trained", "ho formato", "formé"…). So "…and Beta employed me in 2019" joins nothing.
  - **A clause next to backing clauses of two different entries** joins neither.
  - **One year, one date.** A year that occurs once backs one date only. When the model puts it in both dates of an entry, a job keeps it as its start date and an education or certification as its end date.
  - **Education and certifications** follow the same rule as jobs, with the school or the certification in the employer's role.
  - **Any other word makes the clause back nothing.** That covers another employer, in any letter case or left out of the draft; a longer name ("Acme Labs" for "Acme"); and a person.
  - **Clauses that deny, doubt or only hope back nothing.** The closed vocabulary holds no word of:
    - negation ("not", "never"…);
    - doubt or degree ("barely", "almost", "nearly", "partly"…);
    - wish or intention ("want", "would like", "hope", "plan"…);
    - future ("will", "werde"…);
    - condition ("if", "se", "wenn", "si"…).

    It lists the CV verbs only in their present and past forms. A CV verb in another tense or mood ("lavorerò", "trabajaría", "travaillerais") is a word the vocabulary does not explain. So such a clause backs and joins nothing.
  - **An entry needs a factual mention.** An entry is kept only if some clause of the description names its employer, school or certification (or its title, when it has none of these), holds none of the words above, and has only factual verbs.
    - **A factual verb** is a CV verb in a present or past form that the vocabulary lists, or an auxiliary followed in the clause by such a form. The present and past of "to be" count ("am", "'m", "was"; "sono", "ero"; "bin", "war"; "soy", "era"; "suis", "étais"; "sou", "era"), so "I'm a nurse at Acme" is factual. The on-device lexical class tells which words are verbs, and contractions count as their full form.
      - **What grounding relies on.** Grounding reads the lexical class only in English and German, the languages whose rows hold with it, because a device tags a language only once it has downloaded its data. So Italian, Spanish, French and Portuguese are grounded the same on every device, and English and German only on a device that has their data: without it, grounding would take a wish, a plan or another person's statement for the person's fact. So on such a device it gives no draft, and says which language data the device needs (`languageDataUnavailable`):
        - the use case asks before the model writes a draft, and grounding asks again before it reads one;
        - the app then asks the system to download the data, and tells the person that the draft is being prepared, as it does while the Apple Intelligence model downloads;
        - the system downloads the data, and the app sends nothing.
    - **Every word before the name must be explained.** Every word that leads in to the mention must be explained: by the closed vocabulary, by a number, or by the entry's or the person's own quotes. The lead-in is the words before the name, or before the clause's first factual verb, whichever comes first. The device does not tag the verbs of every language, so an unexplained word there may be a verb it cannot see. So "Cerco lavoro come infermiera", "I'm looking for a job as a nurse", "Sogno Acme dal 2027" and "Je rêve d'Acme" give no entry.
    - **Every verb before the name must be factual.** Any verb that comes before the name, or before the clause's first factual verb, and is not factual makes the mention not factual. That covers:
      - another verb in any form ("resterò", "try", "going");
      - an infinitive ("lavorare", "trabajar");
      - a verb after an infinitive marker ("to work", "zu arbeiten").
    - **A purpose or detail after the statement does not.** A verb that comes after both the name and a factual verb does not undo the mention. So "I worked at Acme to support 3 teams" and "Ho lavorato presso Acme per supportare 3 team" are factual, while "I studied hard to work at Acme" and "bei Acme zu arbeiten" are not. The words from the first such verb to the end of the clause give no facts.
    - **The person is the subject.** A clause speaks for the person only when its subject is the person. That means a first-person pronoun ("I", "io", "ich", "je", "yo", "eu"), or no subject at all in the way a CV writes ("Worked at Acme", "Ho lavorato presso Acme", a verbless clause). In the pro-drop languages a listed verb form must be first person singular ("ho lavorato", "lavoro"; not "ha lavorato", "lavora").
      - **The explicit subject.** It is the noun phrase before the clause's first verb. In German, when a phrase of time or place comes first, it is the phrase right after the verb. Only a first-person pronoun counts as the person. A noun ("a nurse"), a name ("Alice"), a third-person pronoun or a possession ("my sister") never does, even when the draft quotes the same word.
        - **Two exceptions** are about the person:
          - the person's possession of one of their own fields ("my email", "my phone", "my profile", "my page", "my English", "my skills"; "la mia email", "il mio inglese"; "meine E-Mail"…), from a short closed list per language of field words;
          - a clause addressed to the reader whose object is the person ("You can reach me at…", "Puoi contattarmi a…").
        - **"My sister" stays another subject.** A possession of a person ("my sister", "my colleague") is never one of these.
        - **Languages that keep their subject.** English and French do not drop the subject. A clause whose first verb comes after anything but a pure time phrase needs a first-person pronoun before that verb. Otherwise the words before the verb are another subject. So "In Rome Anna speaks French (C2)" and "At Acme Anna worked" give nothing, while "In Rome I speak French" and "Since 2016 worked at Acme" keep their facts.
        - **German.** German reads its subject right after the second-position verb ("In Berlin arbeitete Anna bei Acme" gives nothing), because its CV clauses often end with the verb ("Bei Acme gearbeitet").
      - **Another subject.** A clause with another subject backs nothing, gives no mention and is never quoted. So "A nurse worked at Acme in 2019", "Alice managed a school" and "My colleague managed a school" give nothing. Third-person pronouns are not words of the closed vocabulary.
      - **A shared subject.** A clause that starts with its verb after a conjunction or a comma shares the subject of the clause before it. So "My sister is a nurse and worked at Acme" gives no Acme entry and no summary "Worked at Acme".
      - **Every fact is the person's.** Languages and their levels, skills, interests and certifications also need a clause that speaks for the person, or a verbless list ("Languages: Italian (native), French (C2)"). So "My sister speaks French (C2)" gives no French. A language may stay without a level when the description gives none.
      - **A claim, not a denial, a wish or a supposition.** Skills, interests and languages count only in a clause of the person that claims them.
        - **What claims nothing.** A clause that holds a word of the modality lists claims nothing: negation, doubt, wish, future or condition. So does a clause that follows, in its sentence, a clause that opens with a word of condition ("if", "se", "wenn", "si"), and a clause that shares such a clause (a verbless fragment, or one that starts with its verb after a comma or a conjunction). So "I have never used Python", "I would like to learn Spanish", "If I had time, I would play chess" and "Si j'avais le temps, je jouerais aux échecs" give no skill, language or interest. The same item in a plain clause of the person stays.
        - **Ability and part are claims.** The forms of "can" ("posso", "kann", "puedo", "peux", "pode") and the words of part or most ("mostly", "partly", "teilweise", "parcialmente", "partiellement") qualify a claim without withdrawing it: "I can speak French" and "I partly use Swift" keep French and Swift. Both short lists are drawn from the modality lists.
        - **A negation beside a word of level denies the level.** When every such word of the clause is a negation or a hedge of a level and the clause holds a word of level, the clause still claims the item, without the level: "I am not an expert in Swift" keeps Swift.
    - **A clause without any verb** is factual when it starts a sentence or follows a semicolon ("Nurse at Acme, 2016–2020"; "Head nurse at Beta"). A verbless clause split off by a comma or a conjunction belongs to the clause before it in its sentence, and is factual only if that clause is. So "I have never worked at Acme or Beta" and "I would like to work at Acme, Beta or Gamma" give no Beta and no Gamma, while "I worked at Acme, Beta and Gamma" keeps all three.
    - **Backing.** The same rules decide whether a clause can back an entry.
    - So "I have never worked at Acme", "I would like to work at Acme", "Vorrei lavorare presso Acme", "Resterò presso Acme dal 2027", "I am going to work at Acme" and "Ho intenzione di lavorare presso Acme" give no Acme entry and no date.
    - The rule is about the form of the verbs, not a list of phrases. A future, a wish or a plan that the lists do not name still has a verb that is not a listed present or past form.
  - **What nothing depends on.** Capitalisation, prepositions and the model's list of jobs play no part.
- **(d) Prose is quoted from the description.**
  - **A prose clause is a quote.** Each clause of a summary sentence, a role description or an achievement must quote one clause of the description: the same words, in the same forms and the same order. Case, diacritics, white space and punctuation are ignored.
  - **The quote runs to the end of that clause**, or to the start of its purpose tail (c).
    - **The lead-in.** It may leave out only a lead-in: first-person pronouns and joining words ("I", "and", "where I"; "io", "e", "dove"; "ich", "und", "wo ich"; "je", "j'", "et", "où"; "yo", "y", "donde"; "eu", "e", "onde"), with the auxiliary or the form of "to be" that follows them ("I have", "I'm", "où j'ai", "ho", "sono", "ich habe").
    - **What it never leaves out.** An article, a word of negation, doubt, wish, future or condition, and any other word.
    - So "trained 3 new teachers" quotes "…, where I trained 3 new teachers", "taught at Acme since 2016" quotes "I have taught at Acme since 2016", and "A nurse in Turin" quotes "I'm a nurse in Turin".
  - **Why quotes.** Prose rebuilt from the description's words, even clause by clause and in order, reversed claims in review:
    - "I was trained by Acme" became "I trained Acme";
    - "My colleague managed a school" became "I managed a school";
    - a denial or a doubt was dropped.

    A quote keeps the user's own claim, with its subject, its voice and its negation.
  - **Summary.** A summary sentence holds no number, and each of its clauses quotes a clause of the description.
  - **Role descriptions and achievements** quote clauses that back their own job, outside any purpose tail (c).
  - So a paraphrase, an invented name ("Jane Smith", "Globex"), a change of person or a swapped number drops its sentence.
- **(e) Words are compared in a normalised form.**
  - That form is lower case and without diacritics. No lemma is used: a prose quote keeps the user's forms (d), and the closed vocabulary explains a CV verb only in the forms it lists (c), so neither a paraphrase nor a future becomes a fact.
- **(f) Losing beats inventing.** A dropped fact is acceptable: the editor's banner asks the user to complete the draft. An invented or misattributed fact blocks the release.
- **(g) Tidying after grounding only removes or reorders.** These steps add nothing:
  - **A skill that equals an interest of the same draft is dropped when the person mentions it only as leisure.** A hobby is not a claimed ability, and the interest stays.
    - **A clause of leisure** holds a word of leisure from a short closed list per language ("free time", "hobby", "like"; "tempo libero", "piacciono"; "Freizeit", "mag"; "tiempo libre", "gustan"; "temps libre", "aime"; "tempo livre", "gosto"), and otherwise only the quotes of the draft's interests and function or time words: "In my free time I like chess". A fragment of interests that a comma or a conjunction splits off from such a clause is one too: "and hiking".
    - **Any other mention by the person keeps the skill.** "I am proficient in Python", a job's clause ("where I do portrait photography") or a list of skills ("My skills include chess") claim the ability, so the skill stays wherever else the person mentions it.
    - **Only the clauses that claim count,** as rule (c) reads them: another person's clause ("My sister teaches chess") and a clause of the person that denies, wishes or supposes ("I don't play chess") neither keep the skill nor drop it. When no clause that claims holds the skill whole, nothing tells, and the skill stays.
    - **An interest the description does not give removes no skill:** only the interests that grounding keeps count.
  - **A leading indefinite article** ("a", "una", "eine", "une", "um"…) is trimmed from an employer or a school when it is written in lower case. What is left is still a quote, and a name such as "UNA Hotels" keeps its article.
  - **A degree made only of words of graduating, generic degree words and function words is dropped** ("diplôme", "Abschluss", "laurea", "my degree"). The school stays, and a degree with its field stays.
  - **The use case lists the jobs:** the current job first, then the others by their latest year, newest first. Jobs without a year, and jobs of the same year, keep the model's order.

## Consequences

- **Thinner drafts.** A clause that holds descriptive words the user did not tie to a job, such as "a busy hospital", backs no facts.
- **Little prose.** The model paraphrases, so most of its summary and role sentences are dropped. What stays is the user's own wording. The draft's value is in its structure: entries, dates, skills, languages and quoted achievements.
- **A residual risk in four languages.** The device tags no verbs in Italian, Spanish, French or Portuguese. So a wish stated after the name, with no infinitive and no factual verb ("Presso Acme sogno dal 2027"), can keep an entry. The entry holds only the quoted name: that clause backs no date, figure or achievement. Reading words after a verbless name as unexplained would drop real certifications and degrees ("ACLS certifications from the Italian Resuscitation Council"), so the rule stops at the lead-in. The editor's banner asks the user to check the draft.
- **Drafts wait for the language data.** On a device that has not yet downloaded the data of English or German, a description in either gives no draft until the system has it, and the person is asked to try again in a moment.
- **Residual risks of the contacts.** Two constructions still keep a third party's contact (b):
  - a lowercase name in a fragment after the person's clause, as only capitals mark a name there: "I'm Maria Rossi, a friend of anna verdi. Email: anna@example.com";
  - a capitalised name that equals a quote of the draft elsewhere, such as an employer, as a quote of the draft counts as explained: "I worked at Anna Verdi. I'm Maria Rossi, a friend of Anna Verdi. Email: anna@example.com".

  They are accepted: neither construction is likely in a person's own description, and the draft opens unsaved in the editor with the AI-draft notice, so the person reviews it before saving. The contract pins both as residual risks, which fail once a later rule closes them.
- **Deterministic.** The behaviour is deterministic and stated as a table of examples. Every past defect is a permanent row.
- **Less code.** The recognisers for employer prepositions, capitalised names, location prepositions and temporal lead-ins are removed. Capitals are read in one place only: a fragment that a verbless contact leans on (b). The rules shrink to quotes, clauses and one vocabulary list per language.
- **Upkeep.** The vocabulary lists need care in six languages. A missing word only drops data; it never lets data through.

## Alternatives considered

- **Keep recognising employers and names in free text.** Rejected: nine rounds did not converge.
- **Ship version 1 without the draft.** Rejected by the owner.
- **No prose at all,** only quoted fields. Rejected: prose quoted from the user's own clauses keeps the user's claims at no extra risk.
- **Prose rebuilt from the description's words** (the first form of rule (d)). Abandoned after review: free function words and omitted words let a sentence reverse who did what, or drop its subject.

## Validation

- **Tests.** `GroundingContractTests` pass, together with the sanitiser's other tests, on the Mac mini.
- **Existing sanitiser tests.** Those that this ADR reverses are rewritten in the commit that implements it, each one named in the commit. Any safety property they pinned exists as a contract row first.
- **The real model.** Each run is recorded with its kept and dropped fields. On 2026-10-18 Apple's on-device model on macOS 27.0.1 drafted the six in-app example descriptions and one realistic description, three times each:
  - **Nothing was invented** in any of the 21 runs.
  - **Every employer** (12 of 12) and **every job title** (12 of 12) of the examples were kept, after the fixes of rules (c) and (g).
  - **Each job's own years** were kept only where the model wrote them: in English and Portuguese. In German, Spanish, French and Italian the model leaves the years out. That loss is the model's, not the grounding's.
  - **On the realistic description**, the current job loses its dates, because its clause holds words no list explains ("cardiology department"). This is the thinner draft of the Consequences.
