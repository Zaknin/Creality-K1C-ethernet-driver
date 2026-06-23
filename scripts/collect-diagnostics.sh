#!/bin/sh
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
. "$ROOT/scripts/lib.sh"

HOST=
OUT=output/diagnostics
usage() {
  cat <<'EOF'
Collect printer diagnostics over SSH.

Usage:
  scripts/collect-diagnostics.sh --host "$PRINTER_HOST" --out output/diagnostics

Options:
  --host HOST    SSH target, for example root@PRINTER_IP.
  --out DIR      Local output directory. Default: output/diagnostics.

Output:
  output/diagnostics/printer-diagnostics.txt

Safety:
  The report may contain private network details. Review it before sharing.
EOF
}
while [ "$#" -gt 0 ]; do
  case "$1" in
    --host) HOST=${2:-}; shift 2 ;;
    --out) OUT=${2:-}; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done
require_host_arg "$HOST"
need_cmd ssh
mkdir -p "$OUT"
ssh "$HOST" "set -eu; uname -a; ip addr show; ip route show; lsmod 2>/dev/null || true; dmesg | tail -n 120" >"$OUT/printer-diagnostics.txt"
note "diagnostics written to $OUT/printer-diagnostics.txt"
