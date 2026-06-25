#!/bin/sh
set -u

PACKAGE_DIR="${PACKAGE_DIR:-$(CDPATH= cd "$(dirname "$0")" && pwd)}"
STATE_DIR="${STATE_DIR:-$PACKAGE_DIR/state}"
LOG_FILE="${LOG_FILE:-$PACKAGE_DIR/primary-ethernet.log}"
UDHCPC_SCRIPT="$PACKAGE_DIR/usb0-udhcpc-script.sh"
MONITOR_SCRIPT="$PACKAGE_DIR/usb0-route-monitor.sh"
PID_FILE="$STATE_DIR/udhcpc-usb0.pid"
MONITOR_PID_FILE="$STATE_DIR/usb0-monitor.pid"
UDHCPC_PID_FILE="$PID_FILE"
LOG_CONTEXT="start-primary"

. "$PACKAGE_DIR/primary-routing-lib.sh"

mkdir -p "$STATE_DIR"

log() {
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
  if dhcp_replacement_waiting; then
    log "udhcpc replacement already running pid=$(cat "$PID_FILE")"
    return 0
  fi
  if dhcp_process_valid; then
    log "udhcpc process alive but lease invalid for current usb0 interface; restarting"
  fi
  restart_runtime_udhcpc_for_generation || fail "stale udhcpc process did not exit"
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

"$UDHCPC_SCRIPT" leasefail
fail "no usb0 DHCP lease acquired"
