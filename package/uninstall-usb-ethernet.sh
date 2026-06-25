#!/bin/sh
set -u

PACKAGE_DIR="${PACKAGE_DIR:-$(CDPATH= cd "$(dirname "$0")" && pwd)}"
MARKER="$PACKAGE_DIR/.package-owned"
BOOT_HOOK="${BOOT_HOOK:-/etc/init.d/S46usb_ethernet_primary}"

case "${1:-}" in
  --yes)
    ;;
  -h|--help)
    echo "Usage: $0 --yes"
    exit 0
    ;;
  *)
    echo "Refusing to uninstall without --yes"
    exit 2
    ;;
esac

[ -f "$MARKER" ] || {
  echo "Refusing to uninstall because $MARKER is missing"
  exit 1
}

"$PACKAGE_DIR/disable-primary-ethernet-boot.sh" || {
  echo "Uninstall stopped because runtime cleanup failed" >&2
  exit 1
}

if [ -e "$BOOT_HOOK" ]; then
  echo "Uninstall stopped because boot hook remains: $BOOT_HOOK" >&2
  exit 1
fi

runtime_process_count=0

for proc in /proc/[0-9]*; do
  [ -r "$proc/cmdline" ] || continue

  cmd="$(
    tr '\000' ' ' < "$proc/cmdline" 2>/dev/null ||
      true
  )"

  case "$cmd" in
    *"$PACKAGE_DIR/usb0-route-monitor.sh"*|\
    *"udhcpc -i usb0 "*"$PACKAGE_DIR/usb0-udhcpc-script.sh"*)
      echo "Runtime process remains pid=${proc#/proc/}: $cmd" >&2
      runtime_process_count=$((runtime_process_count + 1))
      ;;
  esac
done

if [ "$runtime_process_count" -ne 0 ]; then
  echo "Uninstall stopped because runtime processes remain" >&2
  exit 1
fi

echo "Removing $PACKAGE_DIR"
cd /
rm -rf "$PACKAGE_DIR"

if [ -e "$PACKAGE_DIR" ]; then
  echo "Failed to remove $PACKAGE_DIR" >&2
  exit 1
fi

echo "Uninstall complete"
