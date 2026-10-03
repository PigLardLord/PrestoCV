// Writes the corpus `Tests/TailoringModelTests/Resources/FoldCorpus.json`: texts, and what the `fold` of cv-giovanni returns
// for each. TextFold is held to it by FoldCorpusTests, on every platform the package builds on.
//
//     node CVTailoring/Tools/GenerateFoldCorpus.mjs > CVTailoring/Tests/TailoringModelTests/Resources/FoldCorpus.json
//
// `fold` below is a copy of `domain/fold.js` of cv-giovanni at commit 6e28147 (licence ISC, Copyright (c) 2025-2026
// Giovanni Trovato). The seed is fixed, so the output is the same on every run of the same Unicode data.

function fold(text) {
  return String(text ?? '')
    .normalize('NFKD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/ß/g, 'ss')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
}

// The classes of text that fold treats in its own way, as code points that Unicode assigned long ago, so any recent
// toolchain agrees on them.
const classes = {
  ascii: [..."abcxyzABCXYZ0189 -.,/&'()+#"].map((c) => c.codePointAt(0)),
  latin: [0xc4, 0xe4, 0xd6, 0xf6, 0xdc, 0xfc, 0xe9, 0xc9, 0xe8, 0xe0, 0xf1, 0xd1, 0xe7, 0xc5, 0xe3, 0xf5, 0x10d, 0x161, 0x17e, 0x15f],
  undecomposable: [0x141, 0x142, 0xd8, 0xf8, 0xc6, 0xe6, 0x152, 0x153, 0x110, 0x111, 0x131, 0x130],
  eszett: [0xdf, 0x1e9e],
  ligatures: [0xfb00, 0xfb01, 0xfb02, 0xfb03, 0xfb04, 0xfb05, 0xfb06, 0x132, 0x133, 0x1c4, 0x1c5, 0x1c6, 0x1c9, 0x1cc],
  compatibility: [0x2460, 0x2461, 0xff21, 0xff41, 0xff46, 0x338f, 0xbd, 0xbc, 0x17f, 0x2128, 0x212a, 0x212b, 0x2126, 0x210c, 0x2160, 0x24b6],
  marks: [0x300, 0x301, 0x302, 0x308, 0x316, 0x345, 0x36f, 0x370, 0x20d0, 0x483],
  greek: [0x391, 0x3a3, 0x3a9, 0x3b1, 0x3c2, 0x3c3, 0x3b0, 0x390, 0x1f48, 0x1fb3],
  cyrillic: [0x41f, 0x43f, 0x419, 0x439, 0x401, 0x451],
  space: [0x20, 0x09, 0x0a, 0x0d, 0x0b, 0x0c, 0xa0, 0x1680, 0x2000, 0x2003, 0x200a, 0x2028, 0x2029, 0x202f, 0x205f, 0x3000, 0xfeff],
  notSpace: [0x85, 0x180e, 0x200b, 0x200d, 0x200c, 0x2060],
  scripts: [0x1100, 0xac00, 0xd55c, 0x4e2d, 0x65e5, 0x3042, 0x30a2, 0x5d0, 0x627, 0x1f600, 0x1d7ce, 0x1d400]
};
const pool = Object.values(classes).flat();

// A generator that is the same everywhere: a 32-bit linear congruential one.
let seed = 20261003;
const next = () => (seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0) / 4294967296;
const pick = (list) => list[Math.floor(next() * list.length)];

const texts = [];
// Each code point of each class alone, between letters, and doubled.
for (const list of Object.values(classes)) {
  for (const cp of list) {
    const c = String.fromCodePoint(cp);
    texts.push(c, `a${c}b`, ` ${c} `, `${c}${c}`);
  }
}
// Words as the lists hold them, and the cases of the source's own tests.
for (const word of ['Straße', 'STRASSE', 'GROẞ', 'Café', 'Ausgewählte Erfolge', 'Ausgewahlte Erfolge', 'männlich/weiblich/divers',
  'Via  Slack', '  sprachen  ', 'FULL-TIME', 'CI/CD', 'm/w/d', 'ΑΣ', 'ΑΣΑ', "Α'Σ", 'ΣΑΣ', 'ὈΔΥΣΣΕΎΣ', 'İstanbul', 'Œuvre', 'Łódź',
  'ﬁnance', 'ｆｕｌｌ', 'é̂', 'aͯ', 'Привет', '한국어']) texts.push(word);
// Random strings from the whole pool, then from the classes that interact: letters beside marks, and sigma beside letters.
while (texts.length < 1400) {
  const length = 1 + Math.floor(next() * 9);
  texts.push(Array.from({ length }, () => String.fromCodePoint(pick(pool))).join(''));
}
const interacting = [...classes.greek, ...classes.ascii.slice(0, 6), ...classes.marks, ...classes.space.slice(0, 4), 0x27, 0x2e, 0x2c];
while (texts.length < 2100) {
  const length = 1 + Math.floor(next() * 7);
  texts.push(Array.from({ length }, () => String.fromCodePoint(pick(interacting))).join(''));
}

// ASCII only, so the file reads the same in every editor: every other character is a \u escape.
const escape = (text) => JSON.stringify(text).replace(/[^\x20-\x7e]/g, (c) => '\\u' + c.charCodeAt(0).toString(16).padStart(4, '0'));
console.log('[\n' + texts.map((text) => `  [${escape(text)}, ${escape(fold(text))}]`).join(',\n') + '\n]');
