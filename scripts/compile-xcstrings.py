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
    by_lang = {}

    for key, item in strings.items():
        localizations = item.get("localizations", {})
        if source_lang not in by_lang:
            by_lang[source_lang] = {}
        by_lang[source_lang][key] = key

        for lang, loc in localizations.items():
            if lang not in by_lang:
                by_lang[lang] = {}
            val = None
            if "stringUnit" in loc and "value" in loc["stringUnit"]:
                val = loc["stringUnit"]["value"]
            if val is not None:
                by_lang[lang][key] = val

    for lang, trans_dict in by_lang.items():
        if lang != "en":
            continue
        lproj = os.path.join(out_dir, f"{lang}.lproj")
        os.makedirs(lproj, exist_ok=True)
        strings_file = os.path.join(lproj, "Localizable.strings")
        with open(strings_file, "w", encoding="utf-8") as out:
            for k, v in trans_dict.items():
                out.write(f"\"{escape_str(k)}\" = \"{escape_str(v)}\";\n")

    print(f"Compiled English localization from {os.path.basename(xcstrings_path)} into {out_dir}")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: compile-xcstrings.py <path-to-xcstrings> <out-resources-dir>")
        sys.exit(1)
    compile_xcstrings(sys.argv[1], sys.argv[2])
