#!/bin/sh
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
grep 'KEEP_WIFI_FALLBACK=1' "$ROOT/config/runtime.conf.example" >/dev/null
grep 'preserving Wi-Fi default route' "$ROOT/runtime/common.sh" >/dev/null
grep 'S46usb_ethernet_primary.disabled' "$ROOT/runtime/disable-boot.sh" >/dev/null
grep 'usb_ethernet_primary.disabled' "$ROOT/config/runtime.conf.example" >/dev/null
echo "runtime route and boot naming=pass"

