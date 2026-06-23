#!/bin/sh
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)

license=$ROOT/LICENSE
readme=$ROOT/README.md
notices=$ROOT/THIRD-PARTY-NOTICES.md

[ -f "$license" ] || {
  echo "root LICENSE is missing"
  exit 1
}

grep '^MIT License$' "$license" >/dev/null
grep '^Copyright (c) 2026 Zaknin$' "$license" >/dev/null
grep '\[MIT License\](LICENSE)' "$readme" >/dev/null

grep 'Project code' "$notices" >/dev/null
grep 'Linux kernel and modules' "$notices" >/dev/null
grep 'Ingenic source package' "$notices" >/dev/null
grep 'Creality firmware' "$notices" >/dev/null
grep 'Toolchains and SDKs' "$notices" >/dev/null

if grep -RilE 'MIT License covers.*(vendor|firmware|SDK|toolchain|kernel module)|vendor.*covered by.*MIT|firmware.*covered by.*MIT|SDK.*covered by.*MIT|toolchain.*covered by.*MIT|kernel modules.*covered by.*MIT' "$ROOT/README.md" "$ROOT/docs" "$ROOT/DISCLAIMER.md" "$ROOT/THIRD-PARTY-NOTICES.md" >/tmp/k1c-bad-license-claims.out; then
  cat /tmp/k1c-bad-license-claims.out
  exit 1
fi

python3 "$ROOT/tools/build-release-archives.py" >/tmp/k1c-license-archive.out
tar -tzf "$ROOT/dist/creality-k1c-ethernet-driver-v0.1.1.tar.gz" | grep '/LICENSE$' >/dev/null
python3 - "$ROOT/dist/creality-k1c-ethernet-driver-v0.1.1.zip" <<'PY'
import sys, zipfile
with zipfile.ZipFile(sys.argv[1]) as zf:
    names = zf.namelist()
    assert any(name.endswith("/LICENSE") for name in names)
PY

echo "license=pass"
