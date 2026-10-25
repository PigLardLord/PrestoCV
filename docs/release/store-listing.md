# App Store listing

The texts of PrestoCV's App Store product page for version 1.0, one section per App Store localization, and the notes for App Review. They are entered by hand in App Store Connect, so this file is the versioned copy: a change to the listing changes this file first.

- **Where they go.** In App Store Connect, the name and the subtitle are under App Information. The keywords, the promotional text, the description and the screenshots are under the version (1.0), for each localization. The notes for App Review are under App Review Information, at the bottom of the version page.
- **Limits.** Name and subtitle: 30 characters. Keywords: 100 bytes of UTF-8, each keyword longer than two characters, separated by commas without spaces. Promotional text: 170 characters. Description, What's New and review notes: 4,000 characters. App Review Guideline 2.3.7 rules out prices and "free" claims in the name, the subtitle and the screenshots, and competitors' names in the keywords; guideline 2.3.1 asks for review notes that say specifically how to reach every feature.
- **What's New.** App Store Connect has no What's New field for an app's first version, so the 1.0 texts are not entered there. They serve as TestFlight's What to Test, and as the start of the next version's notes.
- **Counts.** `Tools/Release/check-store-listing.py` counts every text of this file, checks it against those limits, and checks that the table under [Character counts](#character-counts) is current. Run it after changing a text; `--write` rewrites the table.
- **What each claim rests on.** Every feature named here is in the app as it ships (the legacy app of ADR 0022). The AI draft keeps only values that occur in the person's description, but it can still put one in the wrong place, so no text promises a draft without mistakes ([ADR 0023](../architecture/adr/0023-ground-the-ai-draft-in-the-description.md)). The device list is Apple's, from "How to get Apple Intelligence" (support.apple.com/en-us/121115), read on 2026-10-18.
- **The copy is written for each market, not translated.** The register follows the app's own texts: "Sie" in German, "vous" in French, "tu" in Italian and Spanish, "você" in Brazilian Portuguese. The French texts put a no-break space (U+00A0) before a colon and inside « », as French typography does: keep it when copying them.

## Settings for every localization

| Setting | Value |
|---|---|
| Primary category | Business (already set) |
| Secondary category | Productivity (already set) |
| Age rating | 4+ (already set) |
| App Privacy | Data Not Collected (already set) |
| Support URL | `https://prestocv.app` (already set). Apple requires the support page to show contact information: it gives `support@prestocv.app`, which must deliver to the owner before the app is submitted. |
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

## Character counts

Characters are Unicode characters; keywords are counted in UTF-8 bytes, which is Apple's limit for them. Captions are counted one by one, the title and the line below apart; the column shows the longest of each (title limit 30, line limit 80, set by the checker so that they fit the screenshot).

<!-- counts:start -->
| Locale | Name (30) | Subtitle (30) | Keywords (100 bytes) | Promotional text (170) | Description (4000) | Captions (longest title / line) | What's New (4000) |
|---|---|---|---|---|---|---|---|
| en-US | 27 | 29 | 98 | 166 | 2411 | 23 / 63 (6 captions) | 184 |
| en-GB | 27 | 29 | 98 | 166 | 2402 | 23 / 63 (6 captions) | 184 |
| de-DE | 30 | 30 | 96 | 163 | 2834 | 26 / 72 (6 captions) | 230 |
| it | 24 | 29 | 99 | 170 | 2616 | 23 / 62 (6 captions) | 209 |
| es-ES | 28 | 26 | 93 | 163 | 2657 | 25 / 64 (6 captions) | 213 |
| es-MX | 28 | 26 | 97 | 162 | 2631 | 25 / 64 (6 captions) | 210 |
| fr-FR | 25 | 28 | 91 | 168 | 2795 | 25 / 73 (6 captions) | 220 |
| pt-PT | 30 | 29 | 94 | 168 | 2702 | 27 / 61 (6 captions) | 215 |
| pt-BR | 28 | 29 | 95 | 162 | 2635 | 27 / 61 (6 captions) | 205 |

Notes for App Review: 3995 characters (4000).
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
- Tap "Generate CV with AI". Writing takes up to a minute. The draft opens in the editor with a notice. Every value it fills in occurs in the description, and anything the description does not mention is left blank. It can still put a detail in the wrong place, which is why the notice asks the person to check every field. Export it as above.
- If the AI draft can't run, the AI option is shown dimmed, right after "Paste or import a CV", with a short reason, and tapping it shows the full text: where to turn Apple Intelligence on (Settings; System Settings on a Mac), that its model is still downloading (the option then turns on by itself), or that the device doesn't support AI drafts and the CV can be created by hand or from an example. The rest of the app works the same.
- For an English or German description, the draft also needs the system's language data. If iOS has not downloaded it, the screen says it waits, for 60 seconds at most, before the writing starts; then the draft opens by itself, or a message says it did not come.

NETWORK AND DATA
- The app makes no network requests. It contains no networking code and no third-party SDKs. The only download it can start is the system's own: iOS downloads its language data for the AI draft, as it downloads the model. The AI draft runs on Apple's on-device model through the Foundation Models framework, and the PDF is rendered on the device.
- CVs are stored only in the app's container on the device. Nothing is sent to the developer or to anyone else; a PDF leaves the device only when the user shares it from the share sheet.
- The privacy label "Data Not Collected" is therefore accurate: the app collects no data and does not track. Its privacy manifest declares no collected data types, no tracking and no tracking domains.

PURCHASES
This version has no in-app purchases and no subscriptions.
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

AN AI DRAFT THAT STICKS TO YOUR WORDS
• Apple's on-device model writes the draft on your iPhone or iPad. Your description isn't sent anywhere.
• Names, dates, employers, schools and skills that aren't in your description are left out, and anything you don't mention stays blank.
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
Built from your words. | Anything you didn't write stays blank.
Start in seconds. | From a blank CV or one of five examples.
Look the part. | Three designs, three font styles, four color palettes.
Ready to send. | A polished PDF, with headings in your CV's language.
```

### What's New

```text
The first version of PrestoCV. Write your CV on your iPhone or iPad, draft it with Apple Intelligence on supported devices, and export it as a PDF in three designs. No account, no ads.
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

AN AI DRAFT THAT STICKS TO YOUR WORDS
• Apple's on-device model writes the draft on your iPhone or iPad. Your description isn't sent anywhere.
• Names, dates, employers, schools and skills that aren't in your description are left out, and anything you don't mention stays blank.
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
Built from your words. | Anything you didn't write stays blank.
Start in seconds. | From a blank CV or one of five examples.
Look the part. | Three designs, three font styles, four colour palettes.
Ready to send. | A polished PDF, with headings in your CV's language.
```

### What's New

```text
The first version of PrestoCV. Write your CV on your iPhone or iPad, draft it with Apple Intelligence on supported devices, and export it as a PDF in three designs. No account, no ads.
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

EIN KI-ENTWURF, DER SICH AN IHRE WORTE HÄLT
• Das On-Device-Modell von Apple schreibt den Entwurf direkt auf Ihrem iPhone oder iPad. Ihre Beschreibung wird nirgendwohin gesendet.
• Namen, Zeitangaben, Arbeitgeber, Schulen und Kenntnisse, die nicht in Ihrer Beschreibung stehen, fallen weg, und was Sie nicht erwähnen, bleibt leer.
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
Aus Ihren Worten. | Was Sie nicht schreiben, bleibt leer.
Sofort loslegen. | Mit einem leeren Lebenslauf oder einem von fünf Beispielen.
Ein starker Auftritt. | Drei Designs, drei Schriftstile, vier Farbpaletten.
Bereit zum Versenden. | Ein sauberes PDF, mit Überschriften in der Sprache des Lebenslaufs.
```

### What's New

```text
Die erste Version von PrestoCV. Schreiben Sie Ihren Lebenslauf auf dem iPhone oder iPad, entwerfen Sie ihn auf unterstützten Geräten mit Apple Intelligence und exportieren Sie ihn als PDF in drei Designs. Ohne Konto, ohne Werbung.
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

UNA BOZZA FEDELE ALLE TUE PAROLE
• La scrive il modello di Apple direttamente sul tuo iPhone o iPad. La tua descrizione non viene inviata da nessuna parte.
• Nomi, date, datori di lavoro, scuole e competenze che non compaiono nella tua descrizione vengono scartati, e ciò che non indichi resta vuoto.
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
Dalle tue parole. | Ciò che non scrivi resta vuoto.
Parti subito. | Da un CV vuoto o da uno dei cinque esempi.
Fai bella figura. | Tre design, tre stili di carattere, quattro palette di colori.
Pronto da inviare. | Un PDF curato, con i titoli nella lingua del tuo CV.
```

### What's New

```text
La prima versione di PrestoCV. Scrivi il tuo CV su iPhone o iPad, fatti preparare una bozza da Apple Intelligence sui dispositivi compatibili ed esportalo in PDF in tre design. Senza account, senza pubblicità.
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

UN BORRADOR QUE SE CIÑE A TUS PALABRAS
• El modelo de Apple lo redacta en tu propio iPhone o iPad. Tu descripción no se envía a ningún sitio.
• Los nombres, fechas, empresas, centros de estudio y competencias que no aparecen en tu descripción se descartan, y lo que no menciones queda en blanco.
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
A partir de tus palabras. | Lo que no escribas queda en blanco.
Empieza ya. | Con un CV vacío o con uno de los cinco ejemplos.
Causa buena impresión. | Tres diseños, tres estilos de fuente, cuatro paletas de colores.
Listo para enviar. | Un PDF cuidado, con los títulos en el idioma de tu CV.
```

### What's New

```text
La primera versión de PrestoCV. Escribe tu CV en el iPhone o el iPad, deja que Apple Intelligence redacte un borrador en los dispositivos compatibles y expórtalo en PDF con tres diseños. Sin cuenta y sin anuncios.
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

UN BORRADOR QUE RESPETA TUS PALABRAS
• El modelo de Apple lo redacta en tu propio iPhone o iPad. Tu descripción no se envía a ninguna parte.
• Los nombres, fechas, empresas, escuelas y habilidades que no aparecen en tu descripción se descartan, y lo que no menciones queda en blanco.
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
A partir de tus palabras. | Lo que no escribas queda en blanco.
Empieza ya. | Con un CV vacío o con uno de los cinco ejemplos.
Causa buena impresión. | Tres diseños, tres estilos de fuente, cuatro paletas de colores.
Listo para enviar. | Un PDF cuidado, con los títulos en el idioma de tu CV.
```

### What's New

```text
La primera versión de PrestoCV. Escribe tu CV en tu iPhone o iPad, deja que Apple Intelligence redacte un borrador en los dispositivos compatibles y expórtalo en PDF con tres diseños. Sin cuenta y sin anuncios.
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

UN BROUILLON FIDÈLE À VOS MOTS
• Le modèle d'Apple le rédige directement sur votre iPhone ou votre iPad. Votre description n'est envoyée nulle part.
• Les noms, dates, employeurs, établissements et compétences absents de votre description sont écartés, et ce que vous ne mentionnez pas reste vide.
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
À partir de vos mots. | Ce que vous n'écrivez pas reste vide.
Lancez-vous. | Partez d'un CV vide ou de l'un des cinq exemples.
Faites bonne impression. | Trois mises en page, trois styles de police, quatre palettes de couleurs.
Prêt à envoyer. | Un PDF soigné, avec des titres dans la langue du CV.
```

### What's New

```text
La première version de PrestoCV. Rédigez votre CV sur iPhone ou iPad, laissez Apple Intelligence en écrire un brouillon sur les appareils compatibles et exportez-le en PDF avec trois mises en page. Sans compte, sans pub.
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

UM RASCUNHO FIEL ÀS SUAS PALAVRAS
• É o modelo da Apple que o escreve, no seu próprio iPhone ou iPad. A sua descrição não é enviada para lado nenhum.
• Nomes, datas, empregadores, escolas e competências que não constam da sua descrição são descartados, e o que não mencionar fica em branco.
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
A partir das suas palavras. | O que não escrever fica em branco.
Comece já. | Com um currículo vazio ou com um dos cinco exemplos.
Cause boa impressão. | Três designs, três estilos de letra, quatro paletas de cores.
Pronto a enviar. | Um PDF cuidado, com os títulos na língua do seu currículo.
```

### What's New

```text
A primeira versão do PrestoCV. Escreva o seu currículo no iPhone ou no iPad, deixe o Apple Intelligence escrever um rascunho nos dispositivos compatíveis e exporte-o em PDF com três designs. Sem conta, sem anúncios.
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

UM RASCUNHO FIEL ÀS SUAS PALAVRAS
• Quem escreve é o modelo da Apple, no seu próprio iPhone ou iPad. Sua descrição não é enviada para lugar nenhum.
• Nomes, datas, empregadores, escolas e competências que não estão na sua descrição são descartados, e o que você não mencionar fica em branco.
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
A partir das suas palavras. | O que você não escrever fica em branco.
Comece já. | Com um currículo em branco ou com um dos cinco exemplos.
Cause uma boa impressão. | Três designs, três estilos de fonte, quatro paletas de cores.
Pronto para enviar. | Um PDF caprichado, com os títulos no idioma do seu currículo.
```

### What's New

```text
A primeira versão do PrestoCV. Escreva seu currículo no iPhone ou iPad, deixe o Apple Intelligence escrever um rascunho nos aparelhos compatíveis e exporte em PDF com três designs. Sem conta, sem anúncios.
```
