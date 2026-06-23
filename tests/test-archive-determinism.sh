#!/bin/sh
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
python3 "$ROOT/tools/build-release-archives.py" >/tmp/k1c-archive-1.out
first=$(sha256sum "$ROOT/dist/creality-k1c-ethernet-driver-v0.1.1.tar.gz" "$ROOT/dist/creality-k1c-ethernet-driver-v0.1.1.zip")
python3 "$ROOT/tools/build-release-archives.py" >/tmp/k1c-archive-2.out
second=$(sha256sum "$ROOT/dist/creality-k1c-ethernet-driver-v0.1.1.tar.gz" "$ROOT/dist/creality-k1c-ethernet-driver-v0.1.1.zip")
[ "$first" = "$second" ] || { echo "archive hashes changed"; exit 1; }
python3 "$ROOT/tools/scan-release.py" "$ROOT"
echo "archive determinism=pass"
