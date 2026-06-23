#!/bin/sh
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)

find "$ROOT/scripts" "$ROOT/runtime" "$ROOT/tests" -name '*.sh' -type f | sort | while IFS= read -r file; do
  sh -n "$file"
done

if command -v shellcheck >/dev/null 2>&1; then
  find "$ROOT/scripts" "$ROOT/runtime" "$ROOT/tests" -name '*.sh' -type f -print0 |
    sort -z |
    xargs -0 shellcheck
  echo "shellcheck=pass"
else
  echo "shellcheck=skip unavailable"
fi
echo "shell syntax=pass"
