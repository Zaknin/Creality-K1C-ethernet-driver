#!/bin/sh
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
python3 "$ROOT/tools/build-release-archives.py" >/tmp/k1c-archive-modes.out
tar -tvf "$ROOT/dist/creality-k1c-ethernet-driver-v0.1.1.tar.gz" | grep 'scripts/check-environment.sh' | grep 'rwx' >/dev/null
python3 - "$ROOT/dist/creality-k1c-ethernet-driver-v0.1.1.zip" <<'PY'
import sys, zipfile
with zipfile.ZipFile(sys.argv[1]) as zf:
    names = sorted(zf.namelist())
    assert any(n.endswith("scripts/check-environment.sh") for n in names)
    assert not any("/dist/" in n for n in names)
    assert not any("/.github/maintainers/" in n for n in names)
PY
echo "archive modes=pass"
