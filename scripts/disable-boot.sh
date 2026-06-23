#!/bin/sh
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
. "$ROOT/scripts/lib.sh"

HOST=
usage() {
  cat <<'EOF'
Disable automatic Ethernet startup without uninstalling.

Usage:
  scripts/disable-boot.sh --host "$PRINTER_HOST"

Options:
  --host HOST    SSH target, for example root@PRINTER_IP.

Behavior:
  Removes /etc/init.d/usb_ethernet_primary and keeps or recreates
  /etc/init.d/usb_ethernet_primary.disabled when the runtime is installed.

Safety:
  Use this first if Ethernet startup causes trouble but Wi-Fi SSH still works.
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
ssh "$HOST" "set -eu; rm -f /etc/init.d/usb_ethernet_primary /etc/init.d/S46usb_ethernet_primary.disabled; if [ -f /usr/data/k1c-usb-ethernet-local/runtime/start-primary-ethernet.sh ]; then cp /usr/data/k1c-usb-ethernet-local/runtime/start-primary-ethernet.sh /etc/init.d/usb_ethernet_primary.disabled; chmod 0755 /etc/init.d/usb_ethernet_primary.disabled; fi"
note "boot hook disabled on $HOST"
