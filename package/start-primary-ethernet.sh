#!/bin/sh
set -u

PACKAGE_DIR="${PACKAGE_DIR:-$(CDPATH= cd "$(dirname "$0")" && pwd)}"
STATE_DIR="${STATE_DIR:-$PACKAGE_DIR/state}"
LOG_FILE="${LOG_FILE:-$PACKAGE_DIR/primary-ethernet.log}"
UDHCPC_SCRIPT="$PACKAGE_DIR/usb0-udhcpc-script.sh"
PID_FILE="$STATE_DIR/udhcpc-usb0.pid"
MONITOR_PID_FILE="$STATE_DIR/usb0-monitor.pid"

mkdir -p "$STATE_DIR"

log() {
  printf '%s start-primary[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$$" "$*" | tee -a "$LOG_FILE"
}

fail() {
  log "ERROR: $*"
  exit 1
}

wait_carrier() {
  limit="${1:-30}"
  i=0
  while [ "$i" -le "$limit" ]; do
    carrier="$(cat /sys/class/net/usb0/carrier 2>/dev/null || echo absent)"
    log "carrier_wait second=$i carrier=$carrier operstate=$(cat /sys/class/net/usb0/operstate 2>/dev/null || echo absent)"
    [ "$carrier" = "1" ] && return 0
    [ "$i" -eq "$limit" ] && break
    sleep 1
    i=$((i + 1))
  done
  return 1
}

start_udhcpc() {
  if [ -s "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" >/dev/null 2>&1; then
    log "udhcpc already running pid=$(cat "$PID_FILE")"
    return 0
  fi
  rm -f "$STATE_DIR/usb0.env" "$STATE_DIR/usb0.ip" "$STATE_DIR/ethernet.active"
  log "starting udhcpc on usb0"
  DHCP_LOG_DIR="$STATE_DIR" STATE_DIR="$STATE_DIR" LOG_FILE="$LOG_FILE" PACKAGE_DIR="$PACKAGE_DIR" \
    nohup udhcpc -i usb0 -f -t 3 -T 4 -p "$PID_FILE" -s "$UDHCPC_SCRIPT" >> "$LOG_FILE" 2>&1 &
  echo "$!" > "$PID_FILE"
}

start_monitor() {
  if [ -s "$MONITOR_PID_FILE" ] && kill -0 "$(cat "$MONITOR_PID_FILE")" >/dev/null 2>&1; then
    log "monitor already running pid=$(cat "$MONITOR_PID_FILE")"
    return 0
  fi
  (
    last_carrier=""
    while :; do
      carrier="$(cat /sys/class/net/usb0/carrier 2>/dev/null || echo absent)"
      if [ "$carrier" != "$last_carrier" ]; then
        printf '%s monitor carrier=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$carrier" >> "$LOG_FILE"
        last_carrier="$carrier"
      fi
      if [ "$carrier" != "1" ]; then
        if [ -f "$STATE_DIR/ethernet.active" ]; then
          "$UDHCPC_SCRIPT" leasefail
        fi
      fi
      sleep 2
    done
  ) &
  echo "$!" > "$MONITOR_PID_FILE"
  log "monitor started pid=$(cat "$MONITOR_PID_FILE")"
}

log "requested package=$PACKAGE_DIR"
"$PACKAGE_DIR/start-usb-ethernet.sh" --up || fail "module/device start failed"
wait_carrier 30 || fail "usb0 carrier did not appear"
start_udhcpc

i=0
while [ "$i" -le 35 ]; do
  if [ -s "$STATE_DIR/usb0.ip" ]; then
    log "lease acquired usb0_ip=$(cat "$STATE_DIR/usb0.ip")"
    start_monitor
    exit 0
  fi
  sleep 1
  i=$((i + 1))
done

"$UDHCPC_SCRIPT" leasefail
fail "no usb0 DHCP lease acquired"
