#!/bin/sh
set -u

INIT="${BOOT_HOOK:-/etc/init.d/S46usb_ethernet_primary}"
PACKAGE_DIR="${PACKAGE_DIR:-$(CDPATH= cd "$(dirname "$0")" && pwd)}"
failed=0

rm -f "$INIT" || failed=1

if [ -e "$INIT" ]; then
  echo "failed to remove $INIT" >&2
  failed=1
else
  echo "removed $INIT"
fi

"$PACKAGE_DIR/stop-primary-ethernet.sh" ||
  failed=1

if [ -e "$INIT" ]; then
  echo "boot hook remains: $INIT" >&2
  failed=1
fi

if [ "$failed" -ne 0 ]; then
  echo "failed disabling primary Ethernet boot" >&2
  exit 1
fi

echo "disabled $INIT"
