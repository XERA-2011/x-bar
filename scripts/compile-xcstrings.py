#!/usr/bin/env python3
import json
import os
import sys

def escape_str(s):
    return s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r")

def compile_xcstrings(xcstrings_path, out_dir):
    if not os.path.exists(xcstrings_path):
        print(f"Warning: {xcstrings_path} not found")
        return

    with open(xcstrings_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    strings = data.get("strings", {})
    source_lang = data.get("sourceLanguage", "en")
    en_strings = {}
    for key, item in strings.items():
        loc_en = item.get("localizations", {}).get("en", {})
        val = loc_en.get("stringUnit", {}).get("value") if isinstance(loc_en, dict) else None
        en_strings[key] = val if val is not None else key

    lproj = os.path.join(out_dir, "en.lproj")
    os.makedirs(lproj, exist_ok=True)
    strings_file = os.path.join(lproj, "Localizable.strings")
    with open(strings_file, "w", encoding="utf-8") as out:
        for k, v in sorted(en_strings.items()):
            out.write(f"\"{escape_str(k)}\" = \"{escape_str(v)}\";\n")

    print(f"Compiled English localization ({len(en_strings)} keys) into {lproj}")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: compile-xcstrings.py <path-to-xcstrings> <out-resources-dir>")
        sys.exit(1)
    compile_xcstrings(sys.argv[1], sys.argv[2])
