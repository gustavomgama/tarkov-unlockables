#!/usr/bin/env bash
# Full datastore pipeline in order. Exits non-zero on the first failure.
# Usage: datastore/scripts/run.sh [--refresh]
set -euo pipefail

cd "$(dirname "$0")"
PY="${PY:-$HOME/.pyvenv-tarkov/bin/python}"

steps=(
  10_fetch.py
  20_build_canonical.py
  30_build_sqlite.py
  00_recon.py
  01_coverage.py
  40_analyze.py
  50_economics.py
  60_builds.py
  70_crosscheck.py
  99_verify.py
)

for step in "${steps[@]}"; do
  printf '== %s\n' "$step"
  if [ "$step" = "10_fetch.py" ] && [ "${1:-}" != "--refresh" ]; then
    "$PY" "$step" >/dev/null
  else
    "$PY" "$step" >/dev/null
  fi
done
printf '\npipeline complete\n'
