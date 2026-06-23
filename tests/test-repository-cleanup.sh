#!/bin/sh
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)

tracked=$(git -C "$ROOT" ls-files)

printf '%s\n' "$tracked" | grep '^dist/' && {
  echo "dist/ must not be tracked"
  exit 1
}

printf '%s\n' "$tracked" | grep '^RELEASE-FILES\.sha256$' && {
  echo "RELEASE-FILES.sha256 must not be tracked"
  exit 1
}

printf '%s\n' "$tracked" | grep -E '(^|/).*-v[0-9][^/]*\.(tar\.gz|zip)$' && {
  echo "versioned release archive must not be tracked"
  exit 1
}

[ ! -e "$ROOT/fixtures/README.md" ] || {
  echo "empty fixtures placeholder returned"
  exit 1
}

[ "$(cat "$ROOT/VERSION")" = "0.1.1" ] || {
  echo "VERSION is not 0.1.1"
  exit 1
}

source_doc=$ROOT/docs/SOURCE-ACQUISITION.md
grep 'ingenic-linux-kernel4.4.94-x2000_v12-v8.0-20220125.tar.bz2' "$source_doc" >/dev/null
grep 'https://pan.baidu.com/s/1PxHJhv7j_oXkFTjAVNInxA' "$source_doc" >/dev/null
grep '6svw' "$source_doc" >/dev/null

if grep -RilE 'archive is bundled|archive is included|official Creality K1C source|guaranteed.*K1C|guarantees runtime compatibility' "$ROOT/README.md" "$ROOT/docs" >/tmp/k1c-bad-docs.out; then
  cat /tmp/k1c-bad-docs.out
  exit 1
fi

if grep -RilE 'dist/k1c-usb-ethernet-build-tools-v0\.1\.0|k1c-usb-ethernet-build-tools-v0\.1\.0\.(tar\.gz|zip)' "$ROOT/README.md" "$ROOT/docs" "$ROOT/tests" "$ROOT/tools" >/tmp/k1c-old-archives.out; then
  cat /tmp/k1c-old-archives.out
  exit 1
fi

python3 "$ROOT/tools/build-release-archives.py" >/tmp/k1c-cleanup-archive.out

tar -tzf "$ROOT/dist/creality-k1c-ethernet-driver-v0.1.1.tar.gz" | sed 's#^[^/]*/##' | tr -d '\r' | sort > /tmp/k1c-tar-list.out
python3 - "$ROOT/dist/creality-k1c-ethernet-driver-v0.1.1.zip" > /tmp/k1c-zip-list.out <<'PY'
import sys, zipfile
with zipfile.ZipFile(sys.argv[1]) as zf:
    for name in zf.namelist():
        print(name.split("/", 1)[1])
PY
tr -d '\r' < /tmp/k1c-zip-list.out > /tmp/k1c-zip-list-normalized.out
sort /tmp/k1c-zip-list-normalized.out -o /tmp/k1c-zip-list.out

cmp /tmp/k1c-tar-list.out /tmp/k1c-zip-list.out >/dev/null || {
  echo "tar and zip payloads differ"
  exit 1
}

cat /tmp/k1c-tar-list.out /tmp/k1c-zip-list.out > /tmp/k1c-archive-list.out

for required in \
  LICENSE \
  README.md \
  CHANGELOG.md \
  DISCLAIMER.md \
  SECURITY.md \
  THIRD-PARTY-NOTICES.md \
  VERSION
do
  grep "^$required$" /tmp/k1c-tar-list.out >/dev/null || {
    echo "release tar missing $required"
    exit 1
  }
  grep "^$required$" /tmp/k1c-zip-list.out >/dev/null || {
    echo "release zip missing $required"
    exit 1
  }
done

for required_dir in config docs runtime scripts tests tools
do
  grep "^$required_dir/" /tmp/k1c-tar-list.out >/dev/null || {
    echo "release tar missing $required_dir/"
    exit 1
  }
  grep "^$required_dir/" /tmp/k1c-zip-list.out >/dev/null || {
    echo "release zip missing $required_dir/"
    exit 1
  }
done

if grep -E '/dist/|/\.github/maintainers/|ingenic-linux-kernel4\.4\.94-x2000_v12-v8\.0-20220125\.tar\.bz2|\.ko$|/sdk/|/toolchain/|/sysroot/|/firmware/|/private/|/evidence/' /tmp/k1c-archive-list.out; then
  echo "release archive contains forbidden content"
  exit 1
fi

echo "repository cleanup=pass"
