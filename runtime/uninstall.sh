#!/bin/sh
set -eu
DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck disable=SC1091
. "$DIR/common.sh"

"$DIR/stop-primary-ethernet.sh" >/dev/null 2>&1 || true
rm -f "$BOOT_HOOK" "$DISABLED_BOOT_HOOK" /etc/init.d/S46usb_ethernet_primary.disabled
rm -rf "$INSTALL_DIR"
echo "uninstalled USB Ethernet runtime"

