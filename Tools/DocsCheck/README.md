# Documentation checker

It checks that the documentation matches the repository, because documentation changes with the code in the same pull request and a rule without a check is a wish (ADR 0006). It reads the repository and writes nothing. It is a Swift package with no dependency but Foundation, and it builds and runs on Linux and on macOS.

It reads these Markdown files: everything under `docs/`, every `README.md` (not under `.build/`), and `AGENTS.md`. It makes four checks.

## Running it

From the repository root:

```bash
Tools/DocsCheck/check.sh                  # the whole repository: prints the findings, exits 1 if there are any
swift test --package-path Tools/DocsCheck # the unit tests
Tools/DocsCheck/selftest.sh               # a planted stale document per check; needs the build that check.sh makes
```

No git hook runs it. Run `check.sh` before committing a change to a document, a path or an ADR; CI runs it, then its self-test and its unit tests, on every pull request (the `linux` job of `.github/workflows/ci.yml`; the macOS job does not run it, because the documents are the same on both hosts).

- **Output.** One finding per line, `file:line: code: message`, sorted by file, line and code, then `checked N documents: K findings`. The exit status is 0 without findings, 1 with findings, 2 when the check cannot run: bad arguments, or a root, a directory, a document or the planned file that cannot be read, printed as `error: cannot read <path>` with the path relative to the root. A check that cannot read never passes.
- **Environment.** `DOCS_CHECK_ROOT` is the tree to check, `DOCS_CHECK_SCRATCH` the build directory. Both default to this repository and `Tools/DocsCheck/.build`.
- **The working tree is what it reads.** A file that exists only in the working tree, untracked or ignored, satisfies a link locally and fails in CI.

## 1. Links

Every relative link in a document resolves to a file or a directory of the repository, and a link with an anchor into a Markdown file resolves to one of its headings. It reads inline links, images and link definitions, outside code spans and fenced code.

- **Resolution.** A link is resolved from the directory of the document that holds it; a leading `/` means the repository root. A query string is dropped and percent-encoding is decoded. File names are matched with their exact case, as GitHub does, so a link that works on a case-insensitive disk and breaks on GitHub is found. A link that leaves the repository does not resolve. A trailing `/` needs a directory.
- **Not followed.** Links with a scheme (`https:`, `mailto:` and so on) and links that start with `//` are not fetched.
- **Anchors.** A fragment is compared, after percent-decoding and as written, with the slugs of the headings of the target. Only ATX headings (`## Title`) count. The slug is GitHub's: the heading's rendered text in lower case, keeping letters, marks, decimal digits and connector punctuation (`_`), plus `-`, with each space becoming `-`; other numbers (`²`, `½`) and every symbol are dropped. Code spans, link text and emphasis contribute their text; images and HTML tags do not. An underscore run is dropped only when it opens or closes emphasis that has its other end, so `snake_case` and `_config.yml` keep their underscores. Numeric character references (`&#169;`, `&#xA9;`) and `&amp; &lt; &gt; &quot; &apos; &nbsp;` are decoded; other named references, a `[a][b]` whose definition is elsewhere and unusual HTML tags are not rendered as GitHub does, so a heading that uses them can have a different anchor. A heading that repeats an earlier slug gets `-1`, `-2` and so on. So ``## The `rules.json` file`` is `#the-rulesjson-file` and `## Città` is `#città`.
- **Not checked.** An anchor into a file that is not Markdown, or into a directory; an explicit HTML anchor (`<a name>`, `id=`), which is not a heading.

Codes: `link-target-missing`, `link-anchor-missing`.

## 2. Named paths

A path written in a code span whose first segment is a top-level entry of the repository, such as `Tools/…`, `PrestoCVCore/…`, `docs/…` or `.github/…`, exists. Every whitespace-separated word of a code span is tried, so a command that names a path is checked too. Fenced code is not.

- **Skipped.** A word that has a placeholder or a glob (`<n>`, `*`, `?`, `{…}`, `[…]`, `…`, `...`, `$VAR`), any character that a path does not have (so URLs and expressions), a path under `~` or `/`, a path with a `.` or `..` segment, and a path through a `.build` directory, which is a build product. A word whose first segment is not a top-level entry of the repository is not a path for this check.
- **Suffixes.** `file.swift:10`, `file.swift:10:3`, `file.swift:10-20` and `file.swift#L10` name `file.swift`; an `#anchor` is dropped.
- **A trailing `/`** means a directory.
- **Planned paths.** A document may name a path before the code exists. `Tools/DocsCheck/planned.json` declares it, with the open ticket that creates it:

  ```json
  [
    {"path": "Server/Package.swift", "ticket": 155}
  ]
  ```

  A declared path that exists is a finding, so is one that no document names, and so is an entry that is not a relative path with a ticket number. The list therefore cannot go stale: the change that creates the file removes its entry. A path whose first segment is not a top-level entry, such as a new top-level directory, is not recognised, so it needs no declaration until its directory exists.

Codes: `path-missing`, `planned-path-exists`, `planned-path-unused`, `planned-file-invalid`.

## 3. ADR status

Every `docs/architecture/adr/NNNN-*.md` has a status the ADR README defines, and the index lists it with that status.

- **The line.** `- **Status:** Accepted`, outside fenced code. The first such line is the status.
- **The statuses.** `Proposed`, `Accepted`, `Rejected`, or `Superseded by [NNNN](NNNN-title.md)`, written exactly so.
- **Superseded.** The text links to an ADR file of that directory, and that file exists.
- **The index.** `docs/architecture/adr/README.md` has a table row for every ADR, `| [NNNN](NNNN-title.md) | Decision | Status |`, and its status says the same as the ADR's: for a superseded ADR, the same replacement.

Codes: `adr-directory-missing`, `adr-status-missing`, `adr-status-unknown`, `adr-superseded-without-link`, `adr-successor-missing`, `adr-index-missing`, `adr-not-indexed`, `adr-index-unknown`, `adr-index-status-differs`.

## 4. The rule is stated

`AGENTS.md` states that documentation changes with the code in the same pull request, and the pull request template asks which documents the change updates. Each is found by a marker, so the wording around it can change:

| File | Marker |
|---|---|
| `AGENTS.md` | The sentence "documentation changes with the code in the same pull request", whole words in this order, in any case, wrapped over lines, with any emphasis or punctuation. |
| `.github/pull_request_template.md` | A heading, at any level, that reads "Documents updated". |

Codes: `rule-not-stated`, `template-missing`, `template-does-not-ask`.

## Tests

- **Unit tests** (`swift test --package-path Tools/DocsCheck`): the slug rule on headings with backticks, punctuation, accents and repeats; the scanner; the path recogniser; the status text; each check on repositories built in a temporary directory; and this README, whose `Codes:` lines list exactly the codes the tool prints and whose markers are the ones the tool looks for.
- **Self-test** (`selftest.sh`): for each check, a stale document in a small repository makes the built tool fail with the expected finding at the expected line, and the fixed document passes.

## Changing it

- **A new check** is a type that returns `Finding`s, a case in `FindingCode`, a section here, unit tests and self-test cases.
- **The package is a tool target** of the architecture checker (`Tools/ArchitectureCheck/rules.json`), which maps its sources, its tests and its manifest.
