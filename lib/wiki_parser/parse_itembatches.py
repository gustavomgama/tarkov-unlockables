#!/usr/bin/env python3
"""Parse officialwiki itembatches into parsed_items.json.

Input:  offlinedata/officialwiki/itembatches/wiki_batch_*.json
        (query.pages[].revisions[0].slots.main.content, contentmodel wikitext)
Output: offlinedata/officialwiki/parsed_items.json
        { bsg_id: { "full_name": ..., "infobox": {...}, "sections": { "mods": [...], "weapon_variants": [...] } } }

Rules (per plan Task 6):
- mwparserfromhell for ALL template/wikilink extraction; regex ONLY for
  tabber/table internals and 24-hex ids ([0-9a-f]{24}).
- `node` param -> bsg_id key (first 24-hex id only); pages without an
  infobox or without a hex node are skipped.
- Values cleaned: units stripped ("0.01 kg" -> "0.01", "838 m/s" -> "838"),
  HTML font tags removed, plain [[link]]/{{template}} wrappers unwrapped,
  interwiki [[fr:...]]/[[ru:...]]/[[Category:...]]/{{Navbox...}} filtered.
- Infobox param names normalized to snake_case (def ammo -> def_ammo,
  default plates -> default_plates, max uses -> max_uses, Weaprecoil -> recoil).
"""

import argparse
import glob
import json
import os
import re

import mwparserfromhell

HEX24 = re.compile(r"[0-9a-f]{24}")

# Units stripped from trailing position of a value ("0.01 kg" -> "0.01").
UNITS = {
    "kg", "g", "m/s", "m", "mm", "cm", "km", "in", "lb", "oz", "%",
    "s", "hz", "meters", "px", "slots",
}

INTERWIKI_PREFIXES = (
    "fr:", "ru:", "de:", "zh:", "cs:", "es:", "it:", "ja:", "ko:",
    "pl:", "pt:", "tr:", "uk:", "vi:", "nl:", "sv:", "fi:", "hu:",
)


def first_hex(value):
    """First 24-hex id in a string, or None."""
    match = HEX24.search(value or "")
    return match.group(0) if match else None


def strip_units(value):
    """'0.01 kg' -> '0.01', '838 m/s' -> '838'; otherwise unchanged."""
    parts = value.split()
    if len(parts) == 2 and parts[1] in UNITS:
        try:
            float(parts[0])
            return parts[0]
        except ValueError:
            pass
    return value


def strip_font_tags(value):
    """Remove <font ...>...</font> wrappers, keeping inner content."""
    code = mwparserfromhell.parse(value)
    tags = list(code.filter_tags(recursive=True))
    for tag in tags:
        if tag.tag.lower() == "font":
            code.replace(tag, tag.contents)
    return str(code)


def clean_wikilink(link):
    """Unwrap a plain [[link]]; filter interwiki and Category links."""
    target = str(link.title).strip()
    lowered = target.lower()
    if lowered.startswith("category:") or lowered.startswith(INTERWIKI_PREFIXES):
        return ""
    if link.text is not None:
        return str(link.text).strip()
    return target


def clean_template(template):
    """Unwrap a plain {{template}}; filter Navbox templates."""
    name = str(template.name).strip()
    if name.lower().startswith("navbox"):
        return ""
    return name


def clean_value(value):
    """Clean a single infobox param value."""
    value = value.strip()
    if not value:
        return ""
    code = mwparserfromhell.parse(value)
    nodes = [n for n in code.nodes if not (isinstance(n, mwparserfromhell.nodes.Text) and not str(n).strip())]
    if len(nodes) == 1:
        node = nodes[0]
        if isinstance(node, mwparserfromhell.nodes.Wikilink):
            return clean_wikilink(node)
        if isinstance(node, mwparserfromhell.nodes.Template):
            return clean_template(node)
    text = strip_font_tags(value)
    return strip_units(text).strip()


def normalize_param_name(name):
    """'Weaprecoil' -> 'recoil'; spaces -> underscores (def ammo -> def_ammo)."""
    name = name.strip()
    if name == "Weaprecoil":
        return "recoil"
    return name.replace(" ", "_")


def extract_infobox(code):
    """First {{Infobox ...}} template, or None."""
    for template in code.filter_templates():
        if template.name.strip().lower().startswith("infobox"):
            return template
    return None


