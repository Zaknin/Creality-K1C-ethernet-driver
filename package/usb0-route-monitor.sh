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
  present=0
  iface_exists "$USB_IF" && present=1
  previous_presence="$(file_value "$STATE_DIR/usb0.interface-presence" 2>/dev/null || echo unknown)"
  recreated=0
  active=0
  [ -f "$STATE_DIR/ethernet.active" ] && active=1

  if [ "$present" -eq 0 ]; then
    printf 'absent\n' > "$STATE_DIR/usb0.interface-presence"
    if [ "$active" -eq 1 ]; then
      carrier="$(carrier_value "$USB_IF")"
      route_log "usb carrier lost carrier=$carrier; activating fallback"
      "$UDHCPC_SCRIPT" leasefail
      return $?
    fi
    return 0
  fi

  if [ "$previous_presence" != "present" ]; then
    printf 'present\n' > "$STATE_DIR/usb0.interface-presence"
    if [ "$previous_presence" = "absent" ] || [ "$active" -eq 0 ]; then
      recreated=1
      route_log "usb0 interface recreated"
      if ! ip link set "$USB_IF" up >/dev/null 2>&1; then
        route_log "failed setting $USB_IF administratively up after recreation"
      fi
    fi
  fi

  carrier="$(carrier_value "$USB_IF")"

  if [ "$carrier" != "1" ]; then
    if [ "$active" -eq 1 ]; then
      route_log "usb carrier lost carrier=$carrier; activating fallback"
      "$UDHCPC_SCRIPT" leasefail
      return $?
    fi
    if [ "$recreated" -eq 1 ]; then
      wait_for_usb_carrier "$USB_RECREATE_CARRIER_WAIT" || {
        route_log "usb0 carrier did not appear after recreation; retaining wifi fallback"
        return 0
      }
      carrier="$(carrier_value "$USB_IF")"
    else
      return 0
    fi
  fi

  if [ "$active" -eq 1 ] && [ -z "$(iface_ipv4 "$USB_IF")" ]; then
    route_log "usb address missing while active; activating fallback"
    "$UDHCPC_SCRIPT" leasefail
    active=0
  fi

  if [ "$active" -eq 1 ] && usb_primary_needs_reconcile; then
    "$UDHCPC_SCRIPT" reconcile
    return $?
  fi

  if dhcp_lease_valid_for_current_usb_interface; then
    clear_dhcp_replacement_pending
    return 0
  fi

  if [ "$carrier" = "1" ]; then
    if dhcp_replacement_waiting; then
      route_log "DHCP recovery pending for current usb0 interface generation"
      return 0
    fi
    if dhcp_process_valid; then
      route_log "DHCP_PROCESS_VALID=yes DHCP_LEASE_VALID_FOR_CURRENT_USB_INTERFACE=no; allowing short grace"
      wait_for_dhcp_lease_grace "$DHCP_RECOVERY_GRACE" && return 0
    else
      route_log "DHCP_PROCESS_VALID=no DHCP_LEASE_VALID_FOR_CURRENT_USB_INTERFACE=no"
    fi
    route_log "DHCP recovery required for current usb0 interface generation"
    restart_runtime_udhcpc_for_generation
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
