#!/usr/bin/env python3
"""Self-test of check-store-listing.py: the screenshot captions are what the composer pairs with the six captures.

    Tools/Release/check-store-listing-selftest.py

The composer puts the first caption of a locale on the first capture, the second on the second, and so on: a locale with
fewer captions than captures would leave the captions over the wrong screens, and one with more would have no capture
for them. So a locale needs exactly six captions, and the checker says so.
"""
import importlib.util
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
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


if __name__ == "__main__":
    unittest.main(argv=[sys.argv[0], "-v"] if len(sys.argv) == 1 else sys.argv)