def infobox_params(infobox):
    """All infobox params -> {normalized_name: cleaned_value}; empties dropped."""
    params = {}
    for param in infobox.params:
        name = normalize_param_name(param.name)
        if name.isdigit():
            continue  # malformed unnamed param (e.g. stray icon line)
        value = clean_value(param.value)
        if value:
            params[name] = value
    return params


def parse_mods(content):
    """==Mods== <tabber> -> [{slot, items: [hex ids]}]."""
    section = re.search(r"==\s*Mods\s*==\n(.*?)(?=\n==|\Z)", content, re.S)
    if not section:
        return []
    tabber = re.search(r"<tabber>(.*?)</tabber>", section.group(1), re.S)
    if not tabber:
        return []
    mods = []
    for chunk in re.split(r"\|-\|", tabber.group(1)):
        lines = [line for line in chunk.split("\n") if line.strip()]
        if not lines:
            continue
        slot = lines[0].split("=", 1)[0].strip()
        if not slot:
            continue
        body = "\n".join(lines[1:])
        mods.append({"slot": slot, "items": HEX24.findall(body)})
    return mods


def parse_weapon_variants(content):
    """==Weapon variants== wikitable -> [{name, attachments: [hex ids]}]."""
    section = re.search(r"==\s*Weapon variants\s*==\n(.*?)(?=\n==|\Z)", content, re.S)
    if not section:
        return []
    table = re.search(r"\{\|(.*?)\|\}", section.group(1), re.S)
    if not table:
        return []
    variants = []
    for row in re.split(r"\n\|-", table.group(1)):
        row = row.strip()
        if not row:
            continue
        raw_cells = re.split(r"\n[|!]", row)
        if not raw_cells or not raw_cells[0].lstrip().startswith(("|", "!")):
            continue  # table attributes line
        if len(raw_cells) > 1 and raw_cells[1].lstrip().startswith("!"):
            continue  # header row (!Image / !Weapon Variant / !Attachments)
        cells = [cell.lstrip("|!").strip() for cell in raw_cells]
        if len(cells) < 2:
            continue
        name = clean_value(cells[1])
        if not name:
            continue
        attachments = HEX24.findall(cells[2]) if len(cells) > 2 else []
        variants.append({"name": name, "attachments": attachments})
    return variants


def parse_page(title, content):
    """One page -> {bsg_id, full_name, infobox, sections} or None (skip)."""
    code = mwparserfromhell.parse(content)
    infobox = extract_infobox(code)
    if infobox is None:
        return None  # stub page without infobox
    params = infobox_params(infobox)
    node = params.get("node")
    if not node:
        return None  # no node param
    bsg_id = first_hex(node)
    if not bsg_id:
        return None  # node without a 24-hex id
    params["node"] = bsg_id
    return {
        "bsg_id": bsg_id,
        "full_name": title,
        "infobox": params,
        "sections": {
            "mods": parse_mods(content),
            "weapon_variants": parse_weapon_variants(content),
        },
    }


def parse_batch_file(path):
    """One wiki_batch_*.json -> {bsg_id: parsed}."""
    with open(path) as f:
        data = json.load(f)
    results = {}
    for page in data.get("query", {}).get("pages", []):
        revisions = page.get("revisions") or []
        if not revisions:
            continue
        content = revisions[0].get("slots", {}).get("main", {}).get("content", "")
        parsed = parse_page(page.get("title", ""), content)
        if parsed:
            results[parsed.pop("bsg_id")] = parsed
    return results


def parse_all(input_dir):
    """All wiki_batch_*.json in input_dir -> {bsg_id: parsed}."""
    results = {}
    for path in sorted(glob.glob(os.path.join(input_dir, "wiki_batch_*.json"))):
        results.update(parse_batch_file(path))
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", default="offlinedata/officialwiki/itembatches")
    parser.add_argument("--output", default="offlinedata/officialwiki/parsed_items.json")
    args = parser.parse_args()

    results = parse_all(args.input)
    with open(args.output, "w") as f:
        json.dump(results, f, indent=2, ensure_ascii=False)
    print("parsed %d items -> %s" % (len(results), args.output))


if __name__ == "__main__":
    main()