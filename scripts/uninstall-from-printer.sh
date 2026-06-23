#!/bin/sh
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
. "$ROOT/scripts/lib.sh"

HOST=
usage() {
  cat <<'EOF'
Remove the USB Ethernet installation from the printer.

Usage:
  scripts/uninstall-from-printer.sh --host "$PRINTER_HOST"

Options:
  --host HOST    SSH target, for example root@PRINTER_IP.

Removes:
  /etc/init.d/usb_ethernet_primary
  /etc/init.d/usb_ethernet_primary.disabled
  /usr/data/k1c-usb-ethernet-local

Safety:
  Use scripts/disable-boot.sh first if you only want to stop startup.
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
ssh "$HOST" "set -eu; if [ -x /usr/data/k1c-usb-ethernet-local/runtime/uninstall.sh ]; then /usr/data/k1c-usb-ethernet-local/runtime/uninstall.sh; else rm -f /etc/init.d/usb_ethernet_primary /etc/init.d/usb_ethernet_primary.disabled /etc/init.d/S46usb_ethernet_primary.disabled; rm -rf /usr/data/k1c-usb-ethernet-local; fi"
note "uninstalled from $HOST"
