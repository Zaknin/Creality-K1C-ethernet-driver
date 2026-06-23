#!/bin/sh
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/modules"
printf 'not an elf\n' >"$tmp/modules/mii.ko"
printf 'not an elf\n' >"$tmp/modules/usbnet.ko"
printf 'not an elf\n' >"$tmp/modules/cdc_ncm.ko"
if "$ROOT/scripts/verify-modules.sh" --modules-dir "$tmp/modules" --report-dir "$tmp/report" >/tmp/k1c-verify.out 2>&1; then
  echo "fake modules unexpectedly passed verification"
  exit 1
fi
grep 'does not look like' /tmp/k1c-verify.out >/dev/null
echo "module verification fixtures=pass"

