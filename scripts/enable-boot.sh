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
ssh "$HOST" "set -eu; test -f /etc/init.d/usb_ethernet_primary.disabled; rm -f /etc/init.d/S46usb_ethernet_primary.disabled; cp /etc/init.d/usb_ethernet_primary.disabled /etc/init.d/usb_ethernet_primary; chmod 0755 /etc/init.d/usb_ethernet_primary"
note "boot hook enabled on $HOST"

