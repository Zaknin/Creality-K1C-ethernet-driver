#!/bin/sh
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
. "$ROOT/scripts/lib.sh"

HOST=
OUT=output/diagnostics
while [ "$#" -gt 0 ]; do
  case "$1" in
    --host) HOST=${2:-}; shift 2 ;;
    --out) OUT=${2:-}; shift 2 ;;
    -h|--help) echo "usage: $0 --host root@PRINTER_ADDRESS --out output/diagnostics"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done
require_host_arg "$HOST"
need_cmd ssh
mkdir -p "$OUT"
ssh "$HOST" "set -eu; uname -a; ip addr show; ip route show; lsmod 2>/dev/null || true; dmesg | tail -n 120" >"$OUT/printer-diagnostics.txt"
note "diagnostics written to $OUT/printer-diagnostics.txt"

