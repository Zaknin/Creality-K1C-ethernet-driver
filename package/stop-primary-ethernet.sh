#!/bin/sh
set -u

PACKAGE_DIR="${PACKAGE_DIR:-$(CDPATH= cd "$(dirname "$0")" && pwd)}"
STATE_DIR="${STATE_DIR:-$PACKAGE_DIR/state}"
LOG_FILE="${LOG_FILE:-$PACKAGE_DIR/primary-ethernet.log}"

log() {
  printf '%s stop-primary[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$$" "$*" | tee -a "$LOG_FILE"
}

kill_pid_file() {
  file="$1"
  label="$2"
  if [ -s "$file" ]; then
    pid="$(cat "$file")"
    if kill -0 "$pid" >/dev/null 2>&1; then
      log "stopping $label pid=$pid"
      kill "$pid" >/dev/null 2>&1 || true
      sleep 1
    fi
    rm -f "$file"
  fi
}

mkdir -p "$STATE_DIR"
log "requested"
kill_pid_file "$STATE_DIR/usb0-monitor.pid" monitor
kill_pid_file "$STATE_DIR/udhcpc-usb0.pid" udhcpc
STATE_DIR="$STATE_DIR" LOG_FILE="$LOG_FILE" PACKAGE_DIR="$PACKAGE_DIR" "$PACKAGE_DIR/usb0-udhcpc-script.sh" leasefail
"$PACKAGE_DIR/stop-usb-ethernet.sh"
log "complete"
