#!/bin/sh
set -eu
DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck disable=SC1091
. "$DIR/common.sh"

rm -f "$BOOT_HOOK" /etc/init.d/S46usb_ethernet_primary.disabled
cp "$DIR/start-primary-ethernet.sh" "$DISABLED_BOOT_HOOK"
chmod 0755 "$DISABLED_BOOT_HOOK"
log "boot disabled at $DISABLED_BOOT_HOOK"

