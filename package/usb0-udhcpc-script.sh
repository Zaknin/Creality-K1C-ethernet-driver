#!/bin/sh
set -u

PACKAGE_DIR="${PACKAGE_DIR:-$(CDPATH= cd "$(dirname "$0")" && pwd)}"
STATE_DIR="${STATE_DIR:-$PACKAGE_DIR/state}"
. "$PACKAGE_DIR/runtime-logging.sh"
k1c_setup_log "primary-ethernet.log" || exit 1
LOG_CONTEXT="usb0-udhcpc"

. "$PACKAGE_DIR/primary-routing-lib.sh"

mkdir -p "$STATE_DIR"

event="${1:-unknown}"
route_log "event=$event interface=${interface:-unknown} ip=${ip:-none} router=${router:-none} dns=${dns:-none} lease=${lease:-none} carrier=$(carrier_value "$USB_IF")"

case "$event" in
  bound|renew|reconcile|deconfig|nak|leasefail)
    if acquire_route_lock; then
      trap 'release_route_lock' EXIT INT TERM
    else
      exit 1
    fi
    ;;
esac

case "$event" in
  bound|renew)
    apply_usb_primary_routes
    ;;
  reconcile)
    reconcile_usb_primary_routes
    ;;
  deconfig|nak|leasefail)
    restore_wifi_fallback_routes
    ;;
  *)
    route_log "ignored event=$event"
    ;;
esac

exit $?
