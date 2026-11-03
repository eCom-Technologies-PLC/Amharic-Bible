"""The app's search normalization (app/lib/core/geez.dart with unicode_data.dart)
agrees with Python's unicodedata, which the pipeline normalizes the search
index with. normalize_vectors.json checks both on examples; this checks the
data for every character."""
import re
import sys
import unicodedata
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import build_dart_unicode  # noqa: E402
from abible.geez import CHAR_MAP  # noqa: E402


def dart_table() -> dict[int, str]:
    text = build_dart_unicode.OUT.read_text(encoding='utf-8')
    body = text.split('const decompositionTable =', 1)[1]
    return build_dart_unicode.decode(''.join(re.findall(r"'([0-9A-F.]*)'", body)))


def is_punct_or_symbol(ch: str) -> bool:
    return unicodedata.category(ch)[0] in 'PS'


class DartUnicodeTest(unittest.TestCase):
    def test_every_character_decomposes_in_the_app_as_here(self):
        dart = dart_table()
        here = build_dart_unicode.decompositions()
        for cp, want in here.items():
            self.assertEqual(dart.get(cp), want, f'U+{cp:04X}')
        # The table may come from a newer Unicode than this Python's (canonical
        # decompositions never change once assigned): characters this Python
        # doesn't know yet are the only extra ones.
        for cp in dart.keys() - here.keys():
            self.assertEqual(unicodedata.category(chr(cp)), 'Cn', f'U+{cp:04X} decomposes only in the app')

    def test_composing_first_cannot_change_what_normalize_gives(self):
        # geez.py composes the text (NFC) before mapping spelling variants and
        # removing punctuation; geez.dart doesn't. That is safe while composing
        # never makes or breaks a character of the variant map, and never turns
        # a letter into punctuation or a symbol, or the reverse.
        variants = {k if isinstance(k, int) else ord(k) for k in CHAR_MAP}
        for cp in range(0x110000):
            ch = chr(cp)
            if 0xD800 <= cp <= 0xDFFF:
                continue
            composed = unicodedata.normalize('NFC', ch)
            if composed != ch:  # a character NFC replaces (singletons and the like)
                self.assertNotIn(cp, variants, f'U+{cp:04X}')
                self.assertFalse(variants & {ord(c) for c in composed}, f'U+{cp:04X}')
                self.assertEqual(is_punct_or_symbol(ch), is_punct_or_symbol(composed[0]), f'U+{cp:04X}')
            parts = unicodedata.decomposition(ch).split()
            if len(parts) == 2 and not parts[0].startswith('<'):
                first, second = (chr(int(p, 16)) for p in parts)
                if unicodedata.normalize('NFC', first + second) == ch:  # a pair NFC joins into [ch]
                    self.assertNotIn(ord(first), variants, f'U+{cp:04X}')
                    self.assertNotIn(cp, variants, f'U+{cp:04X}')
                    self.assertEqual(is_punct_or_symbol(first), is_punct_or_symbol(ch), f'U+{cp:04X}')


if __name__ == '__main__':
    unittest.main()
