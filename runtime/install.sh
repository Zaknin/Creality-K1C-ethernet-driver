#!/bin/sh
set -eu
DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck disable=SC1091
. "$DIR/common.sh"

mkdir -p "$INSTALL_DIR/runtime" "$INSTALL_DIR/modules"
cp "$DIR"/*.sh "$INSTALL_DIR/runtime/"
[ -f "$DIR/config.conf" ] && cp "$DIR/config.conf" "$INSTALL_DIR/runtime/config.conf"
chmod 0755 "$INSTALL_DIR/runtime"/*.sh
rm -f "$BOOT_HOOK" /etc/init.d/S46usb_ethernet_primary.disabled
cp "$INSTALL_DIR/runtime/start-primary-ethernet.sh" "$DISABLED_BOOT_HOOK"
chmod 0755 "$DISABLED_BOOT_HOOK"
log "installed runtime with boot disabled: $DISABLED_BOOT_HOOK"

