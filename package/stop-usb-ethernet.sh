#!/bin/sh
set -u

PACKAGE_DIR="${PACKAGE_DIR:-$(CDPATH= cd "$(dirname "$0")" && pwd)}"
LOG_FILE="${LOG_FILE:-$PACKAGE_DIR/usb-ethernet.log}"
STATE_DIR="${STATE_DIR:-$PACKAGE_DIR/state}"

log() {
  printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" | tee -a "$LOG_FILE"
}

module_loaded() {
  grep -q "^$1 " /proc/modules 2>/dev/null
}

module_refcount() {
  awk -v m="$1" '$1 == m { print $3 }' /proc/modules 2>/dev/null
}

stop_usb0_dhcp() {
  file="$STATE_DIR/udhcpc-usb0.pid"
  [ -s "$file" ] || return 0
  pid="$(cat "$file")"
  if kill -0 "$pid" >/dev/null 2>&1; then
    log "stopping package-owned usb0 DHCP client pid=$pid"
    kill "$pid" >/dev/null 2>&1 || true
  fi
  rm -f "$file"
}

unload_if_safe() {
  name="$1"
  if ! module_loaded "$name"; then
    log "module not loaded: $name"
    return 0
  fi
  refs="$(module_refcount "$name")"
  if [ "${refs:-1}" != "0" ]; then
    log "leaving module loaded because refcount is $refs: $name"
    return 0
  fi
  log "unloading module: $name"
  rmmod "$name" >> "$LOG_FILE" 2>&1 || log "rmmod failed for $name; module left loaded"
}

log "stop requested"
stop_usb0_dhcp
if [ -d /sys/class/net/usb0 ]; then
  log "bringing usb0 down"
  ip link set dev usb0 down >> "$LOG_FILE" 2>&1 || log "failed to bring usb0 down"
else
  log "usb0 not present"
fi

unload_if_safe cdc_ncm
unload_if_safe usbnet
unload_if_safe mii
log "complete: no forced removal used"
