#!/bin/sh
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
. "$ROOT/scripts/lib.sh"

HOST=
REMOTE_DIR=/tmp/k1c-usb-ethernet-local-stage
while [ "$#" -gt 0 ]; do
  case "$1" in
    --host) HOST=${2:-}; shift 2 ;;
    --remote-dir) REMOTE_DIR=${2:-}; shift 2 ;;
    -h|--help) echo "usage: $0 --host root@PRINTER_ADDRESS"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

require_host_arg "$HOST"
need_cmd ssh
# shellcheck disable=SC2029
ssh "$HOST" "set -eu; rm -rf /usr/data/k1c-usb-ethernet-local.new; mkdir -p /usr/data/k1c-usb-ethernet-local.new; tar -xzf '$REMOTE_DIR/package.tar.gz' -C /usr/data/k1c-usb-ethernet-local.new --strip-components=1; rm -rf /usr/data/k1c-usb-ethernet-local.prev; if [ -d /usr/data/k1c-usb-ethernet-local ]; then mv /usr/data/k1c-usb-ethernet-local /usr/data/k1c-usb-ethernet-local.prev; fi; mv /usr/data/k1c-usb-ethernet-local.new /usr/data/k1c-usb-ethernet-local; rm -f /etc/init.d/usb_ethernet_primary /etc/init.d/S46usb_ethernet_primary.disabled; cp /usr/data/k1c-usb-ethernet-local/runtime/start-primary-ethernet.sh /etc/init.d/usb_ethernet_primary.disabled; chmod 0755 /etc/init.d/usb_ethernet_primary.disabled"
note "installed with boot disabled on $HOST"
