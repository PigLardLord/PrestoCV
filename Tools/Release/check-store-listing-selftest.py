#!/usr/bin/env python3
"""Self-test of check-store-listing.py: the screenshot captions are what the composer pairs with the six captures.

    Tools/Release/check-store-listing-selftest.py

The composer puts the first caption of a locale on the first capture, the second on the second, and so on: a locale with
fewer captions than captures would leave the captions over the wrong screens, and one with more would have no capture
for them. So a locale needs exactly six captions, and the checker says so.

The retired words (store-listing-retired-words.json) are the claims check: a text of the 1.1 listing must not name a
feature the app lacks, in the language of its locale.
"""
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.dont_write_bytecode = True  # importing the checker must leave no __pycache__ in the repository
spec = importlib.util.spec_from_file_location("check_store_listing", HERE / "check-store-listing.py")
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)

LOCALE = "en-US"


def listing():
    """The locales and the notes of the real listing"""
    return checker.parse(checker.DOC.read_text(encoding="utf-8").split("\n"))


def with_captions(captions):
    """The real listing with the captions of one locale replaced"""
    locales, notes = listing()
    locales[LOCALE]["Screenshot captions"] = ["\n".join(captions)]
    return locales, notes


def caption_errors(captions):
    return [e for e in checker.check(*with_captions(captions)) if "caption" in e.lower()]


class CaptionCount(unittest.TestCase):
    def setUp(self):
        locales, _ = listing()
        self.captions = locales[LOCALE]["Screenshot captions"][0].split("\n")

    def test_the_listing_has_six_captions_in_every_locale(self):
        locales, notes = listing()
        self.assertEqual(checker.check(locales, notes), [])
        for locale, fields in locales.items():
            self.assertEqual(len(fields["Screenshot captions"][0].split("\n")), 6, locale)

    def test_five_captions_are_refused(self):
        errors = caption_errors(self.captions[:5])
        self.assertTrue(any(LOCALE in e and "exactly 6" in e for e in errors), errors)

    def test_seven_captions_are_refused(self):
        errors = caption_errors(self.captions + ["One more. | A seventh caption, with no capture."])
        self.assertTrue(any(LOCALE in e and "exactly 6" in e for e in errors), errors)

    def test_an_empty_line_is_refused(self):
        errors = caption_errors(self.captions[:5] + [""])
        self.assertTrue(errors, errors)

    def test_six_captions_are_accepted(self):
        self.assertEqual(caption_errors(self.captions), [])


LANGUAGES = {"en-US": "en", "de-DE": "de", "it": "it", "es-ES": "es", "fr-FR": "fr", "pt-PT": "pt"}
# For each language: a sentence that claims the retired AI draft, as the 1.0 listing did
AI_CLAIMS = {
    "en-US": "Draft it with AI on your iPhone.",
    "de-DE": "Mit KI entwerfen, direkt auf dem iPhone.",
    "it": "Scrivilo con l'IA sul tuo iPhone.",
    "es-ES": "Redáctalo con IA en tu iPhone.",
    "fr-FR": "Rédigez avec l'IA sur votre iPhone.",
    "pt-PT": "Escreva com IA no seu iPhone.",
}


def retired_errors(locale, field, text):
    """The retired-word errors that `text` adds to the field of a locale of the real listing"""
    entries, _ = checker.load_retired()
    locales, notes = listing()
    before = Counter(checker.check_retired(locales, notes, entries, set()))
    locales[locale][field] = [locales[locale][field][0] + "\n" + text]
    return list((Counter(checker.check_retired(locales, notes, entries, set())) - before).elements())


