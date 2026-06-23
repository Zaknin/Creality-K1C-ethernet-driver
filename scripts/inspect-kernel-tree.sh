#!/bin/sh
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
. "$ROOT/scripts/lib.sh"

KERNEL_DIR=
while [ "$#" -gt 0 ]; do
  case "$1" in
    --kernel-dir) KERNEL_DIR=${2:-}; shift 2 ;;
    -h|--help) echo "usage: $0 --kernel-dir /path/to/vendor/kernel"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[ -n "$KERNEL_DIR" ] || die "missing --kernel-dir"
[ -d "$KERNEL_DIR" ] || die "kernel dir not found: $KERNEL_DIR"

score=0
bad=0
[ -f "$KERNEL_DIR/Makefile" ] && score=$((score + 1)) || bad=$((bad + 1))
[ -f "$KERNEL_DIR/drivers/net/mii.c" ] && score=$((score + 1)) || bad=$((bad + 1))
[ -f "$KERNEL_DIR/drivers/net/usb/usbnet.c" ] && score=$((score + 1)) || bad=$((bad + 1))
[ -f "$KERNEL_DIR/drivers/net/usb/cdc_ncm.c" ] && score=$((score + 1)) || bad=$((bad + 1))
[ -f "$KERNEL_DIR/include/generated/utsrelease.h" ] && grep "4.4.94" "$KERNEL_DIR/include/generated/utsrelease.h" >/dev/null 2>&1 && score=$((score + 1)) || bad=$((bad + 1))

if [ "$bad" -ge 3 ]; then
  verdict=INCOMPATIBLE
elif [ "$score" -ge 5 ]; then
  verdict=LIKELY
else
  verdict=UNCONFIRMED
fi

cat <<EOF
compatibility=$verdict
matched_markers=$score
missing_or_unconfirmed_markers=$bad
note=heuristic only; this does not prove exact vendor source identity
EOF

case "$verdict" in
  INCOMPATIBLE) exit 2 ;;
  *) exit 0 ;;
esac

