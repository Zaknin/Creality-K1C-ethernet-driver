#!/bin/sh
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/modules"
printf 'not an elf\n' >"$tmp/modules/mii.ko"
printf 'not an elf\n' >"$tmp/modules/usbnet.ko"
printf 'not an elf\n' >"$tmp/modules/cdc_ncm.ko"
if "$ROOT/scripts/package-local-build.sh" --modules-dir "$tmp/modules" --out "$tmp/out" >/tmp/k1c-package.out 2>&1; then
  echo "package unexpectedly accepted fake modules"
  exit 1
fi
grep 'does not look like' /tmp/k1c-package.out >/dev/null
echo "package layout refusal=pass"

