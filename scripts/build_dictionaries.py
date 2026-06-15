#!/usr/bin/env python3
"""Build clean en.txt / ru.txt wordlists for KeyboardSwitcher.

Input: any plain-text wordlists (one word per line, any encoding).

  ./build_dictionaries.py --en SCOWL.txt --ru OpenCorpora.txt

Output is written to Sources/KeyboardSwitcher/Resources/{en,ru}.txt.

Suggested sources (all open):
  English  — SCOWL                 http://app.aspell.net/create
  Russian  — OpenCorpora wordforms https://opencorpora.org/?page=downloads
             or hunspell-ru        https://github.com/LibreOffice/dictionaries
"""

import argparse
import os
import re
import sys

EN_RE = re.compile(r"^[a-z][a-z']{2,30}$")
RU_RE = re.compile(r"^[а-яё][а-яё\-]{2,30}$")
UA_RE = re.compile(r"^[а-яіїєґё][а-яіїєґё\-']{2,30}$")

DEFAULT_OUT = os.path.join(
    os.path.dirname(__file__), "..", "Sources", "KeyboardSwitcher", "Resources"
)


def load(path: str, regex: re.Pattern) -> set[str]:
    words: set[str] = set()
    with open(path, encoding="utf-8", errors="replace") as f:
        for raw in f:
            w = raw.strip().lower()
            if "/" in w:  # hunspell affix marker
                w = w.split("/", 1)[0]
            if not w:
                continue
            if regex.match(w):
                words.add(w)
    return words


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--en", required=False, help="path to English wordlist")
    p.add_argument("--ru", required=False, help="path to Russian wordlist")
    p.add_argument("--ua", required=False, help="path to Ukrainian wordlist")
    p.add_argument("--out", default=DEFAULT_OUT, help="output directory")
    p.add_argument(
        "--min-frequency",
        type=int,
        default=0,
        help="if input is 'word\\tcount', drop words below this count",
    )
    args = p.parse_args()

    os.makedirs(args.out, exist_ok=True)

    if not args.en and not args.ru and not args.ua:
        p.error("provide at least one of --en / --ru / --ua")

    if args.en:
        words = load(args.en, EN_RE)
        out = os.path.join(args.out, "en.txt")
        with open(out, "w", encoding="utf-8") as f:
            for w in sorted(words):
                f.write(w + "\n")
        print(f"wrote {len(words):,} en words to {out}")

    if args.ru:
        words = load(args.ru, RU_RE)
        out = os.path.join(args.out, "ru.txt")
        with open(out, "w", encoding="utf-8") as f:
            for w in sorted(words):
                f.write(w + "\n")
        print(f"wrote {len(words):,} ru words to {out}")

    if args.ua:
        words = load(args.ua, UA_RE)
        out = os.path.join(args.out, "ua.txt")
        with open(out, "w", encoding="utf-8") as f:
            for w in sorted(words):
                f.write(w + "\n")
        print(f"wrote {len(words):,} ua words to {out}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