class RetiredWords(unittest.TestCase):
    def test_the_listing_names_no_retired_feature(self):
        self.assertEqual(checker.check(*listing()), [])

    def test_every_entry_has_a_reason_and_a_language(self):
        entries, pending = checker.load_retired()
        for entry in entries:
            self.assertTrue(entry["reason"].strip(), entry["pattern"])
            self.assertTrue(set(entry["languages"]) <= {"*", "en", "de", "it", "es", "fr", "pt"}, entry["pattern"])
            self.assertTrue(set(entry.get("allowedIn", [])) <= set(checker.FIELDS), entry["pattern"])
            self.assertTrue(set(entry.get("onlyIn", checker.FIELDS)) <= set(checker.FIELDS), entry["pattern"])
        self.assertTrue(set(pending) <= set(listing()[0]) | {"notes"}, pending)

    def test_the_ai_draft_is_refused_in_every_language(self):
        for locale, claim in AI_CLAIMS.items():
            with self.subTest(locale):
                self.assertTrue(retired_errors(locale, "Description", claim), claim)

    def test_the_other_retired_features_are_refused(self):
        claims = ["Apple Intelligence writes it", "an on-device model", "Import from LinkedIn", "Scan your CV",
                  "Also on the Mac", "also for macOS"]
        for claim in claims:
            with self.subTest(claim):
                self.assertTrue(retired_errors("en-US", "Description", claim), claim)

    def test_the_usual_variants_are_refused(self):
        variants = {
            "en-US": ["ai-powered CVs", "Written by A.I.", "Drafted for you", "Keep drafting", "Apple-Intelligence",
                      "an on device model", "Import from Linked-In", "On all your Macs"],
            "de-DE": ["Mit K.I.", "ki-gestützt", "Drei Entwürfe", "Das On-Device-Modell schreibt"],
            "it": ["Una Bozza pronta", "Con l'I.A.", "Con la ia generativa"],
            "es-ES": ["Con I.A.", "Borrador listo"],
            "fr-FR": ["Brouillon prêt"],
            "pt-PT": ["Com IA", "Rascunho pronto"],
        }
        for locale, texts in variants.items():
            for text in texts:
                with self.subTest(locale=locale, text=text):
                    self.assertTrue(retired_errors(locale, "Description", text), text)
        self.assertTrue(retired_errors("pt-PT", "Keywords", "ia"))

    def test_a_scan_is_refused_in_its_forms(self):
        for locale, text in [("en-US", "Scan your CV"), ("en-US", "a scanned page"), ("en-US", "scanning made easy"),
                             ("de-DE", "eingescannt"), ("de-DE", "Sie können Ihren Lebenslauf einscannen"),
                             ("de-DE", "um ihn einzuscannen"), ("de-DE", "abscannen"), ("de-DE", "der Dokumentenscanner"),
                             ("de-DE", "ein Dokumentenscan"), ("de-DE", "Scan-Funktion"),
                             ("it", "scansiona il CV"), ("es-ES", "escanea tu CV"), ("fr-FR", "numérisez le CV")]:
            with self.subTest(locale=locale, text=text):
                self.assertTrue(retired_errors(locale, "Description", text), text)

    def test_words_that_only_look_like_a_retired_one_pass(self):
        self.assertEqual(retired_errors("en-US", "Description", "Scandinavian roles, all linked in one place."), [])
        self.assertEqual(retired_errors("en-US", "Description", "Tuscany and the Tuscans."), [])
        self.assertEqual(retired_errors("pt-PT", "Description", "Eu ia ao trabalho."), [])
        self.assertEqual(retired_errors("it", "Description", "Ai colleghi piace."), [])

    def test_a_caption_and_the_keywords_are_checked_too(self):
        self.assertTrue(retired_errors("de-DE", "Screenshot captions", "Apple Intelligence | Ein Entwurf"))
        self.assertTrue(retired_errors("en-US", "Keywords", "linkedin"))

    def test_whats_new_may_say_the_ai_draft_is_gone(self):
        self.assertEqual(retired_errors("en-US", "What's New", "The AI draft of version 1.0 is gone."), [])
        self.assertTrue(retired_errors("en-US", "What's New", "Now with Apple Intelligence."))

    def test_the_notes_for_app_review_are_checked_in_english(self):
        locales, notes = listing()
        entries, _ = checker.load_retired()
        errors = checker.check_retired(locales, notes + "\nTap Draft My CV with AI.", entries, set())
        self.assertTrue(any(e.startswith("notes ") for e in errors), errors)

    def test_ordinary_words_are_not_retired(self):
        text = "Mach dein CV in Italia: mail, main, machine, scale, Macedonia, bozzetto, Entwicklung and a tablet."
        for locale in ("en-US", "de-DE", "it"):
            with self.subTest(locale):
                self.assertEqual(retired_errors(locale, "Description", text), [])

    def test_a_pending_locale_that_passes_must_leave_the_baseline(self):
        entries, _ = checker.load_retired()
        errors = checker.check_retired({"en-US": {"Description": ["A plain CV maker."]}}, "Plain notes.", entries,
                                       {"en-US"})
        self.assertTrue(any("remove it from pendingLocales" in e and "en-US" in e for e in errors), errors)

    def test_a_pending_locale_that_fails_is_not_reported(self):
        entries, _ = checker.load_retired()
        errors = checker.check_retired({"en-US": {"Description": ["Draft it with AI."]}}, "Plain notes.", entries,
                                       {"en-US"})
        self.assertEqual(errors, [])

    def test_a_pending_name_that_is_no_locale_is_refused(self):
        entries, _ = checker.load_retired()
        errors = checker.check_retired({"en-US": {"Description": ["Plain."]}}, "Plain.", entries, {"xx"})
        self.assertTrue(any("'xx' is not a locale" in e for e in errors), errors)


class PendingAgainstTheTargetBranch(unittest.TestCase):
    def test_a_grown_list_is_refused(self):
        errors = checker.check_pending_against(["es-ES", "fr-FR"], ["es-ES"])
        self.assertTrue(any("grew" in e and "fr-FR" in e for e in errors), errors)

    def test_an_equal_or_shorter_list_passes(self):
        self.assertEqual(checker.check_pending_against(["es-ES"], ["es-ES"]), [])
        self.assertEqual(checker.check_pending_against([], ["es-ES", "fr-FR"]), [])

    def test_the_command_line_compares_with_the_file_it_is_given(self):
        _, pending = checker.load_retired()
        with tempfile.TemporaryDirectory() as folder:
            shorter, same = Path(folder) / "shorter.json", Path(folder) / "same.json"
            shorter.write_text(json.dumps({"pendingLocales": pending[1:]}), encoding="utf-8")
            same.write_text(json.dumps({"pendingLocales": pending}), encoding="utf-8")
            command = [sys.executable, "-I", str(HERE / "check-store-listing.py"), "--against"]
            refused = subprocess.run(command + [str(shorter)], capture_output=True, text=True)
            passed = subprocess.run(command + [str(same)], capture_output=True, text=True)
        self.assertEqual(refused.returncode, 1, refused.stderr)
        self.assertIn(pending[0], refused.stderr)
        self.assertEqual(passed.returncode, 0, passed.stderr)


if __name__ == "__main__":
    unittest.main(argv=[sys.argv[0], "-v"] if len(sys.argv) == 1 else sys.argv)
