#!/bin/sh
set -eu

interface=${interface:-usb0}

case "${1:-}" in
  deconfig)
    ip addr flush dev "$interface" || true
    ;;
  bound|renew)
    [ -n "${ip:-}" ] || exit 0
    ip addr flush dev "$interface" || true
    ip addr add "$ip/${subnet:-24}" dev "$interface" || true
    if [ "${router:-}" ]; then
      if [ "${KEEP_WIFI_FALLBACK:-1}" = "1" ] && ip route show default | grep ' dev wlan0' >/dev/null 2>&1; then
        exit 0
      fi
      ip route replace default via "$router" dev "$interface" || true
    fi
    ;;
esac
