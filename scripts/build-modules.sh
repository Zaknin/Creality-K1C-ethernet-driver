#!/bin/sh
set -eu

ROOT="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/scripts/lib.sh"

ENV_FILE=

usage() {
  cat <<'EOF'
Build mii.ko, usbnet.ko, and cdc_ncm.ko from the released source directory.

Usage:
  scripts/build-modules.sh --env ../k1c-build.env

Required:
  --env FILE    Build config containing ARCH, KERNEL_RELEASE, KERNEL_DIR,
                CROSS_COMPILE, and optional SOURCE_DIR/OUTPUT_DIR.

Outputs:
  output/modules/mii.ko
  output/modules/usbnet.ko
  output/modules/cdc_ncm.ko
  output/logs/build-modules.log

Safety:
  Builds a scratch copy of source/ and copies only the three expected modules
  to OUTPUT_DIR. The vendor kernel tree must already be prepared.
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
"$ROOT/scripts/check-environment.sh" --env "$ENV_FILE"
load_env_file "$ENV_FILE"

SOURCE_DIR="${SOURCE_DIR:-$ROOT/source}"
OUTPUT_DIR="${OUTPUT_DIR:-output/modules}"
BUILD_LOG_DIR="${BUILD_LOG_DIR:-output/logs}"
BUILD_WORK_DIR="${BUILD_WORK_DIR:-output/build-work/source}"
mkdir -p "$OUTPUT_DIR" "$BUILD_LOG_DIR"
rm -rf "$BUILD_WORK_DIR"
mkdir -p "$BUILD_WORK_DIR"

cp "$SOURCE_DIR/mii.c" "$BUILD_WORK_DIR/"
cp "$SOURCE_DIR/usbnet.c" "$BUILD_WORK_DIR/"
cp "$SOURCE_DIR/cdc_ncm.c" "$BUILD_WORK_DIR/"
cp "$SOURCE_DIR/Makefile" "$BUILD_WORK_DIR/"

log="$BUILD_LOG_DIR/build-modules.log"
note "building released source against prepared kernel tree"
make -C "$KERNEL_DIR" M="$BUILD_WORK_DIR" ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" modules >"$log" 2>&1

for module in $(expected_modules); do
  [ -f "$BUILD_WORK_DIR/$module" ] || die "expected built module missing: $module"
  cp "$BUILD_WORK_DIR/$module" "$OUTPUT_DIR/$module"
done

{
  printf 'version=%s\n' "1.0.1"
  printf 'kernel_release=%s\n' "$KERNEL_RELEASE"
  printf 'arch=%s\n' "$ARCH"
  printf 'source_dir=%s\n' "$SOURCE_DIR"
  printf 'modules=%s\n' "mii.ko usbnet.ko cdc_ncm.ko"
  date -u '+built_utc=%Y-%m-%dT%H:%M:%SZ'
} >"$OUTPUT_DIR/build-metadata.txt"

sha256sum "$OUTPUT_DIR"/mii.ko "$OUTPUT_DIR"/usbnet.ko "$OUTPUT_DIR"/cdc_ncm.ko >"$OUTPUT_DIR/SHA256SUMS"
note "modules copied to $OUTPUT_DIR"
