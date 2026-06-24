#!/bin/sh
set -u

PACKAGE_DIR="${PACKAGE_DIR:-$(CDPATH= cd "$(dirname "$0")" && pwd)}"
STATE_DIR="${STATE_DIR:-$PACKAGE_DIR/state}"
LOG_FILE="${LOG_FILE:-$PACKAGE_DIR/primary-ethernet.log}"
UDHCPC_SCRIPT="${UDHCPC_SCRIPT:-$PACKAGE_DIR/usb0-udhcpc-script.sh}"
MONITOR_INTERVAL="${MONITOR_INTERVAL:-3}"
MONITOR_ONCE="${MONITOR_ONCE:-0}"
LOG_CONTEXT="usb0-monitor"

. "$PACKAGE_DIR/primary-routing-lib.sh"

mkdir -p "$STATE_DIR"

run_once() {
  carrier="$(carrier_value "$USB_IF")"
  active=0
  [ -f "$STATE_DIR/ethernet.active" ] && active=1

  if [ "$active" -eq 0 ]; then
    return 0
  fi

  if [ "$carrier" != "1" ]; then
    route_log "usb carrier lost carrier=$carrier; activating fallback"
    "$UDHCPC_SCRIPT" leasefail
    return $?
  fi

  if [ -z "$(iface_ipv4 "$USB_IF")" ] && [ -z "$(file_value "$STATE_DIR/usb0.ip" 2>/dev/null || true)" ]; then
    route_log "usb address missing while active; activating fallback"
    "$UDHCPC_SCRIPT" leasefail
    return $?
  fi

  if usb_primary_needs_reconcile; then
    "$UDHCPC_SCRIPT" reconcile
    return $?
  fi

  return 0
}

route_log "monitor started interval=${MONITOR_INTERVAL}s once=$MONITOR_ONCE"
while :; do
  run_once
  rc=$?
  [ "$MONITOR_ONCE" = "1" ] && exit "$rc"
  sleep "$MONITOR_INTERVAL"
done
