#!/bin/sh
set -eu

ROOT="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/scripts/lib.sh"

ENV_FILE=

usage() {
  cat <<'EOF'
Check the build machine, kernel tree, and compiler.

Usage:
  scripts/check-environment.sh --env ../k1c-build.env

Required:
  --env FILE    Build config containing ARCH, KERNEL_RELEASE, KERNEL_DIR,
                CROSS_COMPILE, and optional SOURCE_DIR/OUTPUT_DIR.

Checks:
  - required POSIX tools
  - ARCH=mips
  - KERNEL_RELEASE=4.4.94
  - CROSS_COMPILE points to a MIPS gcc
  - KERNEL_DIR has prepared-kernel markers
  - Module.symvers is present, or CONFIG_MODVERSIONS is disabled
  - SOURCE_DIR has the three released source files

Safety:
  This script does not download, prepare, or modify a vendor kernel tree.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --env)
      ENV_FILE=${2:-}
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

[ -n "$ENV_FILE" ] || die "missing --env"
load_env_file "$ENV_FILE"

for cmd in sh make find sed awk grep sort sha256sum file cp rm mkdir; do
  need_cmd "$cmd"
done

[ "${ARCH:-}" = "mips" ] || die "ARCH must be mips"
[ "${KERNEL_RELEASE:-}" = "4.4.94" ] || die "KERNEL_RELEASE must be 4.4.94"
[ -n "${KERNEL_DIR:-}" ] || die "KERNEL_DIR is required"
[ -d "$KERNEL_DIR" ] || die "KERNEL_DIR does not exist: $KERNEL_DIR"
[ -n "${CROSS_COMPILE:-}" ] || die "CROSS_COMPILE is required"

cc="${CROSS_COMPILE}gcc"
if ! command -v "$cc" >/dev/null 2>&1; then
  [ -x "$cc" ] || die "cross compiler not executable or not on PATH: $cc"
fi

case "$($cc -dumpmachine 2>/dev/null || true)" in
  *mips*) : ;;
  *) die "cross compiler target is not visibly MIPS" ;;
esac

[ -f "$KERNEL_DIR/Makefile" ] || die "kernel Makefile missing"
[ -f "$KERNEL_DIR/include/generated/utsrelease.h" ] || die "prepared kernel marker missing: include/generated/utsrelease.h"
[ -f "$KERNEL_DIR/include/generated/autoconf.h" ] || die "prepared kernel marker missing: include/generated/autoconf.h"

if ! grep "4.4.94" "$KERNEL_DIR/include/generated/utsrelease.h" >/dev/null 2>&1; then
  die "prepared kernel release does not contain 4.4.94"
fi

modversions=unknown
if [ -f "$KERNEL_DIR/.config" ]; then
  if grep '^CONFIG_MODVERSIONS=y' "$KERNEL_DIR/.config" >/dev/null 2>&1; then
    modversions=yes
  elif grep '^# CONFIG_MODVERSIONS is not set' "$KERNEL_DIR/.config" >/dev/null 2>&1; then
    modversions=no
  fi
elif [ -f "$KERNEL_DIR/include/config/auto.conf" ]; then
  if grep '^CONFIG_MODVERSIONS=y' "$KERNEL_DIR/include/config/auto.conf" >/dev/null 2>&1; then
    modversions=yes
  elif ! grep '^CONFIG_MODVERSIONS=' "$KERNEL_DIR/include/config/auto.conf" >/dev/null 2>&1; then
    modversions=no
  fi
fi

if [ -f "$KERNEL_DIR/Module.symvers" ]; then
  note "kernel Module.symvers present"
elif [ "$modversions" = no ]; then
  note "kernel Module.symvers missing; CONFIG_MODVERSIONS is disabled, so the external module build will generate a module-local Module.symvers"
else
  die "Module.symvers missing and CONFIG_MODVERSIONS is not proven disabled; prepare the user-supplied tree first"
fi

SOURCE_DIR="${SOURCE_DIR:-$ROOT/source}"
[ -f "$SOURCE_DIR/mii.c" ] || die "source missing: $SOURCE_DIR/mii.c"
[ -f "$SOURCE_DIR/usbnet.c" ] || die "source missing: $SOURCE_DIR/usbnet.c"
[ -f "$SOURCE_DIR/cdc_ncm.c" ] || die "source missing: $SOURCE_DIR/cdc_ncm.c"
[ -f "$SOURCE_DIR/Makefile" ] || die "source Makefile missing: $SOURCE_DIR/Makefile"

note "environment ok"
