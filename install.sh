#!/bin/sh
set -eu

VERSION=1.0.0
EXPECTED_KERNEL=4.4.94
DEFAULT_INSTALL_DIR=/usr/data/k1c-usb-ethernet/vendor-native-known-good
BOOT_HOOK="${BOOT_HOOK:-/etc/init.d/S46usb_ethernet_primary}"

usage() {
  cat <<EOF
Usage: sh install.sh [--enable-boot] [--dest DIR]

Installs the K1C USB Ethernet v$VERSION package on the explicitly supported
K1C kernel ABI. Boot integration is not enabled unless --enable-boot is given.
EOF
}

enable_boot=0
dest="$DEFAULT_INSTALL_DIR"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --enable-boot)
      enable_boot=1
      shift
      ;;
    --dest)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      dest="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

fail() {
  echo "install: ERROR: $*" >&2
  exit 1
}

[ "$(uname -r)" = "$EXPECTED_KERNEL" ] || fail "unsupported kernel $(uname -r), expected $EXPECTED_KERNEL"
[ -d package ] || fail "run this installer from the release repository root"
[ -f package/module-hashes.sha256 ] || fail "missing package/module-hashes.sha256"

( cd package && sha256sum -c module-hashes.sha256 ) || fail "module hash verification failed"

mkdir -p "$dest"
cp -R package/. "$dest/"
echo "k1c-usb-ethernet v$VERSION package-owned install tree" > "$dest/.package-owned"
( cd "$dest" && sha256sum -c module-hashes.sha256 ) || fail "installed module hash verification failed"

chmod 755 \
  "$dest/primary-routing-lib.sh" \
  "$dest/start-usb-ethernet.sh" \
  "$dest/stop-usb-ethernet.sh" \
  "$dest/status-usb-ethernet.sh" \
  "$dest/uninstall-usb-ethernet.sh" \
  "$dest/start-primary-ethernet.sh" \
  "$dest/stop-primary-ethernet.sh" \
  "$dest/usb0-route-monitor.sh" \
  "$dest/usb0-udhcpc-script.sh" \
  "$dest/ethernet-failover-status.sh" \
  "$dest/disable-primary-ethernet-boot.sh" \
  "$dest/S46usb_ethernet_primary"

if [ "$enable_boot" -eq 1 ]; then
  cp "$dest/S46usb_ethernet_primary" "$BOOT_HOOK"
  chmod 755 "$BOOT_HOOK"
  echo "install: boot integration enabled at $BOOT_HOOK"
else
  echo "install: boot integration not enabled"
fi

echo "install: installed v$VERSION to $dest"
echo "install: run $dest/start-primary-ethernet.sh to start Ethernet-primary mode"
