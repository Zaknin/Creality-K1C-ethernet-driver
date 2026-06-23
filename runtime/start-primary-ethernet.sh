#!/bin/sh
set -eu
DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck disable=SC1091
. "$DIR/common.sh"

"$DIR/start-usb-ethernet.sh"
if [ "$KEEP_WIFI_FALLBACK" = "1" ] && wifi_default_route; then
  log "primary switch skipped because Wi-Fi fallback route remains active"
  exit 0
fi

if have_iface "$USB_IFACE" && ip addr show "$USB_IFACE" | grep 'inet ' >/dev/null 2>&1; then
  ip route replace default dev "$USB_IFACE" metric 10 || true
  log "USB Ethernet primary route requested"
else
  log "USB interface has no IPv4 address; primary route not changed"
fi

