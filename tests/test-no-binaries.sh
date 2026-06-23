#!/bin/sh
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
bad=$(find "$ROOT" -path "$ROOT/.git" -prune -o -type f \( -name '*.ko' -o -name '*.o' -o -name '*.a' -o -name '*.so' -o -name '*.bin' -o -name '*.img' -o -name '*.elf' \) -print)
[ -z "$bad" ] || { echo "$bad"; exit 1; }
echo "no binaries=pass"

