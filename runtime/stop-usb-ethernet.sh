#!/bin/sh
set -eu
DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck disable=SC1091
. "$DIR/common.sh"

if have_iface "$USB_IFACE"; then
  ip addr flush dev "$USB_IFACE" || true
  ip link set "$USB_IFACE" down || true
fi

for module in cdc_ncm usbnet mii; do
  rmmod "$module" >/dev/null 2>&1 || true
done
log "usb ethernet stopped"

