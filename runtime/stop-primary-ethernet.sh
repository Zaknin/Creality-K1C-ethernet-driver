#!/bin/sh
set -eu
DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck disable=SC1091
. "$DIR/common.sh"

if usb_default_route; then
  ip route del default dev "$USB_IFACE" || true
fi
"$DIR/stop-usb-ethernet.sh"
log "primary USB Ethernet stopped"

