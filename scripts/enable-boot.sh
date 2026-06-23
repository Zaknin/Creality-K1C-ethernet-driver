#!/bin/sh
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
. "$ROOT/scripts/lib.sh"

HOST=
usage() {
  cat <<'EOF'
Enable automatic Ethernet startup on the printer.

Usage:
  scripts/enable-boot.sh --host "$PRINTER_HOST"

Options:
  --host HOST    SSH target, for example root@PRINTER_IP.

Behavior:
  Copies /etc/init.d/usb_ethernet_primary.disabled to
  /etc/init.d/usb_ethernet_primary and makes it executable.

Safety:
  Use only after Wi-Fi SSH and Ethernet SSH both work.
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
ssh "$HOST" "set -eu; test -f /etc/init.d/usb_ethernet_primary.disabled; rm -f /etc/init.d/S46usb_ethernet_primary.disabled; cp /etc/init.d/usb_ethernet_primary.disabled /etc/init.d/usb_ethernet_primary; chmod 0755 /etc/init.d/usb_ethernet_primary"
note "boot hook enabled on $HOST"
