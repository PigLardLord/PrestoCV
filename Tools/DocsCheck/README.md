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

No git hook runs it. Run `check.sh` before committing a change to a document, a path or an ADR; CI runs it, then its self-test and its unit tests, on every pull request, in its own Linux job ("Linux · documentation check" in `.github/workflows/ci.yml`), so that a stale link does not hide the package build and tests. The macOS job does not run it, because the documents are the same on both hosts.

- **Output.** One finding per line, `file:line: code: message`, sorted by file, line and code, then `checked N documents: K findings`. The exit status is 0 without findings, 1 with findings, 2 when the check cannot run: bad arguments, or a root, a directory, a document or the planned file that cannot be read, printed as `error: cannot read <path>` with the path relative to the root. A check that cannot read never passes.
- **Environment.** `DOCS_CHECK_ROOT` is the tree to check, `DOCS_CHECK_SCRATCH` the build directory. Both default to this repository and `Tools/DocsCheck/.build`.
- **The working tree is what it reads.** A file that exists only in the working tree, untracked or ignored, satisfies a link locally and fails in CI.

## 1. Links

Every relative link in a document resolves to a file or a directory of the repository, and a link with an anchor into a Markdown file resolves to one of its headings. It reads inline links, images and link definitions, outside code spans, fenced code and HTML comments. A comment is one that closes on its line, one that starts its line (after at most three spaces) and runs to its `-->` over any lines, and one opened in the middle of a line that closes before the next blank line. A `<!--` in the middle of a line that closes nowhere in its paragraph is text, so a sentence that mentions the opener hides nothing. An indented code block is read like any other text: reading more can only add findings.

- **Resolution.** A link is resolved from the directory of the document that holds it; a leading `/` means the repository root. A query string is dropped and percent-encoding is decoded. File names are matched with their exact case and scalar by scalar, as GitHub does, through the listing of each directory, so a link that works on a case-insensitive disk and breaks on GitHub is found. A link that leaves the repository does not resolve. A trailing `/` needs a directory.
- **Not followed.** Links with a scheme (`https:`, `mailto:` and so on) and links that start with `//` are not fetched.
- **Anchors.** A fragment is compared, after percent-decoding and as written, with the slugs of the headings of the target, scalar by scalar: an accent written as one character and as a letter plus a combining mark are different anchors, as they are on GitHub. Only ATX headings (`## Title`) count. The slug is GitHub's: the heading's rendered text in lower case, keeping letters, marks, decimal digits and connector punctuation (`_`), plus `-`, with each space becoming `-`; other numbers (`²`, `½`) and every symbol are dropped. Code spans, link text and emphasis contribute their text; images, HTML tags and HTML comments do not, and a comment is removed, not replaced by a space (`## Alpha <!-- note --> Beta` is `#alpha--beta`). An underscore run is dropped only when it opens or closes emphasis that has its other end, so `snake_case` and `_config.yml` keep their underscores. Numeric character references (`&#169;`, `&#xA9;`) and `&amp; &lt; &gt; &quot; &apos; &nbsp;` are decoded; other named references, a `[a][b]` whose definition is elsewhere and unusual HTML tags are not rendered as GitHub does, so a heading that uses them can have a different anchor. A heading that repeats an earlier slug gets `-1`, `-2` and so on. So ``## The `rules.json` file`` is `#the-rulesjson-file` and `## Città` is `#città`.
- **Bounded.** A heading longer than 1,000 characters, or whose link labels nest deeper than 32, is a finding and is not read: it has no anchor, and no input can make the check run long or recurse without bound.
- **Explicit anchors.** The `id` and `name` attributes of an HTML tag that starts and ends on one line are anchors too, as written, so `<a name="top"></a>` is the target of `#top`. A tag is read for at most 1,000 characters, and the first tag of a line that does not end within that stops the scan of the line, so no line can make the check run long.
- **Not checked.** An anchor into a file that is not Markdown, or into a directory. A heading inside a block quote or a list item is not an anchor here, although it is on GitHub, so a link to one is reported.

Codes: `link-target-missing`, `link-anchor-missing`, `heading-too-long`, `heading-too-nested`.

## 2. Named paths

A path written in a code span exists. A word is a path when its first segment is a top-level entry of the repository, such as `Tools/…`, `PrestoCVCore/…`, `docs/…` or `.github/…`, or when it has a `/` and ends in a file extension of this list, whatever its first segment: `.swift .md .json .mjs .js .sh .yml .yaml .css .html .txt .csv` (in lower case). The second rule finds a file named in a directory that was renamed or deleted. It exists, from the repository root or from the directory of the document that names it or any directory above that, so a package's README can name `Sources/…` from the package root. It is a finding only when every place misses. Every whitespace-separated word of a code span is tried, so a command that names a path is checked too. Fenced code and HTML comments are not read.

- **Skipped.** A word that has a placeholder or a glob (`<n>`, `*`, `?`, `{…}`, `[…]`, `…`, `...`, `$VAR`), any character that a path does not have (so URLs and expressions), a path under `~` or `/`, a path with a `.` or `..` segment, a path through a `.build` directory, which is a build product, and, for the extension rule, a first segment that looks like a host name (`example.com/index.html`). A word whose first segment is not a top-level entry and that does not end in a listed extension is not a path for this check. The extension rule cannot tell the files of another repository from a mistake, so a document names those without a code span, or with a prefix and a colon (`other-repo:core/Tailor.js`), which is not a path.
- **Suffixes.** `file.swift:10`, `file.swift:10:3`, `file.swift:10-20` and `file.swift#L10` name `file.swift`; an `#anchor` is dropped.
- **A trailing `/`** means a directory.
- **Planned paths.** A document may name a path before the code exists. `Tools/DocsCheck/planned.json` declares it, with the open ticket that creates it:

  ```json
  [
    {"path": "Tools/DocsCheck/Sources/DocsCheckKit/NewCheck.swift", "ticket": 155}
  ]
  ```

  A declared path that exists is a finding, so is one that no document names, and so is an entry that is not a relative path with a ticket number. The list therefore cannot go stale: the change that creates the file removes its entry. An entry excuses a path in a code span, not a link: a link to a file that does not exist is always a finding. A path is declared as the document writes it, or as it resolves from the document's directory or one above it. A directory path whose first segment is not a top-level entry, such as a new top-level directory with no file extension, is not recognised, so it needs no declaration until that directory exists.

Codes: `path-missing`, `planned-path-exists`, `planned-path-unused`, `planned-file-invalid`.

## 3. ADR status

Every `docs/architecture/adr/NNNN-*.md` has a status the ADR README defines, and the index lists it with that status.

- **The line.** `- **Status:** Accepted`, outside fenced code. The first such line is the status.
- **The statuses.** `Proposed`, `Accepted`, `Rejected`, or `Superseded by [NNNN](NNNN-title.md)`, written exactly so.
- **Superseded.** The text links to an ADR file of that directory, and that file exists.
- **The index.** `docs/architecture/adr/README.md` has a table row for every ADR, `| [NNNN](NNNN-title.md) | Decision | Status |`. A row is matched with the file that the link in its first cell points to, not with a number, and the number it shows must be that file's. Its status says the same as the ADR's: for a superseded ADR, the same replacement. A row without a link to an ADR file is a finding, and so are two ADR files with one number.

Codes: `adr-directory-missing`, `adr-status-missing`, `adr-status-unknown`, `adr-superseded-without-link`, `adr-successor-missing`, `adr-number-duplicated`, `adr-index-missing`, `adr-not-indexed`, `adr-index-unknown`, `adr-index-status-differs`.

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
