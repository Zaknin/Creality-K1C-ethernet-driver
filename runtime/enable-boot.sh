#!/bin/sh
set -eu
DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck disable=SC1091
. "$DIR/common.sh"

rm -f /etc/init.d/S46usb_ethernet_primary.disabled
cp "$DIR/start-primary-ethernet.sh" "$BOOT_HOOK"
chmod 0755 "$BOOT_HOOK"
log "boot enabled at $BOOT_HOOK"

