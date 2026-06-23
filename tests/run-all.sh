#!/bin/sh
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)

for test_script in "$ROOT"/tests/test-*.sh; do
  echo "== $(basename "$test_script")"
  sh "$test_script"
done

