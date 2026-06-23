#!/bin/sh
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
python3 "$ROOT/tools/scan-release.py" "$ROOT"

