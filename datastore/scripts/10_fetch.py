#!/usr/bin/env python3
"""Fetch the tarkov.dev reference/localization endpoints that offlinedata lacks.

The saved `offlinedata/tarkovdev/*.json` dumps carry no display strings:
every `name` is a `<bsgId> Name` placeholder and every `translations` array is
empty. The live API exposes separate `*_en` localization endpoints plus the
`maps` and `hideout` reference datasets. This script caches them under
`fetched/` with a manifest so the build is reproducible offline.

Idempotent: existing files are reused. Pass --refresh to re-download.

Run: ~/.pyvenv-tarkov/bin/python datastore/scripts/10_fetch.py [--refresh]
"""
from __future__ import annotations

import hashlib
import json
import os
import sys
import urllib.request
from datetime import datetime, timezone

BASE = "https://json.tarkov.dev/regular"
ENDPOINTS = [
    "items_en",     # <id> Name / ShortName / Description + slot/zone names
    "tasks_en",      # <id> name / description
    "traders_en",    # <id> Nickname / Description
    "maps_en",       # <id> Name
    "maps",          # map entities: extracts, transits, bosses, raid duration
    "hideout",       # hideout stations + levels + build requirements
    "hideout_en",    # hideout_area_N_name -> display name
]

HERE = os.path.dirname(os.path.abspath(__file__))
DS = os.path.abspath(os.path.join(HERE, ".."))
OUT = os.path.join(DS, "fetched")
MANIFEST = os.path.join(OUT, "manifest.json")


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def main():
    refresh = "--refresh" in sys.argv
    os.makedirs(OUT, exist_ok=True)
    manifest = {}
    if os.path.exists(MANIFEST):
        with open(MANIFEST, encoding="utf-8") as fh:
            manifest = json.load(fh)

    for name in ENDPOINTS:
        path = os.path.join(OUT, f"{name}.json")
        if os.path.exists(path) and not refresh:
            print(f"  reuse  {name}")
            continue
        url = f"{BASE}/{name}"
        try:
            with urllib.request.urlopen(url, timeout=60) as resp:
                raw = resp.read()
        except Exception as exc:  # noqa: BLE001 - a failed fetch must be loud
            print(f"  FAIL   {name}  {type(exc).__name__}: {exc}", file=sys.stderr)
            if os.path.exists(path):
                print(f"         keeping existing {path}", file=sys.stderr)
                continue
            raise SystemExit(f"cannot fetch {url} and no cached copy exists")
        with open(path, "wb") as fh:
            fh.write(raw)
        print(f"  fetch  {name}  {len(raw)} bytes")
        manifest[name] = {
            "url": url,
            "bytes": len(raw),
            "sha256": sha256(path),
            "fetched_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        }

    # backfill entries for files that predate the manifest (stamped today:
    # they were downloaded during this session, just before the manifest existed)
    stamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    for name in ENDPOINTS:
        path = os.path.join(OUT, f"{name}.json")
        if name not in manifest and os.path.exists(path):
            manifest[name] = {"url": f"{BASE}/{name}", "bytes": os.path.getsize(path),
                              "sha256": sha256(path), "fetched_at": stamp}

    with open(MANIFEST, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2, sort_keys=True)
    print(f"\nmanifest -> {MANIFEST} ({len(manifest)} endpoints)")


if __name__ == "__main__":
    main()
