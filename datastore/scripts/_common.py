#!/usr/bin/env python3
"""Shared helpers for the datastore pipeline.

Paths, JSON loading, id/slug utilities and display-name resolution. Kept tiny
on purpose: it exists so 20_build_canonical.py, 30_build_sqlite.py and
99_verify.py agree on where things live and how names resolve.
"""
from __future__ import annotations

import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
DS = os.path.abspath(os.path.join(HERE, ".."))          # datastore/
REPO = os.path.abspath(os.path.join(DS, ".."))          # repo root
OFF = os.path.join(REPO, "offlinedata")
FETCHED = os.path.join(DS, "fetched")
CANON = os.path.join(DS, "canonical")
REPORTS = os.path.join(DS, "reports")
SQLITE = os.path.join(DS, "tarkov.sqlite3")


def load_off(rel):
    with open(os.path.join(OFF, rel), encoding="utf-8") as fh:
        return json.load(fh)


def load_fetched(name):
    with open(os.path.join(FETCHED, f"{name}.json"), encoding="utf-8") as fh:
        return json.load(fh)


def slugify(text):
    """Human text -> ascii slug. Used only as a last-resort fallback."""
    s = (text or "").lower()
    s = s.replace("'", "").replace("\u2019", "")
    s = re.sub(r"[^a-z0-9]+", "-", s)
    return s.strip("-")


def humanize(slug):
    """Slug or wiki-page segment -> roughly display text."""
    s = re.sub(r"[_\-]+", " ", slug or "").strip()
    return s[:1].upper() + s[1:] if s else s


def wiki_title_name(link):
    """Last segment of a fandom wiki URL -> display text."""
    if not link:
        return None
    seg = link.rstrip("/").rsplit("/", 1)[-1]
    return humanize(seg)


def load_jsonl(path):
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if line:
                yield json.loads(line)


def write_jsonl(path, rows):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    n = 0
    with open(path, "w", encoding="utf-8") as fh:
        for row in rows:
            fh.write(json.dumps(row, ensure_ascii=False, sort_keys=False) + "\n")
            n += 1
    return n
