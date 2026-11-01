#!/usr/bin/env python3
"""Prints every localizable string the Swift compiler extracted during the build.

Xcode writes one .stringsdata file per compiled Swift file (SWIFT_EMIT_LOC_STRINGS = YES). Each holds the exact
String Catalog keys (with %lld / %@ placeholders already worked out) and translator comments. This script merges
them and prints one JSON object per line, prefixed with LOCKEY, so the keys can be read from the CI log and used
to keep Localizable.xcstrings complete.

Usage: dump-strings.py <DerivedData path>
"""
import json
import pathlib
import sys


def target_for(path: pathlib.Path) -> str:
    text = str(path)
    if "UnhookWidgets.build" in text:
        return "widgets"
    if "UnhookTests.build" in text:
        return "tests"
    return "app"


def main() -> int:
    root = pathlib.Path(sys.argv[1])
    files = sorted(root.rglob("*.stringsdata"))
    entries: dict[tuple[str, str, str], set[str]] = {}
    unreadable = 0
    for path in files:
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, ValueError) as error:
            unreadable += 1
            print(f"UNREADABLE {path}: {error}")
            continue
        for table, items in (data.get("tables") or {}).items():
            for item in items:
                key = item.get("key")
                if key is None:
                    continue
                comments = entries.setdefault((target_for(path), table, key), set())
                if item.get("comment"):
                    comments.add(item["comment"])

    print(f"STRINGSDATA-FILES {len(files)} UNREADABLE {unreadable} STRINGS {len(entries)}")
    if not entries and files:
        # Unknown format: show a sample so the parser can be fixed.
        print("SAMPLE " + files[0].read_text(encoding="utf-8")[:3000])
    for (target, table, key), comments in sorted(entries.items()):
        record = {"target": target, "table": table, "key": key, "comments": sorted(comments)}
        print("LOCKEY\t" + json.dumps(record, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
