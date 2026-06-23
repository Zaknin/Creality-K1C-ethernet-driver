#!/bin/sh
set -eu
DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck disable=SC1091
. "$DIR/common.sh"

for module in mii usbnet cdc_ncm; do
  if ! lsmod 2>/dev/null | awk '{print $1}' | grep "^$module$" >/dev/null 2>&1; then
    insmod "$INSTALL_DIR/modules/$module.ko" || modprobe "$module" || {
      log "failed to load $module"
      exit 1
    }
  fi
done

if have_iface "$USB_IFACE"; then
  ip link set "$USB_IFACE" up || true
  if command -v udhcpc >/dev/null 2>&1; then
    udhcpc -i "$USB_IFACE" -s "$DIR/usb0-udhcpc-script.sh" -t 3 -T "$USB_DHCP_TIMEOUT" -q || true
  fi
fi

preserve_wifi_fallback
"$DIR/status-usb-ethernet.sh"

