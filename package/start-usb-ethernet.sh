#!/bin/sh
set -u

PACKAGE_DIR="${PACKAGE_DIR:-$(CDPATH= cd "$(dirname "$0")" && pwd)}"
MODULE_DIR="$PACKAGE_DIR/modules"
. "$PACKAGE_DIR/runtime-logging.sh"
k1c_setup_log "usb-ethernet.log" || exit 1
EXPECTED_KERNEL="4.4.94"

MII_HASH="a66d280aa643319a848260e8ade6373415a61e1e07c73e16dacd33f75ac497d8"
USBNET_HASH="8a582cb3f480f86126dacc2b7255b45efcb4fb58d591007e6ba653bee08da85d"
CDC_NCM_HASH="f12a6cc8faf904a72cb44e21e6ec520efe24b37ae9999a40a1ca0183517d7271"

log() {
  k1c_trim_log
  printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" | tee -a "$LOG_FILE"
}

fail() {
  log "ERROR: $*"
  exit 1
}

usage() {
  cat <<EOF
Usage: $0 [--up]

Loads verified known-good USB Ethernet modules. By default this does not bring
usb0 up and does not run DHCP. Use --up to bring usb0 up after the modules and
device are present.
EOF
}

bring_up=0
case "${1:-}" in
  "") ;;
  --up) bring_up=1 ;;
  -h|--help) usage; exit 0 ;;
  *) usage; exit 2 ;;
esac

hash_file() {
  sha256sum "$1" | awk '{print $1}'
}

verify_hash() {
  file="$1"
  expected="$2"
  [ -f "$file" ] || fail "missing module $file"
  actual="$(hash_file "$file")"
  [ "$actual" = "$expected" ] || fail "hash mismatch for $file: got $actual expected $expected"
  log "hash ok: $(basename "$file") $actual"
}

module_loaded() {
  grep -q "^$1 " /proc/modules
}

load_module() {
  name="$1"
  file="$2"
  if module_loaded "$name"; then
    log "module already loaded: $name"
    return 0
  fi
  log "loading module: $file"
  insmod "$file" >> "$LOG_FILE" 2>&1 || fail "insmod failed for $file"
}

wait_for_asix() {
  i=0
  while [ "$i" -lt 15 ]; do
    for dev in /sys/bus/usb/devices/*; do
      [ -r "$dev/idVendor" ] || continue
      [ -r "$dev/idProduct" ] || continue
      vendor="$(cat "$dev/idVendor" 2>/dev/null || true)"
      product="$(cat "$dev/idProduct" 2>/dev/null || true)"
      if [ "$vendor" = "0b95" ] && [ "$product" = "1790" ]; then
        log "ASIX 0b95:1790 present at $(basename "$dev")"
        return 0
      fi
    done
    sleep 1
    i=$((i + 1))
  done
  fail "ASIX 0b95:1790 not found"
}

wait_for_usb0() {
  i=0
  while [ "$i" -lt 15 ]; do
    [ -d /sys/class/net/usb0 ] && return 0
    sleep 1
    i=$((i + 1))
  done
  fail "usb0 did not appear"
}

log "start requested: args=$* package=$PACKAGE_DIR"
[ "$(uname -r)" = "$EXPECTED_KERNEL" ] || fail "kernel mismatch: running $(uname -r), expected $EXPECTED_KERNEL"
verify_hash "$MODULE_DIR/mii.ko" "$MII_HASH"
verify_hash "$MODULE_DIR/usbnet.ko" "$USBNET_HASH"
verify_hash "$MODULE_DIR/cdc_ncm.ko" "$CDC_NCM_HASH"

load_module mii "$MODULE_DIR/mii.ko"
load_module usbnet "$MODULE_DIR/usbnet.ko"
load_module cdc_ncm "$MODULE_DIR/cdc_ncm.ko"
wait_for_asix
wait_for_usb0

if [ "$bring_up" -eq 1 ]; then
  log "bringing usb0 up by explicit request"
  ip link set dev usb0 up >> "$LOG_FILE" 2>&1 || fail "failed to bring usb0 up"
else
  log "usb0 present; leaving link state unchanged because --up was not provided"
fi

log "complete: no DHCP, route, DNS, wlan0, or boot configuration changes requested"
