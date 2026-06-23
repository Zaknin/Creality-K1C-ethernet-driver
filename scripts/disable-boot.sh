#!/bin/sh
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
. "$ROOT/scripts/lib.sh"

HOST=
while [ "$#" -gt 0 ]; do
  case "$1" in
    --host) HOST=${2:-}; shift 2 ;;
    -h|--help) echo "usage: $0 --host root@PRINTER_ADDRESS"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done
require_host_arg "$HOST"
need_cmd ssh
ssh "$HOST" "set -eu; rm -f /etc/init.d/usb_ethernet_primary /etc/init.d/S46usb_ethernet_primary.disabled; if [ -f /usr/data/k1c-usb-ethernet-local/runtime/start-primary-ethernet.sh ]; then cp /usr/data/k1c-usb-ethernet-local/runtime/start-primary-ethernet.sh /etc/init.d/usb_ethernet_primary.disabled; chmod 0755 /etc/init.d/usb_ethernet_primary.disabled; fi"
note "boot hook disabled on $HOST"

