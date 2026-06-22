#!/bin/sh
set -u

INIT=/etc/init.d/S46usb_ethernet_primary
PACKAGE_DIR="${PACKAGE_DIR:-$(CDPATH= cd "$(dirname "$0")" && pwd)}"

"$PACKAGE_DIR/stop-primary-ethernet.sh" || true
rm -f "$INIT"
echo "disabled $INIT"
