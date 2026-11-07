# App Store listing

The texts of PrestoCV's App Store product page for version 1.0, one section per App Store localization, and the notes for App Review. They are entered by hand in App Store Connect, so this file is the versioned copy: a change to the listing changes this file first.

- **Where they go.** In App Store Connect, the name and the subtitle are under App Information. The keywords, the promotional text, the description and the screenshots are under the version (1.0), for each localization. The notes for App Review are under App Review Information, at the bottom of the version page.
- **Limits.** Name and subtitle: 30 characters. Keywords: 100 bytes of UTF-8, each keyword longer than two characters, separated by commas without spaces. Promotional text: 170 characters. Description, What's New and review notes: 4,000 characters. App Review Guideline 2.3.7 rules out prices and "free" claims in the name, the subtitle and the screenshots, and competitors' names in the keywords; guideline 2.3.1 asks for review notes that say specifically how to reach every feature.
- **What's New.** App Store Connect has no What's New field for an app's first version, so version 1.0 has none. The texts below are those of version 1.0.1, which has the field.
- **Counts.** `Tools/Release/check-store-listing.py` counts every text of this file, checks it against those limits, and checks that the table under [Character counts](#character-counts) is current. Run it after changing a text; `--write` rewrites the table.
- **What each claim rests on.** Every feature named here is in the app as it ships (the legacy app of ADR 0022). In the AI draft, the facts (the name, the contacts, the employers, the schools, the dates, the figures and the languages) occur in the person's description; the summary, the role descriptions and the skills are written by the model from it and may be wrong, so no text promises a correct draft ([ADR 0031](../architecture/adr/0031-let-the-ai-draft-write-around-the-facts.md), with [ADR 0023](../architecture/adr/0023-ground-the-ai-draft-in-the-description.md)). The device list is Apple's, from "How to get Apple Intelligence" (support.apple.com/en-us/121115), read on 2026-10-18.
- **The copy is written for each market, not translated.** The register follows the app's own texts: "Sie" in German, "vous" in French, "tu" in Italian and Spanish, "você" in Brazilian Portuguese. The French texts put a no-break space (U+00A0) before a colon and inside « », as French typography does: keep it when copying them.

## Settings for every localization

| Setting | Value |
|---|---|
| Primary category | Business (already set) |
| Secondary category | Productivity (already set) |
| Age rating | 4+ (already set) |
| App Privacy | Data Not Collected (already set) |
| Support URL | `https://prestocv.app` (already set). Apple requires the support page to show contact information: it gives `support@prestocv.app`, which must deliver to the maintainer before the app is submitted. |
| Marketing URL | `https://prestocv.app` (already set). |
| Privacy Policy URL | `https://prestocv.app/privacy.html`, in every localization (already set). |
| Sign-in required (App Review Information) | No |
| Screenshots | iPhone and iPad sets. Each caption is a title and a line below it, written `Title | Line below`: the title says what the person gets, the line says how. The captions of each locale name the iPhone; in the iPad set, "iPhone" becomes "iPad", and the rest of the sentence stays as it is in every language. |

## Localizations

| App Store Connect localization | Code | Why |
|---|---|---|
| English (U.S.) | en-US | The primary language. The default of the United States storefront. |
| English (U.K.) | en-GB | The default of the United Kingdom and Ireland, and an additional language of Germany, Austria, Switzerland, Italy, France, Spain, Portugal, Brazil, Mexico and the rest of Latin America in Apple's storefront table. The name and the subtitle are the ones already set; the description and the captions say "CV" only, as British usage does. |
| German | de-DE | The default of Germany, Austria and Switzerland. |
| Italian | it | The default of Italy. App Store Connect's code for Italian has no region. |
| Spanish (Spain) | es-ES | The default of Spain. |
| Spanish (Mexico) | es-MX | Worth it: Apple's storefront table makes Spanish (Mexico), not Spanish (Spain), the default language of Mexico and of every Spanish-speaking storefront of Latin America, and an additional language of the United States. The app's Spanish reads naturally there ("tú", "Agrega"). Its copy uses Latin American usage: "vacante", "salud", "hoja de vida". |
| French | fr-FR | The default of France. |
| Portuguese (Portugal) | pt-PT | The default of Portugal. The app's own Portuguese is Brazilian ("você", "salvar", "Carregando"), so this copy describes the buttons instead of quoting them. |
| Portuguese (Brazil) | pt-BR | Worth it: it is the default language of Brazil and an additional language of the United States, and it is the variety the app's Portuguese texts are written in, so the listing and the app match. |

## Screenshots

Six screenshots per localization and device, one per caption, in the order of the captions. A tool makes them, so that the next version makes them again in the same way.

| # | Screen |
|---|---|
| 1 | My CVs: a complete CV and three copies of it adapted to other jobs. |
| 2 | The AI screen with the person's description typed in. The simulator has no on-device model, so the test turns the AI entry on with `-AIAvailabilityOverride available`. On a smaller iPhone the form goes up to show the whole of Generate, but the heading stays below the navigation bar: the descriptions are short enough for both. |
| 3 | The editor of a CV stored with the facts of that description, where the person checks and changes every line, as its caption says. What the description does not mention, the e-mail, the phone and the portfolio, is blank, and so is the summary: a stored CV holds only what was typed into it, while an AI draft writes one ([ADR 0031](../architecture/adr/0031-let-the-ai-draft-write-around-the-facts.md)). The navigation bar carries the name of the CV and "Saved on this device", with no Done button. On iPhone the form is scrolled until the Personal Information heading sits just under the navigation bar, so that every fact and every blank field with its hint is in view, and the section bar floats over the empty summary box and covers no text; the test fails if a bar covers a text or cuts one in two. The app makes an AI draft only with the on-device model, and has no fake one (rule R14), so this is a CV stored with those facts, not a draft: it has no draft notice. |
| 4 | New CV with its choices: import a CV, the AI draft, Example CV and Empty CV. The test turns the AI entry on with `-AIAvailabilityOverride available`, so the AI card is live, not dimmed with the reason that a device without Apple Intelligence shows; the test fails if it is dimmed. |
| 5 | The export sheet: the preview, the language of the headings, Send or save PDF, and the designs. |
| 6 | The share sheet over the export sheet, with the PDF in the serif font style and its headings in the CV's language. |

- **Sizes.** The tool makes up to three sets. Version 1 has two: `iphone`, 1320 × 2868 (iPhone 17 Pro Max), the iPhone 6.9-inch set (`APP_IPHONE_69`), and `ipad`, 2064 × 2752 (iPad Pro 13-inch), the iPad 13-inch set (`APP_IPAD_PRO_3GEN_129`). App Store Connect scales the 6.9-inch images to the smaller iPhones. The third, `iphone-6.3`, 1206 × 2622 (iPhone 17 Pro, `APP_IPHONE_61`), is made only if `asc-prestocv validate` reports an iPhone set missing after the upload, as Apple's "Screenshot specifications" (developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications, read on 2026-10-18) name an "iPhone with Dynamic Island (medium display)" set. The sizes each type takes are the ones `asc-prestocv screenshots sizes --all` lists (read on 2026-10-26). The images are PNG without an alpha channel, which Apple rejects.
- **Languages.** The app has six languages. en-GB, es-MX and pt-BR use the screenshots of en, es and pt with their own captions; pt-PT uses those of pt, whose texts are Brazilian, like the app's.
- **People.** One fictional person per language: Emily Parker (en), Lena Hoffmann (de), Lucía Martínez (es), Camille Laurent (fr), Giulia Conti (it), Ana Ferreira (pt). Their employers and schools are made up, their e-mail addresses are at example.com, and they have no phone number. They are in `PrestoCVUITests/StoreScreenshotFixtures.swift`.
- **Capture.** `StoreScreenshotsUITests`, one test per language. Each screen is a launch of its own: the debug-only launch argument `-PrestoCVUITestsSeed` hands the app the CV files of the screen, in Base64, which it writes into the new UI-test storage folder of `-PrestoCVUITestsEmptyStorage` before it reads it, in a folder beside it that is moved to its place once every file is there, so that a seed that fails or is cut short leaves no half-seeded folder and the next launch on that name seeds again (a folder that is already there keeps what the app saved in it, so a relaunch on a named folder never has its CVs overwritten by the seed). The test finds the buttons by the app's own texts, which the tool hands over from `PrestoCV/Localizable.xcstrings` (the test does not read the source tree; a key the tool did not hand over stops the test and names the key), and attaches each screen at the simulator's resolution once the element it shows has come to rest: nothing waits for a fixed time. It is in no test plan that CI runs: the `PrestoCV` plan skips it, the `CI` plan has no UI tests, and only the `StoreScreenshots` plan holds it. That plan turns test timeouts on, so that the 30 minutes each language's test is given (`executionTimeAllowance`) end a test that hangs; without the setting Xcode ignores the allowance.
- **Compose.** `Tools/Release/compose-store-screenshots.swift`, in Swift with Core Text and the system font, puts each caption above its screenshot on the app's dark green (#0A403B), with a glow of the accent (#00DAC3) and a plain rounded frame: no picture of a device. The title is set large and bold, in at most two lines, and the line below it smaller, in at most three. All the titles of a locale and device get one size, and all its lines below another: the largest at which each fits, or a little smaller where that lets them break much better. The line breaks go after a sentence or a clause where they can, and not after a short word such as "a" or "der"; apostrophes are set as ’, and "Apple Intelligence" stays on one line. The titles start at the same height, and the screenshot stays in the same place, on every image of a device.
- **Regenerating them.** On a Mac with Xcode 27 or later, from the repository:

  ```bash
  Tools/Release/store-screenshots.sh --output ~/Desktop/PrestoCV-screenshots --devices iphone,ipad
  ```

  The images are in `<output>/<locale>/<device>/NN.png`, and `<output>/contact-sheet-<device>.png` shows every locale of a device at a glance: look at each one before uploading. `--languages de,fr` captures some languages only. After a caption changes, run `check-store-listing.py`, then the same command with `--compose-only`, which composes the captures again without the simulator, and refuses unless all six captures of every language and device asked for are there (it prints when they were taken); `--listing <file>` takes the captions from another copy of this file, such as a change still under review. A capture run starts by clearing the folders in `captures/` of the devices and languages it was asked for, before it looks for a simulator, builds or erases anything, so that a run that fails at any step leaves none of them for a `--compose-only` to take, and no capture of an earlier run is ever composed with the captions of this one. The six captures of a language are copied into `<language>.partial` and renamed once all six are there, so a copy that fails leaves no file of that language. A language whose test fails (or attaches fewer than six screenshots) keeps none; the other languages are still run, and then the run ends before the composer. The composer takes exactly six captions for each locale and checks that each capture has the size of its device, before it writes anything. It makes the whole output in `<output>/.compose-staging` and puts it in place only when all of it is made, replacing each `<locale>/<device>` folder and each contact sheet whole, so that a run that fails at any step (a capture missing for a later locale or device, a write that fails, a folder that cannot be replaced) leaves the output of the earlier run as it was, with no half-made folder next to it. A run that is killed while it puts the output in place may leave only part of the set, in an empty output folder too, where nothing is moved aside: so the composer writes `<output>/.compose-promoting`, which lists the items, before the first move, and removes it after the last, the contact sheets included. While it is there the next run refuses and says why: look at the items it lists (`<output>/.compose-previous` holds what that run had replaced, if it had replaced anything), put back or remove them, then remove the file and `.compose-previous`, and run again. A capture run that is killed leaves the captures of the languages it had finished, whole, and none of the language it was in or of those after it: the captures it replaces were cleared when it began, and a language is put in place by a rename. The arguments are checked first, before the lock is taken or any simulator is erased. Each language takes about two and a half minutes per device. The tool erases and boots its own simulators, named `PrestoCV store <device>` (`--simulator-prefix` changes the name, which must still start with `PrestoCV store`: the tool erases every simulator of that name, so no other simulator may carry it), one run at a time (a second run exits with 75 while the first lives, or while the capture of a first run that was killed still goes on, and an interrupted run puts its simulator back), each language in its own language and region, so that the share sheet speaks it too: the status bar at 9:41 (09:41 in the regions that write the hour with two digits), full battery and signal, the light appearance, and no autocorrection or spell check. On iPad the status bar also shows a date, 9 January 2007 in every image, and the name of the app. The simulator writes that date in English in every language, so the composer writes it again in the language of each locale, as the iPad writes it, and refuses a capture whose status bar does not show the time, the date and the name on a plain background, a date that leaves no room for the name, and a language it has no date for.

## Character counts

Characters are Unicode characters; keywords are counted in UTF-8 bytes, which is Apple's limit for them. Captions are counted one by one, the title and the line below apart; the column shows the longest of each (title limit 30, line limit 80, set by the checker so that they fit the screenshot).

<!-- counts:start -->
| Locale | Name (30) | Subtitle (30) | Keywords (100 bytes) | Promotional text (170) | Description (4000) | Captions (longest title / line) | What's New (4000) |
|---|---|---|---|---|---|---|---|
| en-US | 27 | 29 | 98 | 166 | 2494 | 24 / 63 (6 captions) | 398 |
| en-GB | 27 | 29 | 98 | 166 | 2485 | 24 / 63 (6 captions) | 398 |
| de-DE | 30 | 30 | 96 | 163 | 2931 | 29 / 72 (6 captions) | 481 |
| it | 24 | 29 | 99 | 170 | 2708 | 23 / 62 (6 captions) | 416 |
| es-ES | 28 | 26 | 93 | 163 | 2767 | 22 / 64 (6 captions) | 429 |
| es-MX | 28 | 26 | 97 | 162 | 2745 | 22 / 64 (6 captions) | 429 |
| fr-FR | 25 | 28 | 91 | 168 | 2924 | 28 / 73 (6 captions) | 435 |
| pt-PT | 30 | 29 | 94 | 168 | 2811 | 24 / 61 (6 captions) | 438 |
| pt-BR | 28 | 29 | 95 | 162 | 2722 | 24 / 61 (6 captions) | 445 |

Notes for App Review: 3997 characters (4000).
<!-- counts:end -->

## Notes for App Review

In English, once for every localization, under App Review Information → Notes. The button names are the app's English texts.

```text
PrestoCV is a CV maker for iPhone and iPad. It has no account, no sign-in, no in-app purchase, no subscription and no ads, so no demo account is needed: every feature is available as soon as the app opens.

WITHOUT THE AI DRAFT (any iPhone or iPad)
1. On the first launch, tap "Start from an example" and choose one of the five examples, or tap "Create My First CV" for a blank CV. Later, the + button in My CVs opens the New CV screen with the same choices, "Empty CV" and "Example CV".
2. Edit any section: the editor saves by itself, and "Saved on this device" shows under the title. The examples leave the name and the contact details blank: add a name and an email, because the PDF needs both.
3. Tap "Preview & export", the share symbol at the top right. Choose a design, a font style and a color palette in the Templates, Fonts and Colors tabs; the preview updates.
4. Tap "Send or save PDF" to open the share sheet; Save to Files, for example, saves the PDF.
5. Saving: change a CV, close the app from the app switcher and open it again: the change is there.

THE AI DRAFT
- It needs a device that supports Apple Intelligence: iPhone 15 Pro, iPhone 15 Pro Max, iPhone 16 models or later, iPhone Air, iPad models with M1 or later, or iPad mini (A17 Pro). Apple Intelligence must be turned on (Settings > Apple Intelligence & Siri) and its model downloaded, with the device language and the Siri language set to the same supported language.
- On such a device, the first launch offers "Draft My CV with AI" right after "Paste or import a CV". Later, choose "AI CV Generation" on the New CV screen, in the same place.
- Type a description of at least 10 characters. The screen shows an example under "Example"; this is the same text, ready to paste:
I'm Maria Rossi, a primary school teacher from Bologna. Since 2016 I have taught at the Don Milani school, where I trained 3 new teachers. Before that, from 2012 to 2016, I worked as an assistant in a nursery. I studied Education Sciences at the University of Bologna and graduated in 2012. I speak Italian (native) and English (B2). In my free time I like chess and hiking.
- Tap "Generate CV with AI". Writing takes up to a minute. The draft opens in the editor with a notice. Names, contacts, dates, employers, schools and figures come from the description, and anything it does not mention is left blank. The summary, the role descriptions and the skills are written by the on-device model, which is why the notice asks the person to check every field. Nothing leaves the device. Export it as above.
- If the AI draft can't run, the AI option is shown dimmed, right after "Paste or import a CV", with a short reason, and tapping it shows the full text: where to turn Apple Intelligence on (Settings; System Settings on a Mac), that its model is still downloading (the option then turns on by itself), or that the device doesn't support AI drafts and the CV can be created by hand or from an example. The rest of the app works the same.
- For an English or German description, the draft also needs the system's language data. If iOS has not downloaded it, the screen says it waits, for 60 seconds at most, before the writing starts; then the draft opens by itself, or a message says it did not come.

NETWORK AND DATA
- The app makes no network requests. It contains no networking code and no third-party SDKs. The only download it can start is the system's own: iOS downloads its language data for the AI draft, as it downloads the model. The AI draft runs on Apple's on-device model through the Foundation Models framework, and the PDF is rendered on the device.
- CVs are stored only in the app's container on the device. Nothing is sent to the developer or to anyone else; a PDF leaves the device only when the user shares it from the share sheet.
- The privacy label "Data Not Collected" is therefore accurate: the app collects no data and does not track. Its privacy manifest declares no collected data types and no tracking domains.
```

## English (U.S.), en-US

### Name

```text
PrestoCV: CV & Resume Maker
```

### Subtitle

```text
Write your CV fast, privately
```

### Keywords

```text
builder,creator,curriculum,vitae,job,application,template,pdf,career,generator,offline,writer,work
```

### Promotional text

```text
Tell your story in your own words, and on supported devices Apple Intelligence drafts your CV on the device. Pick a design, export a polished PDF. No account, no ads.
```

### Description

```text
PrestoCV helps you write a clear CV or resume on your iPhone or iPad and send it as a PDF. There's no account to create, no subscription and no ads. Your CVs are saved on your device, and the app doesn't track you.

THREE WAYS TO START
• Draft it with AI: describe your work and studies in your own words, and Apple Intelligence writes a first draft on your device.
• Start from an example: five sample CVs from different fields (academia, business, design, healthcare and software), with the name and contact details left blank for you to fill in.
• Start from a blank CV.

A DRAFT THAT STARTS FROM YOUR WORDS
• Apple's on-device model writes the draft on your iPhone or iPad. Your description isn't sent anywhere.
• Your name, contacts, employers, schools and dates come from your description, and what you don't mention stays blank. The summary, the job descriptions and the skills are suggested by the model for your role and field.
• It can still make mistakes, such as a detail in the wrong place: check every field before you send it.
• The AI draft needs a device that supports Apple Intelligence, with Apple Intelligence turned on: iPhone 15 Pro, iPhone 15 Pro Max, iPhone 16 models or later, iPhone Air, iPad models with M1 or later, and iPad mini (A17 Pro).
• On every other device, PrestoCV works fully without it: you start from a blank CV or from an example.

WRITE AND EDIT
• Sections for your profile, work experience, education, skills, languages, certifications, interests and links.
• Language levels from A1 to C2, plus native.
• Keep several CVs, and duplicate one to adapt it for another job.
• Changes are saved on your device a moment after you stop typing, and when you leave the editor or the app. If one can't be saved, PrestoCV tells you and keeps it in the editor.

EXPORT TO PDF
• Three designs, three font styles and four color palettes, with a preview of the PDF and its page count.
• "Send or save PDF" opens the share sheet: email it, message it or save it to Files.
• The headings follow the language your CV is written in. Write it in German and the PDF says "Berufserfahrung", even if the app is in English. You can also choose the language yourself.

FOR EVERYONE
• Available in English, German, Spanish, French, Italian and Portuguese.
• Supports Dynamic Type and VoiceOver.

PRIVACY
No account, no ads, no tracking, no data collected. PrestoCV never sends your CVs or your description anywhere on its own: a PDF leaves your device only when you share it.
```

### Screenshot captions

```text
Your CV, on your terms. | No account. No subscription. Your CV stays on your iPhone.
Just tell your story. | Apple Intelligence turns it into a first draft, on your iPhone.
Written from your words. | You check and change every line.
Start in seconds. | From a blank CV or one of five examples.
Look the part. | Three designs, three font styles, four color palettes.
Ready to send. | A polished PDF, with headings in your CV's language.
```

### What's New

```text
The AI draft now keeps your own words when you paste in a CV, reading it the way an import does. A job you still hold now ends with the word your CV uses for "present". A duty is no longer written twice or put under the wrong job, and a finished job no longer reads in the present tense. An imported certification with an "Issued by" line below it is now one certification with its issuer, not two.
```

## English (U.K.), en-GB

### Name

```text
PrestoCV: CV & Resume Maker
```

### Subtitle

```text
Write your CV fast, privately
```

### Keywords

```text
builder,creator,curriculum,vitae,job,application,template,pdf,career,generator,offline,writer,work
```

### Promotional text

```text
Tell your story in your own words, and on supported devices Apple Intelligence drafts your CV on the device. Pick a design, export a polished PDF. No account, no ads.
```

### Description

```text
PrestoCV helps you write a clear CV on your iPhone or iPad and send it as a PDF. There's no account to create, no subscription and no ads. Your CVs are saved on your device, and the app doesn't track you.

THREE WAYS TO START
• Draft it with AI: describe your work and studies in your own words, and Apple Intelligence writes a first draft on your device.
• Start from an example: five sample CVs from different fields (academia, business, design, healthcare and software), with the name and contact details left blank for you to fill in.
• Start from a blank CV.

A DRAFT THAT STARTS FROM YOUR WORDS
• Apple's on-device model writes the draft on your iPhone or iPad. Your description isn't sent anywhere.
• Your name, contacts, employers, schools and dates come from your description, and what you don't mention stays blank. The summary, the job descriptions and the skills are suggested by the model for your role and field.
• It can still make mistakes, such as a detail in the wrong place: check every field before you send it.
• The AI draft needs a device that supports Apple Intelligence, with Apple Intelligence turned on: iPhone 15 Pro, iPhone 15 Pro Max, iPhone 16 models or later, iPhone Air, iPad models with M1 or later, and iPad mini (A17 Pro).
• On every other device, PrestoCV works fully without it: you start from a blank CV or from an example.

WRITE AND EDIT
• Sections for your profile, work experience, education, skills, languages, certifications, interests and links.
• Language levels from A1 to C2, plus native.
• Keep several CVs, and duplicate one to tailor it to another job.
• Changes are saved on your device a moment after you stop typing, and when you leave the editor or the app. If one can't be saved, PrestoCV tells you and keeps it in the editor.

EXPORT TO PDF
• Three designs, three font styles and four colour palettes, with a preview of the PDF and its page count.
• "Send or save PDF" opens the share sheet: email it, message it or save it to Files.
• The headings follow the language your CV is written in. Write it in German and the PDF says "Berufserfahrung", even if the app is in English. You can also choose the language yourself.

FOR EVERYONE
• Available in English, German, Spanish, French, Italian and Portuguese.
• Supports Dynamic Type and VoiceOver.

PRIVACY
No account, no ads, no tracking, no data collected. PrestoCV never sends your CVs or your description anywhere on its own: a PDF leaves your device only when you share it.
```

### Screenshot captions

```text
Your CV, on your terms. | No account. No subscription. Your CV stays on your iPhone.
Just tell your story. | Apple Intelligence turns it into a first draft, on your iPhone.
Written from your words. | You check and change every line.
Start in seconds. | From a blank CV or one of five examples.
Look the part. | Three designs, three font styles, four colour palettes.
Ready to send. | A polished PDF, with headings in your CV's language.
```

### What's New

```text
The AI draft now keeps your own words when you paste in a CV, reading it the way an import does. A job you still hold now ends with the word your CV uses for "present". A duty is no longer written twice or put under the wrong job, and a finished job no longer reads in the present tense. An imported certification with an "Issued by" line below it is now one certification with its issuer, not two.
```

## German, de-DE

### Name

```text
PrestoCV: Lebenslauf erstellen
```

### Subtitle

```text
CV schreiben – schnell, privat
```

### Keywords

```text
Bewerbung,Vorlage,Muster,Beispiel,Curriculum,Vitae,Job,Karriere,PDF,Generator,Ausbildung,Offline
```

### Promotional text

```text
Erzählen Sie Ihren Werdegang in eigenen Worten: Auf unterstützten Geräten entwirft Apple Intelligence Ihren Lebenslauf direkt dort. Design wählen, PDF exportieren.
```

### Description

```text
Mit PrestoCV schreiben Sie Ihren Lebenslauf auf dem iPhone oder iPad und verschicken ihn als PDF. Sie brauchen kein Konto und kein Abo, und es gibt keine Werbung. Ihre Lebensläufe bleiben auf Ihrem Gerät – ganz ohne Tracking.

DREI WEGE ZUM LEBENSLAUF
• Mit KI entwerfen: Beschreiben Sie Berufserfahrung und Ausbildung in eigenen Worten, und Apple Intelligence schreibt auf Ihrem Gerät einen ersten Entwurf.
• Mit einem Beispiel beginnen: fünf Beispiel-Lebensläufe aus verschiedenen Bereichen (Wissenschaft, Wirtschaft, Design, Gesundheitswesen und Softwareentwicklung). Name und Kontaktdaten sind leer, damit Sie Ihre eigenen eintragen.
• Mit einem leeren Lebenslauf beginnen.

EIN ENTWURF, DER VON IHREN WORTEN AUSGEHT
• Das On-Device-Modell von Apple schreibt den Entwurf direkt auf Ihrem iPhone oder iPad. Ihre Beschreibung wird nirgendwohin gesendet.
• Name, Kontaktdaten, Arbeitgeber, Schulen und Zeitangaben stammen aus Ihrer Beschreibung, und was Sie nicht erwähnen, bleibt leer. Zusammenfassung, Tätigkeitsbeschreibungen und Kenntnisse schlägt das Modell passend zu Ihrem Beruf und Fachgebiet vor.
• Der Entwurf kann trotzdem Fehler enthalten, etwa eine Angabe an der falschen Stelle: Prüfen Sie jedes Feld, bevor Sie ihn versenden.
• Für den KI-Entwurf brauchen Sie ein Gerät mit Apple Intelligence, auf dem Apple Intelligence eingeschaltet ist: iPhone 15 Pro, iPhone 15 Pro Max, alle Modelle ab iPhone 16, iPhone Air, iPad-Modelle mit M1 oder neuer und iPad mini (A17 Pro).
• Auf allen anderen Geräten funktioniert PrestoCV vollständig ohne KI: Sie beginnen mit einem leeren Lebenslauf oder einem Beispiel.

SCHREIBEN UND BEARBEITEN
• Abschnitte für Kurzprofil, Berufserfahrung, Ausbildung, Fähigkeiten, Sprachen, Zertifikate, Interessen und Links.
• Sprachniveaus von A1 bis C2 sowie Muttersprache.
• Mehrere Lebensläufe verwalten und einen duplizieren, um ihn an eine andere Stelle anzupassen.
• Änderungen werden einen Moment nach dem Tippen auf Ihrem Gerät gespeichert, außerdem beim Verlassen des Editors oder der App. Lässt sich eine Änderung nicht speichern, meldet PrestoCV das und behält sie im Editor.

ALS PDF EXPORTIEREN
• Drei Designs, drei Schriftstile und vier Farbpaletten, mit PDF-Vorschau und Seitenzahl.
• „PDF senden oder speichern“ öffnet das Teilen-Menü: per Mail oder Nachricht verschicken oder in der Dateien-App sichern.
• Die Überschriften folgen der Sprache, in der Ihr Lebenslauf geschrieben ist. Schreiben Sie ihn auf Englisch, steht im PDF „Work experience“, auch wenn die App auf Deutsch ist. Die Sprache können Sie auch selbst wählen.

FÜR ALLE
• Verfügbar auf Deutsch, Englisch, Spanisch, Französisch, Italienisch und Portugiesisch.
• Unterstützt Dynamic Type und VoiceOver.

DATENSCHUTZ
Kein Konto, keine Werbung, kein Tracking, keine Datenerhebung. PrestoCV sendet Ihre Lebensläufe und Ihre Beschreibung nie von sich aus irgendwohin: Ein PDF verlässt Ihr Gerät nur, wenn Sie es teilen.
```

### Screenshot captions

```text
Ihr Lebenslauf. Nur Ihrer. | Kein Konto, kein Abo. Ihr Lebenslauf bleibt auf Ihrem iPhone.
Erzählen Sie einfach. | Apple Intelligence macht daraus einen ersten Entwurf – auf Ihrem iPhone.
Aus Ihren Worten geschrieben. | Sie prüfen und ändern jede Zeile.
Sofort loslegen. | Mit einem leeren Lebenslauf oder einem von fünf Beispielen.
Ein starker Auftritt. | Drei Designs, drei Schriftstile, vier Farbpaletten.
Bereit zum Versenden. | Ein sauberes PDF, mit Überschriften in der Sprache des Lebenslaufs.
```

### What's New

```text
Der KI-Entwurf übernimmt Ihre eigenen Worte, wenn Sie einen Lebenslauf einfügen, und liest ihn wie einen Import. Eine Stelle, die Sie noch innehaben, endet jetzt mit dem Wort, das Ihr Lebenslauf für „heute“ verwendet. Eine Aufgabe steht nicht mehr doppelt da oder unter der falschen Stelle, und eine beendete Stelle steht nicht mehr in der Gegenwart. Ein importiertes Zertifikat mit einer Zeile „Ausgestellt von“ darunter ist jetzt ein Zertifikat mit seinem Aussteller, nicht zwei.
```

## Italian, it

### Name

```text
PrestoCV: Crea il tuo CV
```

### Subtitle

```text
Curriculum veloce e riservato
```

### Keywords

```text
vitae,lavoro,candidatura,modello,esempio,pdf,carriera,compilare,generatore,impiego,offline,scrivere
```

### Promotional text

```text
Racconta il tuo percorso con parole tue: sui dispositivi compatibili, Apple Intelligence ne fa una bozza sul dispositivo. Scegli un design, esporta il PDF. Senza account.
```

### Description

```text
PrestoCV ti aiuta a scrivere il tuo curriculum su iPhone o iPad e a inviarlo in PDF. Non devi creare un account e non ci sono abbonamenti né pubblicità. I tuoi CV restano sul tuo dispositivo e l'app non ti traccia.

TRE MODI PER INIZIARE
• Scrivilo con l'IA: descrivi il tuo lavoro e i tuoi studi con parole tue, e Apple Intelligence scrive una prima bozza sul tuo dispositivo.
• Parti da un esempio: cinque CV di esempio in ambiti diversi (università, azienda, design, sanità e sviluppo software), con nome e contatti lasciati vuoti, da completare con i tuoi.
• Parti da un CV vuoto.

UNA BOZZA CHE PARTE DALLE TUE PAROLE
• La scrive il modello di Apple direttamente sul tuo iPhone o iPad. La tua descrizione non viene inviata da nessuna parte.
• Nome, contatti, datori di lavoro, scuole e date vengono dalla tua descrizione, e ciò che non indichi resta vuoto. Il riepilogo, le descrizioni dei ruoli e le competenze li propone il modello, in base al tuo ruolo e al tuo settore.
• La bozza può comunque contenere errori, per esempio un dato nel posto sbagliato: controlla ogni campo prima di inviarla.
• La bozza con l'IA richiede un dispositivo compatibile con Apple Intelligence, con la funzione attiva: iPhone 15 Pro, iPhone 15 Pro Max, tutti i modelli da iPhone 16 in poi, iPhone Air, modelli di iPad con chip M1 o successivo e iPad mini (A17 Pro).
• Su tutti gli altri dispositivi PrestoCV funziona completamente anche senza: parti da un CV vuoto o da un esempio.

SCRIVI E MODIFICA
• Sezioni per profilo professionale, esperienza lavorativa, formazione, competenze, lingue, certificazioni, interessi e link.
• Livelli di lingua da A1 a C2, più madrelingua.
• Tieni più CV e duplicane uno per adattarlo a un'altra offerta di lavoro.
• Le modifiche vengono salvate sul tuo dispositivo un attimo dopo che smetti di scrivere, e quando esci dall'editor o dall'app. Se una modifica non si può salvare, PrestoCV te lo dice e la tiene nell'editor.

ESPORTA IN PDF
• Tre design, tre stili di carattere e quattro palette di colori, con l'anteprima del PDF e il numero di pagine.
• «Invia o salva il PDF» apre il menu di condivisione: mandalo via email o per messaggio, oppure salvalo in File.
• I titoli seguono la lingua in cui è scritto il CV. Se lo scrivi in inglese, nel PDF trovi «Work experience», anche con l'app in italiano. Puoi anche scegliere la lingua tu.

PER TUTTI
• Disponibile in italiano, inglese, tedesco, spagnolo, francese e portoghese.
• Supporta Dynamic Type e VoiceOver.

PRIVACY
Nessun account, nessuna pubblicità, nessun tracciamento, nessun dato raccolto. PrestoCV non invia mai di sua iniziativa i tuoi CV o la tua descrizione: un PDF lascia il dispositivo solo quando lo condividi tu.
```

### Screenshot captions

```text
Il tuo CV, solo tuo. | Nessun account, nessun abbonamento. Resta sul tuo iPhone.
Racconta la tua storia. | Apple Intelligence ne scrive una prima bozza, sul tuo iPhone.
Nasce dalle tue parole. | Tu controlli e modifichi ogni riga.
Parti subito. | Da un CV vuoto o da uno dei cinque esempi.
Fai bella figura. | Tre design, tre stili di carattere, quattro palette di colori.
Pronto da inviare. | Un PDF curato, con i titoli nella lingua del tuo CV.
```

### What's New

```text
La bozza con l'IA ora mantiene le tue parole quando incolli un CV: lo legge come un'importazione. Un lavoro in corso finisce con la parola che usa il tuo CV per dire «oggi». Un compito non viene più scritto due volte né messo sotto il lavoro sbagliato, e un lavoro concluso non è più al presente. Una certificazione importata con sotto una riga «Rilasciato da» ora è una sola certificazione con il suo ente, non due.
```

## Spanish (Spain), es-ES

### Name

```text
PrestoCV: Crea tu currículum
```

### Subtitle

```text
Tu CV, rápido y en privado
```

### Keywords

```text
vitae,empleo,trabajo,plantilla,modelo,ejemplo,pdf,hacer,generador,carrera,candidatura,offline
```

### Promotional text

```text
Cuenta tu trayectoria con tus palabras: en los dispositivos compatibles, Apple Intelligence redacta tu CV allí mismo. Elige un diseño y exporta el PDF. Sin cuenta.
```

### Description

```text
PrestoCV te ayuda a escribir tu currículum en el iPhone o el iPad y a enviarlo en PDF. No tienes que crear ninguna cuenta y no hay suscripciones ni anuncios. Tus CV se guardan en tu dispositivo y la app no te rastrea.

TRES FORMAS DE EMPEZAR
• Redáctalo con IA: describe tu trabajo y tus estudios con tus propias palabras, y Apple Intelligence escribe un primer borrador en tu dispositivo.
• Empieza con un ejemplo: cinco CV de ejemplo de distintos ámbitos (universidad, empresa, diseño, sanidad y desarrollo de software), con el nombre y los datos de contacto en blanco para que pongas los tuyos.
• Empieza con un CV vacío.

UN BORRADOR QUE PARTE DE TUS PALABRAS
• El modelo de Apple lo redacta en tu propio iPhone o iPad. Tu descripción no se envía a ningún sitio.
• Tu nombre, tus datos de contacto, las empresas, los centros de estudio y las fechas salen de tu descripción, y lo que no menciones queda en blanco. El resumen, las descripciones de los puestos y las competencias los propone el modelo según tu puesto y tu sector.
• Aun así, el borrador puede tener errores, como un dato en el lugar equivocado: revisa cada campo antes de enviarlo.
• El borrador con IA necesita un dispositivo compatible con Apple Intelligence, con Apple Intelligence activado: iPhone 15 Pro, iPhone 15 Pro Max, todos los modelos a partir del iPhone 16, iPhone Air, modelos de iPad con chip M1 o posterior e iPad mini (A17 Pro).
• En los demás dispositivos, PrestoCV funciona por completo sin él: empiezas con un CV vacío o con un ejemplo.

ESCRIBE Y EDITA
• Secciones para perfil profesional, experiencia laboral, formación, competencias, idiomas, certificaciones, intereses y enlaces.
• Niveles de idioma de A1 a C2, además de lengua materna.
• Guarda varios CV y duplica uno para adaptarlo a otra oferta.
• Los cambios se guardan en tu dispositivo un instante después de que dejes de escribir, y al salir del editor o de la app. Si uno no se puede guardar, PrestoCV te lo indica y lo mantiene en el editor.

EXPORTA A PDF
• Tres diseños, tres estilos de fuente y cuatro paletas de colores, con vista previa del PDF y su número de páginas.
• «Enviar o guardar PDF» abre el menú de compartir: mándalo por correo o por mensaje, o guárdalo en Archivos.
• Los títulos siguen el idioma en que está escrito el CV. Si lo escribes en inglés, el PDF dice «Work experience», aunque la app esté en español. También puedes elegir tú el idioma.

PARA TODO EL MUNDO
• Disponible en español, inglés, alemán, francés, italiano y portugués.
• Compatible con Dynamic Type y VoiceOver.

PRIVACIDAD
Sin cuenta, sin anuncios, sin rastreo y sin recopilación de datos. PrestoCV nunca envía por su cuenta tus CV ni tu descripción a ningún sitio: un PDF solo sale de tu dispositivo cuando tú lo compartes.
```

### Screenshot captions

```text
Tu CV, solo tuyo. | Sin cuenta ni suscripción. Tu CV se queda en tu iPhone.
Cuenta tu historia. | Apple Intelligence redacta un primer borrador en tu iPhone.
Nace de tus palabras. | Tú revisas y cambias cada línea.
Empieza ya. | Con un CV vacío o con uno de los cinco ejemplos.
Causa buena impresión. | Tres diseños, tres estilos de fuente, cuatro paletas de colores.
Listo para enviar. | Un PDF cuidado, con los títulos en el idioma de tu CV.
```

### What's New

```text
El borrador con IA ahora conserva tus propias palabras cuando pegas un CV, porque lo lee como una importación. Un empleo actual termina con la palabra que usa tu CV para decir «actualidad». Una tarea ya no se escribe dos veces ni aparece bajo el empleo equivocado, y un empleo terminado ya no está en presente. Una certificación importada con una línea «Expedido por» debajo ahora es una sola certificación con su emisor, no dos.
```

## Spanish (Mexico), es-MX

### Name

```text
PrestoCV: Crea tu currículum
```

### Subtitle

```text
Tu CV, rápido y en privado
```

### Keywords

```text
vitae,empleo,trabajo,plantilla,formato,ejemplo,pdf,hacer,solicitud,hoja de vida,generador,vacante
```

### Promotional text

```text
Cuenta tu trayectoria con tus palabras: en los dispositivos compatibles, Apple Intelligence redacta tu CV ahí mismo. Elige un diseño y exporta el PDF. Sin cuenta.
```

### Description

```text
PrestoCV te ayuda a escribir tu currículum en tu iPhone o iPad y a enviarlo en PDF. No tienes que crear una cuenta y no hay suscripciones ni anuncios. Tus CV se guardan en tu dispositivo y la app no te rastrea.

TRES FORMAS DE EMPEZAR
• Redáctalo con IA: describe tu trabajo y tus estudios con tus propias palabras, y Apple Intelligence escribe un primer borrador en tu dispositivo.
• Empieza con un ejemplo: cinco CV de ejemplo de distintas áreas (universidad, negocios, diseño, salud y desarrollo de software), con el nombre y los datos de contacto en blanco para que pongas los tuyos.
• Empieza con un CV vacío.

UN BORRADOR QUE PARTE DE TUS PALABRAS
• El modelo de Apple lo redacta en tu propio iPhone o iPad. Tu descripción no se envía a ninguna parte.
• Tu nombre, tus datos de contacto, las empresas, las escuelas y las fechas salen de tu descripción, y lo que no menciones queda en blanco. El resumen, las descripciones de los puestos y las habilidades son sugerencias del modelo para tu puesto y tu área.
• Aun así, el borrador puede tener errores, como un dato en el lugar equivocado: revisa cada campo antes de enviarlo.
• El borrador con IA necesita un dispositivo compatible con Apple Intelligence, con Apple Intelligence activado: iPhone 15 Pro, iPhone 15 Pro Max, todos los modelos a partir del iPhone 16, iPhone Air, modelos de iPad con chip M1 o posterior y iPad mini (A17 Pro).
• En los demás dispositivos, PrestoCV funciona por completo sin él: empiezas con un CV vacío o con un ejemplo.

ESCRIBE Y EDITA
• Secciones para perfil profesional, experiencia laboral, formación, competencias, idiomas, certificaciones, intereses y enlaces.
• Niveles de idioma de A1 a C2, además de lengua materna.
• Guarda varios CV y duplica uno para adaptarlo a otra vacante.
• Los cambios se guardan en tu dispositivo un instante después de que dejes de escribir, y al salir del editor o de la app. Si uno no se puede guardar, PrestoCV te lo indica y lo mantiene en el editor.

EXPORTA A PDF
• Tres diseños, tres estilos de fuente y cuatro paletas de colores, con vista previa del PDF y su número de páginas.
• "Enviar o guardar PDF" abre el menú para compartir: mándalo por correo o por mensaje, o guárdalo en Archivos.
• Los títulos siguen el idioma en que está escrito el CV. Si lo escribes en inglés, el PDF dice "Work experience", aunque la app esté en español. También puedes elegir tú el idioma.

PARA TODOS
• Disponible en español, inglés, alemán, francés, italiano y portugués.
• Compatible con Dynamic Type y VoiceOver.

PRIVACIDAD
Sin cuenta, sin anuncios, sin rastreo y sin recopilación de datos. PrestoCV nunca envía por su cuenta tus CV ni tu descripción a ninguna parte: un PDF solo sale de tu dispositivo cuando tú lo compartes.
```

### Screenshot captions

```text
Tu CV, solo tuyo. | Sin cuenta ni suscripción. Tu CV se queda en tu iPhone.
Cuenta tu historia. | Apple Intelligence redacta un primer borrador en tu iPhone.
Nace de tus palabras. | Tú revisas y cambias cada línea.
Empieza ya. | Con un CV vacío o con uno de los cinco ejemplos.
Causa buena impresión. | Tres diseños, tres estilos de fuente, cuatro paletas de colores.
Listo para enviar. | Un PDF cuidado, con los títulos en el idioma de tu CV.
```

### What's New

```text
El borrador con IA ahora conserva tus propias palabras cuando pegas un CV, porque lo lee como una importación. Un empleo actual termina con la palabra que usa tu CV para decir «actualidad». Una tarea ya no se escribe dos veces ni aparece bajo el empleo equivocado, y un empleo terminado ya no está en presente. Una certificación importada con una línea «Expedido por» debajo ahora es una sola certificación con su emisor, no dos.
```

## French, fr-FR

### Name

```text
PrestoCV : Créez votre CV
```

### Subtitle

```text
Rapide, privé et sans compte
```

### Keywords

```text
curriculum,vitae,créer,faire,modèle,exemple,emploi,travail,candidature,pdf,stage,rédiger
```

### Promotional text

```text
Racontez votre parcours avec vos mots : sur les appareils compatibles, Apple Intelligence rédige votre CV sur place. Choisissez un design, exportez le PDF. Sans compte.
```

### Description

```text
PrestoCV vous aide à rédiger votre CV sur iPhone ou iPad et à l'envoyer en PDF. Aucun compte à créer, aucun abonnement, aucune publicité. Vos CV restent sur votre appareil, et l'app ne vous piste pas.

TROIS FAÇONS DE COMMENCER
• Rédiger avec l'IA : décrivez votre parcours et vos études avec vos propres mots, et Apple Intelligence rédige un premier brouillon sur votre appareil.
• Partir d'un exemple : cinq CV d'exemple dans des domaines variés (recherche, entreprise, design, santé et développement logiciel), avec le nom et les coordonnées à compléter.
• Partir d'un CV vide.

UN BROUILLON QUI PART DE VOS MOTS
• Le modèle d'Apple le rédige directement sur votre iPhone ou votre iPad. Votre description n'est envoyée nulle part.
• Votre nom, vos coordonnées, vos employeurs, vos établissements et vos dates viennent de votre description, et ce que vous ne mentionnez pas reste vide. Le résumé, les descriptions de poste et les compétences sont proposés par le modèle selon votre métier et votre domaine.
• Le brouillon peut tout de même contenir des erreurs, comme une information au mauvais endroit : vérifiez chaque champ avant de l'envoyer.
• Le brouillon IA nécessite un appareil compatible avec Apple Intelligence, sur lequel Apple Intelligence est activé : iPhone 15 Pro, iPhone 15 Pro Max, tous les modèles à partir de l'iPhone 16, iPhone Air, modèles d'iPad avec puce M1 ou ultérieure et iPad mini (A17 Pro).
• Sur tous les autres appareils, PrestoCV fonctionne pleinement sans l'IA : vous partez d'un CV vide ou d'un exemple.

RÉDIGER ET MODIFIER
• Des rubriques pour le profil, l'expérience professionnelle, la formation, les compétences, les langues, les certifications, les centres d'intérêt et les liens.
• Niveaux de langue de A1 à C2, et langue maternelle.
• Gérez plusieurs CV et dupliquez-en un pour l'adapter à une autre offre.
• Les modifications sont enregistrées sur votre appareil un instant après que vous avez cessé d'écrire, et quand vous quittez l'éditeur ou l'app. Si l'une d'elles ne peut pas l'être, PrestoCV vous le dit et la garde dans l'éditeur.

EXPORTER EN PDF
• Trois mises en page, trois styles de police et quatre palettes de couleurs, avec un aperçu du PDF et son nombre de pages.
• « Envoyer ou enregistrer le PDF » ouvre le menu de partage : envoyez-le par e-mail ou par message, ou enregistrez-le dans Fichiers.
• Les titres suivent la langue dans laquelle votre CV est rédigé. Rédigez-le en anglais et le PDF affiche « Work experience », même si l'app est en français. Vous pouvez aussi choisir la langue vous-même.

POUR TOUT LE MONDE
• Disponible en français, anglais, allemand, espagnol, italien et portugais.
• Compatible avec Dynamic Type et VoiceOver.

CONFIDENTIALITÉ
Pas de compte, pas de publicité, pas de pistage, aucune donnée collectée. PrestoCV n'envoie jamais de lui-même vos CV ni votre description : un PDF ne quitte votre appareil que lorsque vous le partagez.
```

### Screenshot captions

```text
Votre CV, rien qu'à vous. | Sans compte ni abonnement. Votre CV reste sur votre iPhone.
Racontez votre parcours. | Apple Intelligence en rédige un premier brouillon, sur votre iPhone.
Rédigé à partir de vos mots. | Vous vérifiez et modifiez chaque ligne.
Lancez-vous. | Partez d'un CV vide ou de l'un des cinq exemples.
Faites bonne impression. | Trois mises en page, trois styles de police, quatre palettes de couleurs.
Prêt à envoyer. | Un PDF soigné, avec des titres dans la langue du CV.
```

### What's New

```text
Le brouillon par IA garde désormais vos propres mots quand vous collez un CV : il le lit comme un import. Un poste en cours se termine par le mot que votre CV emploie pour « aujourd’hui ». Une tâche n’est plus écrite deux fois ni placée sous le mauvais poste, et un poste terminé n’est plus au présent. Une certification importée suivie d’une ligne « Délivré par » est désormais une seule certification avec son organisme, et non deux.
```

## Portuguese (Portugal), pt-PT

### Name

```text
PrestoCV: Crie o seu currículo
```

### Subtitle

```text
CV rápido, privado, sem conta
```

### Keywords

```text
curriculum,vitae,emprego,trabalho,modelo,exemplo,pdf,candidatura,carreira,criar,fazer,estágio
```

### Promotional text

```text
Conte o seu percurso por palavras suas: nos dispositivos compatíveis, o Apple Intelligence escreve o rascunho no próprio dispositivo. Escolha um design e exporte o PDF.
```

### Description

```text
O PrestoCV ajuda-o a escrever o seu currículo no iPhone ou no iPad e a enviá-lo em PDF. Não precisa de criar conta e não há subscrições nem anúncios. Os seus currículos ficam guardados no seu dispositivo e a app não o rastreia.

TRÊS FORMAS DE COMEÇAR
• Escreva com IA: descreva o seu percurso profissional e os seus estudos por palavras suas, e o Apple Intelligence escreve um primeiro rascunho no seu dispositivo.
• Comece por um exemplo: cinco currículos de exemplo de áreas diferentes (universidade, gestão, design, saúde e desenvolvimento de software), com o nome e os contactos em branco para preencher com os seus.
• Comece por um currículo vazio.

UM RASCUNHO QUE PARTE DAS SUAS PALAVRAS
• É o modelo da Apple que o escreve, no seu próprio iPhone ou iPad. A sua descrição não é enviada para lado nenhum.
• O nome, os contactos, os empregadores, as escolas e as datas vêm da sua descrição, e o que não mencionar fica em branco. O resumo, as descrições das funções e as competências são sugeridos pelo modelo de acordo com a sua função e a sua área.
• Ainda assim, o rascunho pode ter erros, como um dado no sítio errado: verifique cada campo antes de o enviar.
• O rascunho com IA precisa de um dispositivo compatível com o Apple Intelligence, com esta funcionalidade ativada: iPhone 15 Pro, iPhone 15 Pro Max, todos os modelos a partir do iPhone 16, iPhone Air, modelos de iPad com chip M1 ou posterior e iPad mini (A17 Pro).
• Nos restantes dispositivos, o PrestoCV funciona plenamente sem IA: começa por um currículo vazio ou por um exemplo.

ESCREVER E EDITAR
• Secções para perfil profissional, experiência profissional, formação, competências, idiomas, certificações, interesses e ligações.
• Níveis de língua de A1 a C2, e língua materna.
• Guarde vários currículos e duplique um para o adaptar a outra oferta de emprego.
• As alterações são guardadas no seu dispositivo um instante depois de parar de escrever e quando sai do editor ou da app. Se uma não puder ser guardada, o PrestoCV avisa-o e mantém-na no editor.

EXPORTAR EM PDF
• Três designs, três estilos de letra e quatro paletas de cores, com pré-visualização do PDF e o número de páginas.
• O botão para enviar ou guardar o PDF abre o menu de partilha: envie-o por e-mail ou mensagem, ou guarde-o na app Ficheiros.
• Os títulos seguem a língua em que o currículo está escrito. Se o escrever em inglês, o PDF mostra «Work experience», mesmo com a app em português. Também pode escolher a língua.

PARA TODOS
• Disponível em português, inglês, alemão, espanhol, francês e italiano.
• Compatível com Dynamic Type e VoiceOver.

PRIVACIDADE
Sem conta, sem anúncios, sem rastreio e sem recolha de dados. O PrestoCV nunca envia por iniciativa própria os seus currículos nem a sua descrição: um PDF só sai do seu dispositivo quando o partilha.
```

### Screenshot captions

```text
O seu currículo, só seu. | Sem conta nem subscrição. O seu currículo fica no seu iPhone.
Conte a sua história. | O Apple Intelligence faz um primeiro rascunho, no seu iPhone.
Nasce das suas palavras. | Verifica e altera cada linha.
Comece já. | Com um currículo vazio ou com um dos cinco exemplos.
Cause boa impressão. | Três designs, três estilos de letra, quatro paletas de cores.
Pronto a enviar. | Um PDF cuidado, com os títulos na língua do seu currículo.
```

### What's New

```text
O rascunho com IA passa a manter as suas palavras quando cola um currículo, porque o lê como uma importação. Um emprego atual termina com a palavra que o seu currículo usa para «atualidade». Uma tarefa já não é escrita duas vezes nem colocada no emprego errado, e um emprego terminado já não está no presente. Uma certificação importada com uma linha «Emitido por» por baixo passa a ser uma só certificação com a sua entidade, e não duas.
```

## Portuguese (Brazil), pt-BR

### Name

```text
PrestoCV: Crie seu currículo
```

### Subtitle

```text
CV rápido, privado, sem conta
```

### Keywords

```text
curriculum,vitae,emprego,trabalho,modelo,exemplo,pdf,vaga,criar,fazer,gerador,estágio,carreira
```

### Promotional text

```text
Conte sua trajetória com suas palavras: nos aparelhos compatíveis, o Apple Intelligence escreve o rascunho no próprio aparelho. Escolha um design e exporte o PDF.
```

### Description

```text
O PrestoCV ajuda você a escrever seu currículo no iPhone ou iPad e enviá-lo em PDF. Não precisa criar conta e não tem assinatura nem anúncios. Seus currículos ficam salvos no seu aparelho, e o app não rastreia você.

TRÊS JEITOS DE COMEÇAR
• Escreva com IA: descreva sua experiência e seus estudos com suas próprias palavras, e o Apple Intelligence escreve um primeiro rascunho no seu aparelho.
• Comece com um exemplo: cinco currículos de exemplo de áreas diferentes (universidade, negócios, design, saúde e desenvolvimento de software), com nome e contatos em branco para você preencher.
• Comece com um currículo em branco.

UM RASCUNHO QUE PARTE DAS SUAS PALAVRAS
• Quem escreve é o modelo da Apple, no seu próprio iPhone ou iPad. Sua descrição não é enviada para lugar nenhum.
• Seu nome, contatos, empregadores, escolas e datas vêm da sua descrição, e o que você não mencionar fica em branco. O resumo, as descrições dos cargos e as competências são sugestões do modelo para o seu cargo e a sua área.
• Ainda assim, o rascunho pode ter erros, como um dado no lugar errado: confira cada campo antes de enviá-lo.
• O rascunho com IA precisa de um aparelho compatível com o Apple Intelligence, com o recurso ativado: iPhone 15 Pro, iPhone 15 Pro Max, todos os modelos a partir do iPhone 16, iPhone Air, modelos de iPad com chip M1 ou posterior e iPad mini (A17 Pro).
• Nos outros aparelhos, o PrestoCV funciona por completo sem IA: você começa com um currículo em branco ou com um exemplo.

ESCREVA E EDITE
• Seções para perfil profissional, experiência profissional, formação, competências, idiomas, certificações, interesses e links.
• Níveis de idioma de A1 a C2, e língua materna.
• Tenha vários currículos e duplique um para adaptá-lo a outra vaga.
• As alterações são salvas no seu aparelho um instante depois que você para de digitar e quando você sai do editor ou do app. Se uma não puder ser salva, o PrestoCV avisa e a mantém no editor.

EXPORTE EM PDF
• Três designs, três estilos de fonte e quatro paletas de cores, com pré-visualização do PDF e o número de páginas.
• "Enviar ou salvar PDF" abre o menu de compartilhamento: mande por e-mail ou mensagem, ou salve no app Arquivos.
• Os títulos seguem o idioma em que o currículo está escrito. Se você escrever em inglês, o PDF mostra "Work experience", mesmo com o app em português. Você também pode escolher o idioma.

PARA TODOS
• Disponível em português, inglês, alemão, espanhol, francês e italiano.
• Compatível com Dynamic Type e VoiceOver.

PRIVACIDADE
Sem conta, sem anúncios, sem rastreamento e sem coleta de dados. O PrestoCV nunca envia por conta própria seus currículos nem sua descrição: um PDF só sai do seu aparelho quando você o compartilha.
```

### Screenshot captions

```text
Seu currículo, só seu. | Sem conta nem assinatura. Seu currículo fica no seu iPhone.
Conte sua história. | O Apple Intelligence faz um primeiro rascunho, no seu iPhone.
Nasce das suas palavras. | Você confere e muda cada linha.
Comece já. | Com um currículo em branco ou com um dos cinco exemplos.
Cause uma boa impressão. | Três designs, três estilos de fonte, quatro paletas de cores.
Pronto para enviar. | Um PDF caprichado, com os títulos no idioma do seu currículo.
```

### What's New

```text
O rascunho com IA agora mantém suas palavras quando você cola um currículo, porque o app o lê como uma importação. Um emprego atual termina com a palavra que seu currículo usa para “atualidade”. Uma tarefa não é mais escrita duas vezes nem colocada no emprego errado, e um emprego encerrado não fica mais no presente. Uma certificação importada com uma linha “Emitido por” embaixo agora é uma só certificação com a entidade emissora, e não duas.
```
