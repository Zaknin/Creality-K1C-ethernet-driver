#!/bin/sh
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
. "$ROOT/scripts/lib.sh"

MODULES_DIR=output/modules
KERNEL_RELEASE=4.4.94
REPORT_DIR=output/verify
while [ "$#" -gt 0 ]; do
  case "$1" in
    --modules-dir) MODULES_DIR=${2:-}; shift 2 ;;
    --kernel-release) KERNEL_RELEASE=${2:-}; shift 2 ;;
    --report-dir) REPORT_DIR=${2:-}; shift 2 ;;
    -h|--help) echo "usage: $0 --modules-dir output/modules --kernel-release 4.4.94"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[ -d "$MODULES_DIR" ] || die "modules dir not found: $MODULES_DIR"
mkdir -p "$REPORT_DIR"

for module in $(expected_modules); do
  [ -f "$MODULES_DIR/$module" ] || die "missing expected module: $module"
done

extras=$(find "$MODULES_DIR" -maxdepth 1 -type f -name '*.ko' ! -name mii.ko ! -name usbnet.ko ! -name cdc_ncm.ko -print)
[ -z "$extras" ] || die "unexpected module(s): $extras"

for module in $(expected_modules); do
  file "$MODULES_DIR/$module" | tee "$REPORT_DIR/$module.file.txt" >/dev/null
  if ! file "$MODULES_DIR/$module" | grep -Ei 'ELF|relocatable|kernel module' >/dev/null; then
    die "$module does not look like an ELF/kernel module"
  fi
  if command -v modinfo >/dev/null 2>&1; then
    modinfo "$MODULES_DIR/$module" >"$REPORT_DIR/$module.modinfo.txt" || die "modinfo failed for $module"
    if grep '^vermagic:' "$REPORT_DIR/$module.modinfo.txt" >/dev/null 2>&1; then
      grep '^vermagic:' "$REPORT_DIR/$module.modinfo.txt" | grep "$KERNEL_RELEASE" >/dev/null 2>&1 || die "$module vermagic does not include $KERNEL_RELEASE"
    fi
  fi
  if command -v readelf >/dev/null 2>&1; then
    readelf -h "$MODULES_DIR/$module" >"$REPORT_DIR/$module.readelf.txt" || die "readelf failed for $module"
  fi
done

sha256sum "$MODULES_DIR"/mii.ko "$MODULES_DIR"/usbnet.ko "$MODULES_DIR"/cdc_ncm.ko >"$REPORT_DIR/SHA256SUMS"
printf '%s\n' mii usbnet cdc_ncm >"$REPORT_DIR/dependency-order.txt"
reject_private_text "$REPORT_DIR"
note "module verification ok"

