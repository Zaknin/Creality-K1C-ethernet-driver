#!/bin/sh
set -u

PACKAGE_DIR="${PACKAGE_DIR:-$(CDPATH= cd "$(dirname "$0")" && pwd)}"
MARKER="$PACKAGE_DIR/.package-owned"

case "${1:-}" in
  --yes) ;;
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

"$PACKAGE_DIR/stop-usb-ethernet.sh"
echo "Removing $PACKAGE_DIR"
cd /
rm -rf "$PACKAGE_DIR"
