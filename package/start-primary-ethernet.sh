#!/bin/sh
set -u

PACKAGE_DIR="${PACKAGE_DIR:-$(CDPATH= cd "$(dirname "$0")" && pwd)}"
STATE_DIR="${STATE_DIR:-$PACKAGE_DIR/state}"
. "$PACKAGE_DIR/runtime-logging.sh"
k1c_setup_log "primary-ethernet.log" || exit 1
UDHCPC_SCRIPT="$PACKAGE_DIR/usb0-udhcpc-script.sh"
MONITOR_SCRIPT="$PACKAGE_DIR/usb0-route-monitor.sh"
PID_FILE="$STATE_DIR/udhcpc-usb0.pid"
MONITOR_PID_FILE="$STATE_DIR/usb0-monitor.pid"
UDHCPC_PID_FILE="$PID_FILE"
LOG_CONTEXT="start-primary"
BOOT_DHCP_TRIES="${BOOT_DHCP_TRIES:-5}"

. "$PACKAGE_DIR/primary-routing-lib.sh"

mkdir -p "$STATE_DIR"

log() {
  k1c_trim_log
  printf '%s start-primary[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$$" "$*" | tee -a "$LOG_FILE"
}

fail() {
  log "ERROR: $*"
  exit 1
}

start_udhcpc() {
  if dhcp_lease_valid_for_current_usb_interface; then
    log "udhcpc lease already valid for current usb0 interface"
    return 0
  fi
  if dhcp_process_valid; then
    log "udhcpc process alive but lease invalid for current usb0 interface; restarting"
    terminate_runtime_udhcpc || fail "stale udhcpc process did not exit"
  fi
  clear_usb_lease_state
  clear_dhcp_replacement_pending
  log "starting bounded boot DHCP acquisition command=udhcpc -i $USB_IF -n -q -t $BOOT_DHCP_TRIES"
  DHCP_LOG_DIR="$STATE_DIR" STATE_DIR="$STATE_DIR" LOG_FILE="$LOG_FILE" PACKAGE_DIR="$PACKAGE_DIR" \
    udhcpc -i "$USB_IF" -n -q -t "$BOOT_DHCP_TRIES" -s "$UDHCPC_SCRIPT" >> "$LOG_FILE" 2>&1 || return 1
  dhcp_lease_valid_for_current_usb_interface
}

start_monitor() {
  if [ -s "$MONITOR_PID_FILE" ] && kill -0 "$(cat "$MONITOR_PID_FILE")" >/dev/null 2>&1; then
    log "monitor already running pid=$(cat "$MONITOR_PID_FILE")"
    return 0
  fi
  PACKAGE_DIR="$PACKAGE_DIR" STATE_DIR="$STATE_DIR" LOG_FILE="$LOG_FILE" \
    nohup "$MONITOR_SCRIPT" >> "$LOG_FILE" 2>&1 &
  echo "$!" > "$MONITOR_PID_FILE"
  log "monitor started pid=$(cat "$MONITOR_PID_FILE")"
}

log "requested package=$PACKAGE_DIR"
"$PACKAGE_DIR/start-usb-ethernet.sh" --up || fail "module/device start failed"
wait_for_usb_carrier 30 || fail "usb0 carrier did not appear"
start_udhcpc

i=0
while [ "$i" -le 35 ]; do
  if dhcp_lease_valid_for_current_usb_interface; then
    log "lease acquired usb0_ip=$(cat "$STATE_DIR/usb0.ip")"
    start_monitor
    exit 0
  fi
  sleep 1
  i=$((i + 1))
done

log "no usb0 DHCP lease acquired; preserving existing routes and fallback state"
fail "no usb0 DHCP lease acquired"
