#!/bin/sh
set -eu

RUNTIME_DIR=${RUNTIME_DIR:-$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)}
CONFIG_FILE=${CONFIG_FILE:-$RUNTIME_DIR/config.conf}
[ -f "$CONFIG_FILE" ] || CONFIG_FILE="$RUNTIME_DIR/config.conf.example"
# shellcheck disable=SC1090
. "$CONFIG_FILE"

USB_IFACE=${USB_IFACE:-usb0}
WIFI_IFACE=${WIFI_IFACE:-wlan0}
KEEP_WIFI_FALLBACK=${KEEP_WIFI_FALLBACK:-1}
USB_DHCP_TIMEOUT=${USB_DHCP_TIMEOUT:-20}
INSTALL_DIR=${INSTALL_DIR:-/usr/data/k1c-usb-ethernet-local}
BOOT_HOOK=${BOOT_HOOK:-/etc/init.d/usb_ethernet_primary}
DISABLED_BOOT_HOOK=${DISABLED_BOOT_HOOK:-/etc/init.d/usb_ethernet_primary.disabled}

log() {
  printf '%s\n' "$*"
}

have_iface() {
  ip link show "$1" >/dev/null 2>&1
}

wifi_default_route() {
  ip route show default 2>/dev/null | grep " dev $WIFI_IFACE" >/dev/null 2>&1
}

usb_default_route() {
  ip route show default 2>/dev/null | grep " dev $USB_IFACE" >/dev/null 2>&1
}

preserve_wifi_fallback() {
  [ "$KEEP_WIFI_FALLBACK" = "1" ] || return 0
  if wifi_default_route; then
    log "KEEP_WIFI_FALLBACK=1 preserving Wi-Fi default route on $WIFI_IFACE"
    return 0
  fi
  return 0
}

