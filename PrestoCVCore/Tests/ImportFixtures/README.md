# The import's synthetic corpus

The fixtures of the import's contract table ([ADR 0027](../../../docs/architecture/adr/0027-import-a-cv-from-its-text-with-rules.md)),
read by `ContractTableTests` in `PrestoCVImportingTests` and, for the PDFs, by the PDFKit reader's contract test.

**Every person, employer, address and number here is invented. No real CV is ever committed**, not even anonymised.

- E-mail addresses use the reserved domains `example.com`, `example.org` and `example.net` (RFC 2606).
- Phone numbers: the United Kingdom's range for fiction (`07700 900xxx`), France's (`01 99 00 xx xx`, `06 39 98 xx xx`), and
  elsewhere numbers filled with zeros in the country's format (`+39 333 000 0101`, `+49 170 0000101`).
- Employers are named "Esempio", "Beispiel", "Ejemplo", "Exemple", "Exemplo", "Example" or "Acme". Places and schools may
  be real: they are not personal data.

## What is here

- **Twelve people, two per language** (en, it, de, es, fr, pt), in `<language>-<name>/`, each in several forms:
  - `chat.txt`: a chat assistant's Markdown answer, with its opening and closing sentences, icons and a table;
  - `word.txt`: text copied from a Word document;
  - `latex.txt`: text copied from a LaTeX CV, with ligatures, icon glyphs and a word hyphenated at a line's end;
  - `europass.txt`: the Italian "formato europeo" copied from its Word table (the Italian people);
  - `lebenslauf.txt`: the German tabular Lebenslauf copied from its Word table (the German people);
  - `linkedin.pdf`: LinkedIn's "Save to PDF", with its sidebar (one person per language);
  - `wordpdf.pdf`: a one-column CV from a word processor (the other person per language);
  - `railpdf.pdf`: the headings right-aligned in a narrow column, each beside the first line of its section (the other
    person per language);
  - `lebenslaufpdf.pdf` and `europasspdf.pdf`: the tabular forms as PDFs.

  A PDF comes with `*.layout.json`: the words and boxes a PDF reader sees, which the Linux tests read.
- **`traps/`**: hand-written CVs in other styles, each with the trap it sets: references with their contacts, levels
  drawn as bars, "seit 2019" and a signature, the consent to data processing, an employer before the role, the one-line
  headers of a US résumé, LinkedIn's PDF copied as text with its sidebar first, labelled personal details.
- **`scan/scan.pdf`**: a PDF with no text layer.
- **`*.expected.json`**: the fields each fixture states, which the table compares with what the import found.
- **`index.json`**: every fixture, its language, form and files.

## Changing it

- The people and their forms are generated: edit `Tools/ImportFixtures/people.py` or `generate.py`, then run
  `python3 Tools/ImportFixtures/generate.py` from the repository's root, and review the output like code.
- A trap is written by hand: add `traps/<name>.txt` and its `traps/<name>.expected.json`, then run the generator to
  list it in `index.json`.
- **Rows are never removed or weakened.** A defect found adds a fixture that fails, before its fix.
