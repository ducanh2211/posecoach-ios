#!/usr/bin/env python3
"""
Convert Android strings.xml and values-vi/strings.xml into Apple String Catalog (Localizable.xcstrings).

Usage:
    python3 tools/strings-xml-to-xcstrings/convert.py
"""

import os
import re
import sys
import json
import xml.etree.ElementTree as ET

def clean_android_text(text: str) -> str:
    if text is None:
        return ""
    # Android unescapes \' to ' and \" to "
    text = text.replace(r"\'", "'").replace(r'\"', '"')
    # Replace format specifiers:
    # %1$s -> %1$@, %s -> %@
    # %1$d -> %1$lld, %d -> %lld
    text = re.sub(r'%([0-9]+\$)?s', r'%\1@', text)
    text = re.sub(r'%([0-9]+\$)?d', r'%\1lld', text)
    return text

def parse_xml(file_path: str):
    tree = ET.parse(file_path)
    root = tree.getroot()
    strings = {}
    plurals = {}

    for elem in root:
        if elem.tag == 'string':
            name = elem.attrib.get('name')
            # Text might contain child tags or plain text
            full_text = "".join(elem.itertext())
            strings[name] = clean_android_text(full_text)
        elif elem.tag == 'plurals':
            name = elem.attrib.get('name')
            items = {}
            for item in elem.findall('item'):
                qty = item.attrib.get('quantity')
                item_text = "".join(item.itertext())
                items[qty] = clean_android_text(item_text)
            plurals[name] = items

    return strings, plurals

def main():
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '../..'))
    en_path = os.path.join(repo_root, 'shared/posecoach/app/app/src/main/res/values/strings.xml')
    vi_path = os.path.join(repo_root, 'shared/posecoach/app/app/src/main/res/values-vi/strings.xml')
    output_path = os.path.join(repo_root, 'PoseCoach/PoseCoach/Resources/Localizable.xcstrings')

    if not os.path.exists(en_path) or not os.path.exists(vi_path):
        print(f"Error: Missing Android strings files:\n  {en_path}\n  {vi_path}", file=sys.stderr)
        sys.exit(1)

    en_strings, en_plurals = parse_xml(en_path)
    vi_strings, vi_plurals = parse_xml(vi_path)

    all_string_keys = sorted(set(en_strings.keys()) | set(vi_strings.keys()))
    all_plural_keys = sorted(set(en_plurals.keys()) | set(vi_plurals.keys()))

    print(f"Found {len(all_string_keys)} strings and {len(all_plural_keys)} plurals.")

    catalog_strings = {}

    for key in all_string_keys:
        entry = {
            "extractionState": "manual",
            "localizations": {}
        }
        if key in en_strings:
            entry["localizations"]["en"] = {
                "stringUnit": {
                    "state": "translated",
                    "value": en_strings[key]
                }
            }
        if key in vi_strings:
            entry["localizations"]["vi"] = {
                "stringUnit": {
                    "state": "translated",
                    "value": vi_strings[key]
                }
            }
        catalog_strings[key] = entry

    for key in all_plural_keys:
        entry = {
            "extractionState": "manual",
            "localizations": {}
        }
        if key in en_plurals:
            variations = {"plural": {}}
            for qty, val in en_plurals[key].items():
                variations["plural"][qty] = {
                    "stringUnit": {
                        "state": "translated",
                        "value": val
                    }
                }
            entry["localizations"]["en"] = {"variations": variations}

        if key in vi_plurals:
            variations = {"plural": {}}
            for qty, val in vi_plurals[key].items():
                variations["plural"][qty] = {
                    "stringUnit": {
                        "state": "translated",
                        "value": val
                    }
                }
            entry["localizations"]["vi"] = {"variations": variations}

        catalog_strings[key] = entry

    catalog = {
        "sourceLanguage": "en",
        "strings": catalog_strings,
        "version": "1.0"
    }

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(catalog, f, ensure_ascii=False, indent=2)

    print(f"Generated String Catalog at: {output_path}")

if __name__ == '__main__':
    main()
