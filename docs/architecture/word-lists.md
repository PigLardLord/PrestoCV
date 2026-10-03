# Word lists

Every rule of the CV Tailoring context that depends on a language reads it from data, one file per language ([ADR 0013](adr/0013-cv-tailoring-context.md), [R13](rules.md#r13-localisation-happens-at-the-edges)). The words an advert wastes, how it names its sections, the months, the numbers in words, how a floor of years is written, how a letter greets and closes, and the names of technologies are all in the file of the language. Adding a language adds a file and an index entry, and changes no code.

The files are resources of the `TailoringModel` target, read through `Bundle.module` ([R2](rules.md#r2-pure-layers-read-no-ambient-state)) the way `HeadingsCatalog` reads the heading tables. They are in `CVTailoring/Sources/TailoringModel/Resources/WordLists/`.

`TailoringModelTests` hold this page to the decoder. A key the decoder knows that this page does not name fails a test, and so does a key this page names that the decoder does not know.

## Format, version 1

### Files

| File | Holds |
|---|---|
| `index.json` | An array of language codes: the languages that have a file, in the order they are listed |
| `<code>.json` | The lists of one language, as one JSON object |

- `WordLists.load()` reads the index, then the file of every language it names, and validates each one. A composition root calls it once and injects the value ([R4](rules.md#r4-one-composition-root)); nothing caches it.
- `WordLists.forLanguage(_:)` returns the `LanguageWordLists` of a language, or `unsupportedLanguage` for a language that has no file. It never falls back to English ([R13](rules.md#r13-localisation-happens-at-the-edges)).
- A file names its own language in `language`. The decoder refuses a file whose language is not the one the index lists it for.
- Every file is JSON and at most 1,048,576 bytes (1 MiB). The size is checked before the bytes are decoded.
- The format is closed. A key that is not in the tables below is refused wherever it is: at the top of a file, in a group, in a list and in an entry.

### Languages

The supported languages are the ones the index names, each with its file. An index code is one of the six languages of the model: `en`, `de`, `es`, `fr`, `it`, `pt`, written in lower case, and a code is listed once. A seventh language is a change to the language type of the model, and its own decision.

### Shapes

| Shape | Keys |
|---|---|
| The file | `version`, `language`, `advert`, `dates`, `numbers`, `spans`, `letter`, `provenance`, `fields` |
| A list | `source`, `licence`, `entries` |
| The list of streets | `source`, `licence`, `entries`, `order` |
| A month name | `name`, `month` |
| A number word | `word`, `value` |
| A group of synonyms | `forms` |
| A word of a form of address | `form`, `word` |
| A word that claims a rank | `word`, `ranks` |

- `version` is the whole number 1. A file of another version is refused, and the version is read before anything else, so a newer format is never read as a file with lists missing.
- Each group holds the lists named in the key table, and no other. Every list is an object with a `source`, a `licence` and its `entries`.
- An entry is a string, except in six lists:
  - `dates.months`: `{ "name": "january", "month": 1 }`, a month from 1 to 12;
  - `numbers.words` and `spans.countWords`: `{ "word": "two", "value": 2 }`, a value that is not negative;
  - `advert.synonyms`: `{ "forms": ["ui", "user interface"] }`, two forms at least;
  - `letter.formsOfAddress`: `{ "form": "ms", "word": "mrs" }`, a form that is `ms` or `mr`, since the neutral form has no word of its own;
  - `provenance.ranks`: `{ "word": "chief", "ranks": ["head"] }`, one rank at least, each from the set below and none twice.
- `advert.streets` also says where the language writes the word of a street, in `order`: `joined` to the name ("Hauptstraße 1"), `after` it with the number first ("221B Baker Street"), or `before` it with the number last ("Via Roma 1").
- `spans.tiedCounts` holds templates: literal words around `{count}` and `{employer}`, each exactly once, no other brace, and a word between them. A language puts the count before or after the employer as it writes it.
- A source, a licence and every entry is one line of text that shows something. It holds no hidden character: the model's `TextRules` refuse control characters, bidirectional marks, embeddings and overrides, and tag characters. It has no blank at either end by the model's one rule of trimming. And it is not empty once folded: an entry that folds to nothing, such as a lone combining mark, is corrupt.
- Entries are kept as written. A match folds both sides with `TextFold.fold`, the one normalisation in `TailoringModel`: case, accents and ligatures are dropped, `ß` is `ss`, and runs of white space are one space.

### Ranks

A word of a title claims the ranks it may mean, and a tailored title may claim no rank its source does not. The ranks are a closed set, the same in every language: `senior`, `lead`, `principal`, `staff`, `head`, `director`, `manager`, `architect`. An entry is a whole word, and it may mean several ranks: German writes a lead and a head alike.

### Keys

Every file holds every key below. A file that lacks one is refused as incomplete, with the key named.

| Key | Holds | Used by |
|---|---|---|
| `version` | The format version | Refused unless it is the one this page describes |
| `language` | The code of the language the file is the file of, as the index lists it | Refused unless it is the language the index names for this file, so a file copied under another name is caught |
| `advert.stopwords` | Words that carry no information about a role, however often an advert uses them | `AdvertAnalysis` leaves them out of the terms it ranks, and guesses an advert's language from the share of its words that a language's stopwords make |
| `advert.plainWords` | Ordinary words of an advert's prose that a tailoring may write although the CV does not, because each is a word of some technology's name ("new", "time") | `Provenance` lets them pass in the check of names; `AdvertAnalysis` still ranks them |
| `advert.dimensions` | Nouns that name what a claim measures ("performance", "stability") | `Provenance` holds the figure beside one to the source, and refuses one beside no figure as a claim |
| `advert.boilerplate` | Phrases and words that belong to the posting and not to the job ("equal opportunity", "full time") | `AdvertAnalysis` drops a phrase as furniture; a one-word entry counts only on a short line |
| `advert.genderMarkers` | Gender markers a job title carries in words ("all genders") | `AdvertAnalysis` takes them out of a line before it reads it |
| `advert.instructions` | What an advert asks of the applicant and not of the job ("please state", "notice period") | `AdvertAnalysis` takes them out of a line as words before it reads it |
| `advert.streets` | The words a street's name carries ("street", "road"), and where the language writes them | `AdvertAnalysis` reads an address line as the posting's and not as a requirement, only beside a house number |
| `advert.names` | Names written in several words that are read whole ("github actions", "time series") | `AdvertAnalysis` reads each as one term and not as its words |
| `advert.synonyms` | Groups of forms that mean the same ("ci/cd", "continuous integration") | `AdvertAnalysis` finds evidence through a group and reports it as a synonym and never as exact |
| `advert.requirementHeadings` | Headings under which an advert states what it will not compromise on ("requirements", "must have") | `AdvertAnalysis` marks the terms below one as required |
| `advert.offerHeadings` | Headings under which an advert talks about itself: what it offers and who it is ("we offer", "about us") | `AdvertAnalysis` ranks the terms below one lower |
| `advert.structuralHeadings` | Headings that organise an advert without demanding or offering anything ("tech stack", "location") | `AdvertAnalysis` reads their own words as structure, so "tech stack" is no technology |
| `dates.months` | The names and abbreviations of the twelve months, each with its month; every month has a name at least | `ContentChecks` and `Provenance` read a date written with a month's name as the date of the numbers |
| `dates.presentWords` | How a period says it has not ended ("present", "ongoing") | `ContentChecks` reads a period written in text: a role still running cannot bear a count tied to it, since the calendar overtakes it |
| `dates.sinceWords` | What a period says before its start when it began and has not ended ("since") | `ContentChecks` reads it as a period that runs to the present |
| `dates.rangeSeparatorWords` | The words between the two dates of a period ("to"); the dashes and the tilde are a shape | `ContentChecks` splits a period into its two dates |
| `dates.durationUnitWords` | The units of the length a period carries after its dates ("3 years", "8 mos"), every form written out | `ContentChecks` takes the length off a period, since what a reader compares is the dates |
| `numbers.words` | Numbers written in words, with their value: "two" to "nineteen", the tens, "dozen", "hundred", "thousand", "million". "One" is left out: it is a pronoun as often as a number | `Provenance` reads a figure in words as a figure and holds it to the source; a tens word, a hyphen and a word of 2 to 9 are one figure |
| `spans.floorLeadIns` | What opens a floor before its count ("over", "more than"); "11+ years" is a shape and needs no entry | `ContentChecks` lets a floor pass, since it only grows truer |
| `spans.yearWords` | The words for a year, singular and plural | `ContentChecks` reads the unit of a count of time |
| `spans.monthWords` | The words for a month, singular and plural | `ContentChecks` reads the unit of a count of time |
| `spans.countWords` | The counts of time that a CV writes in words, "one" to "twelve", with their value | `ContentChecks` reads the count of a span of time |
| `spans.tiedCounts` | How the language ties a count to an employer, as templates ("{count} of them at {employer}") | `ContentChecks` holds a count tied to a role that has ended to that role's dates |
| `spans.employerEndWords` | The words that end an employer's name in a tied count, as a comma, a full stop or a semicolon do ("8 of them at PigLardLord and …"): "and" | `ContentChecks` reads where the employer's name ends |
| `letter.greetings` | The words that open a salutation ("dear", "hello") | `Provenance` refuses a salutation the model writes, since the page greets the recipient itself |
| `letter.salutations` | Salutations that stand on their own ("to whom it may concern") | `Provenance`, as for the greetings |
| `letter.addressees` | The words that, right after a greeting and as a whole word, make it a salutation: forms of address, titles and groups ("mr", "dr", "everyone") | `Provenance`, as for the greetings: "hi-fi audio" is prose and "hi everyone" is a greeting |
| `letter.addresseesAtClauseEnd` | The words that make a greeting a salutation only when a comma, a "!" or the end of the text follows them ("there": "hi there," greets, "hi there is a place" is prose) | `Provenance`, as for the greetings |
| `letter.addresseeNouns` | The nouns an addressee ends in, with up to two words before ("team", "manager") | `Provenance`, as for the greetings: "dear hiring manager" |
| `letter.valedictions` | How a letter signs off, every form written out ("kind regards", "yours sincerely") | `Provenance` refuses a sign-off the model writes, since the page signs off itself |
| `letter.salaryExpectationAsks` | How an advert asks for a salary expectation, every phrase written out | `AdvertAnalysis` asks the user when the advert asks and the letter defaults give none |
| `letter.startDateAsks` | How an advert asks for a start date, every phrase written out ("earliest start date", "notice period") | `AdvertAnalysis`, as for the salary |
| `letter.statedTermWords` | The words that, right after an ask, show the advert states its own term and asks nothing ("salary range of …") | `AdvertAnalysis` does not ask when an ask is followed by one, by a figure, or by a colon or a dash |
| `letter.formsOfAddress` | The words that write a form of address before a contact's name, each with its form, `ms` or `mr`: "ms" and "mrs" for `ms`, "mr" for `mr` | `Provenance` accepts a form of address only when the advert writes one of its words before the contact's name; otherwise the form is neutral |
| `letter.academicTitles` | The titles that may stand between a form of address and a name ("dr", "prof") | `Provenance`, as for the forms of address: "Ms Dr Grace Hopper" |
| `letter.notGivenNames` | The words that are no given name before a surname: another form of address, or a conjunction ("miss", "and", "or") | `Provenance`, as for the forms of address: "Ms Müller and Mr Hopper" writes no "Ms" before Hopper |
| `provenance.notPlurals` | Words that end like a plural and are none ("news", "series") | `Provenance` finds a word in both its numbers, and does not make "new" of "news" |
| `provenance.legalForms` | The legal forms a company's name ends in, every spelling written out ("gmbh", "ltd.", "gmbh & co. kg"). A legal form belongs to a jurisdiction and not to a language, so every file holds the whole list, as it holds the technologies | `Provenance` finds a recipient's company as a letter writes it in prose, without its legal form |
| `provenance.firstPerson` | The capitalised words of the first person, with either apostrophe ("I", "I'm") | `Provenance` does not read them as names |
| `provenance.ranks` | The words of a title that claim a rank, each with the ranks it may mean ("senior", "chief" for head) | `Provenance` refuses a title that claims a rank its source does not write |
| `fields.technologies` | Names of technologies that are never ordinary words of the language ("Kotlin", "SwiftUI") | `Provenance` holds a mention to the source however it is written; a name that is also an ordinary word stays out, and is read from its capitals |

### What stays in code

A shape is the same in every language, so it is not a list: the letters of a gender marker joined by slashes ("m/w/d"), a house number, a postcode, an American state and its ZIP code, the dashes and the tilde between two dates, the floor written "11+ years", a figure in numerals, and a tens word joined to a unit by a hyphen. The checks that read them are in the targets that use them.

### Not in the word lists

cv-giovanni holds more than the files do. What stays out, and why:

- **The German forms of the synonym groups, `ALSO_ENGLISH_WORDS`, `SHARED_NOUNS`, `NOT_RANKS`, the German abbreviations and every other German list** belong to the file of German (#142). `Flutter`, the one name of `ALSO_ENGLISH_WORDS`, is an ordinary English word: English leaves it out of `fields.technologies` and reads it from its capital, and German lists it. The synonym group for "architecture" has one English form, so English holds no group for it. "Managerin", the German feminine of "manager", is German's.
- **`SectionLexicon.js`**, the headings of a CV, serves the ATS audit (#148).
- **`PlaceLexicon.js`**, the countries and regions of a location, serves the ATS parser (#148) and the date line of the letter page, which is rendering. No check of a tailoring reads it.
- **The question wordings of `Tailor.js`** are text for the user. The app words a question from its codes ([R13](rules.md#r13-localisation-happens-at-the-edges)).
- **`LANGUAGES`, the names of the languages in `Tailor.js`**, belong to the prompt (#151).
- **`IDENTITY`, `COPIED` and `WORDED`** are field names of cv-giovanni's profile, not words of a language.
- **The shapes** above go to the checks that read them (#138, #139).

### Source and licence

Every list states where its entries come from and under which licence, beside them.

- `source` is free text that names the origin precisely enough to find the entries again: a repository, a commit, the list inside it. A list that is a port says so ("cv-giovanni 6e28147 domain/AdvertLexicon.js ADVERT.stopwords.en").
- `licence` is an SPDX identifier. The entries of cv-giovanni are under ISC.
- The licences a list may carry: `ISC`.
- That set is closed and the decoder refuses any other licence. Widening it is a reviewed change: a licence must be compatible with ISC and with the App Store.
- A list with no source or no licence, or with a licence outside the set, is refused.

### Refusals

Every refusal is a typed error that carries codes and no text ([R7](rules.md#r7-errors-are-typed-per-context-and-translated-at-the-boundary)):

| Error | When |
|---|---|
| `corruptWordList(.index, nil)` | The index is not a JSON array of language codes, is empty, names a code that is none of the six, lists a language twice, or is too large |
| `corruptWordList(.language(l), nil)` | A fault of the file of `l` and not of a list: it is missing though the index lists it, is not JSON, is too large, has a version other than 1, names another language than the index lists it for, or has a key the format does not know at the top or in a group |
| `corruptWordList(.language(l), key)` | The list `key` has a key the format does not know, lacks its `source`, `licence` or `entries`, or holds a value of the wrong type |
| `corruptWordList(.language(l), key)` | The `licence` of the list is not one of the allowed set |
| `corruptWordList(.language(l), key)` | A `source`, a `licence` or an entry is empty, is not trimmed, hides a character, or folds to nothing |
| `corruptWordList(.language(l), key)` | Two entries of the list are the same once folded, so a word two forms of address or two ranks share counts too |
| `corruptWordList(.language(l), key)` | A month is outside 1 to 12, a value is negative, or a group of synonyms has fewer than 2 forms |
| `corruptWordList(.language(l), key)` | A tied count does not hold `{count}` and `{employer}` once each, holds another brace, or has no word between them |
| `corruptWordList(.language(l), key)` | The `order` of the streets is missing or is none of the three |
| `corruptWordList(.language(l), key)` | The form of a form of address is not `ms` or `mr` |
| `corruptWordList(.language(l), key)` | A rank is none of the eight, or a word claims no rank, or claims one twice |
| `incompleteWordList(l, key)` | The file of `l` has no group or no list for `key` (a missing group is reported as its first list), a list has no entry, or no month is named for one of the twelve |
| `unsupportedLanguage` | `forLanguage(_:)` is asked for a language that has no file |

### Adding a language

1. Add `<code>.json` to `Resources/WordLists/`, with the `version`, its own `language` and every list of the key table at format version 1. Each list states its source and its licence.
2. Add the code to `index.json`.

Nothing else changes: no code, no manifest line. The folder is copied whole, and `TailoringLanguage` already knows the six codes. Two tests keep the files honest: the files in the folder, but the index, are exactly the languages of the index, and a file that lacks a key another file has is refused as incomplete, because every file must hold every key.
