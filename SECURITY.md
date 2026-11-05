# Security policy

## Reporting a vulnerability

Report a vulnerability privately. Do not open a public issue, discussion or pull request about it.

- **On GitHub (preferred):** use private vulnerability reporting, with the "Report a vulnerability" button in the Security tab of the repository.
- **By email:** support@prestocv.app, if you cannot use GitHub.

Include what is needed to reproduce it: the app version or the commit, the device and its iOS version, the steps or a proof of concept, and what an attacker gains. If the report needs a CV, use invented data, never a real person's.

The project has one maintainer, who handles reports on a best-effort basis: they aim to acknowledge a report within 7 days, keep you informed while the fix is prepared, and agree with you when the vulnerability is disclosed. You are credited in the advisory unless you prefer not to be.

## Supported versions

| Version | Supported |
|---|---|
| The latest version on the App Store | yes |
| `main` | yes |
| Older versions | no |

A fix ships in a new version on the App Store. Older versions do not get backports.

## Scope

PrestoCV runs entirely on the device. It has no server, no account and no network service of its own (see "Privacy" in the [README](README.md)).

In scope:
- **The app and the packages of this repository:** `PrestoCV/`, `PrestoCVCore/`, `CVPDFExporter/`, `CVGeneratorAI/`, `PrestoCVApp/`, `DiagnosticLogging/` and `DiagnosticTrace/`.
- **Data leaving the device:** anything that sends data off the device, or loads remote content, without the person choosing to share or save a PDF.
- **Rendering:** markup or script injected through the fields of a CV, content that escapes the isolation of the web view that renders it, or text in a field that hides or changes other text of the PDF.
- **Files from outside:** a CV, a PDF or any other file that someone can give the person, and that the app opens or imports, is untrusted input, and so are the files in the app's storage (rules R8 and R12 in `docs/architecture/rules.md`). Such a file that crashes the app, runs code, corrupts or hides other CVs, or exposes their content is in scope.
- **The AI draft:** a description that gets text past the grounding check of [ADR 0023](docs/architecture/adr/0023-ground-the-ai-draft-in-the-description.md) into the draft, such as facts about the person that the description does not state.
- **The build and release scripts** (`ci_scripts/`, `Tools/`): anything that could expose a signing credential or let an unchecked build reach TestFlight.

Out of scope:
- vulnerabilities in iOS, in its frameworks or in Apple's on-device model: report them to Apple;
- attacks that need an unlocked device in the attacker's hands, a jailbroken device or a modified build;
- bugs that lose or damage data with no attacker involved, such as a crash on a file the app wrote itself: report them in a public issue;
- the throwaway prototype in `Prototypes/ADRValidation/`, which no release build includes;
- forks, and builds that others distribute;
- reports of automated scanners without a demonstrated impact.
