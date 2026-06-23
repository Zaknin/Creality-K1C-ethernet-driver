#!/bin/sh
set -eu
DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck disable=SC1091
. "$DIR/common.sh"

echo "usb_iface=$USB_IFACE"
ip link show "$USB_IFACE" 2>/dev/null || true
ip addr show "$USB_IFACE" 2>/dev/null || true
ip route show default 2>/dev/null || true
lsmod 2>/dev/null | grep -E '^(mii|usbnet|cdc_ncm)[[:space:]]' || true

