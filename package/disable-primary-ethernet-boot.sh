#!/bin/sh
set -u

INIT="${BOOT_HOOK:-/etc/init.d/S46usb_ethernet_primary}"
PACKAGE_DIR="${PACKAGE_DIR:-$(CDPATH= cd "$(dirname "$0")" && pwd)}"
failed=0

# Ownership is proved by exact symlink target (v1.0.6), or by matching the
# shipped full-file hook (v1.0.5 copy mode). Broken foreign symlinks are not safe.
if [ -L "$INIT" ]; then
  owned_target="$(readlink "$INIT" 2>/dev/null || true)"
  if [ "$owned_target" = "$PACKAGE_DIR/S46usb_ethernet_primary" ]; then
    rm -f "$INIT" || failed=1
  else
    echo "refusing to remove unrelated boot symlink: $INIT" >&2
    exit 1
  fi
elif [ -e "$INIT" ]; then
  if [ -f "$INIT" ] && [ -f "$PACKAGE_DIR/S46usb_ethernet_primary" ] &&
      cmp -s "$INIT" "$PACKAGE_DIR/S46usb_ethernet_primary"; then
    rm -f "$INIT" || failed=1
  else
    echo "refusing to remove unrelated/modified boot hook: $INIT" >&2
    exit 1
  fi
fi

if [ -e "$INIT" ] || [ -L "$INIT" ]; then
  echo "failed to remove owned boot hook $INIT" >&2
  failed=1
else
  echo "boot hook absent: $INIT"
fi

"$PACKAGE_DIR/stop-primary-ethernet.sh" ||
  failed=1

if [ -e "$INIT" ] || [ -L "$INIT" ]; then
  echo "boot hook remains: $INIT" >&2
  failed=1
fi

if [ "$failed" -ne 0 ]; then
  echo "failed disabling primary Ethernet boot" >&2
  exit 1
fi

echo "disabled $INIT"
