#!/bin/sh
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
. "$ROOT/scripts/lib.sh"

HOST=
usage() {
  cat <<'EOF'
Show printer USB Ethernet status.

Usage:
  scripts/test-connectivity.sh --host "$PRINTER_HOST"

Options:
  --host HOST    SSH target, for example root@PRINTER_IP.

Runs on the printer:
  /usr/data/k1c-usb-ethernet-local/runtime/status-usb-ethernet.sh

Output includes usb0, IP addresses, default routes, and loaded modules when
available.
EOF
}
while [ "$#" -gt 0 ]; do
  case "$1" in
    --host) HOST=${2:-}; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done
require_host_arg "$HOST"
need_cmd ssh
ssh "$HOST" "set -eu; /usr/data/k1c-usb-ethernet-local/runtime/status-usb-ethernet.sh"
