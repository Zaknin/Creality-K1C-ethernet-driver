#!/bin/sh
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
. "$ROOT/scripts/lib.sh"

ENV_FILE=
usage() {
  cat <<'EOF'
Build mii.ko, usbnet.ko, and cdc_ncm.ko.

Usage:
  scripts/build-modules.sh --env ../k1c-build.env

Required:
  --env FILE    Build config copied from config/build.env.example.

Outputs:
  output/modules/mii.ko
  output/modules/usbnet.ko
  output/modules/cdc_ncm.ko
  output/logs/build-modules.log

Safety:
  Builds only the three expected modules and copies them to output/modules/.
EOF
}
while [ "$#" -gt 0 ]; do
  case "$1" in
    --env) ENV_FILE=${2:-}; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[ -n "$ENV_FILE" ] || die "missing --env"
"$ROOT/scripts/check-environment.sh" --env "$ENV_FILE"
load_env_file "$ENV_FILE"

OUTPUT_DIR=${OUTPUT_DIR:-output/modules}
BUILD_LOG_DIR=${BUILD_LOG_DIR:-output/logs}
mkdir -p "$OUTPUT_DIR" "$BUILD_LOG_DIR"

set -- drivers/net/mii.ko drivers/net/usb/usbnet.ko drivers/net/usb/cdc_ncm.ko
log="$BUILD_LOG_DIR/build-modules.log"
note "building selected modules only"
make -C "$KERNEL_DIR" ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" "$@" >"$log" 2>&1

for src in "$@"; do
  name=$(basename "$src")
  [ -f "$KERNEL_DIR/$src" ] || die "expected built module missing: $src"
  cp "$KERNEL_DIR/$src" "$OUTPUT_DIR/$name"
done

{
  printf 'version=%s\n' "$(cat "$ROOT/VERSION")"
  printf 'kernel_release=%s\n' "$KERNEL_RELEASE"
  printf 'arch=%s\n' "$ARCH"
  printf 'modules=%s\n' "mii.ko usbnet.ko cdc_ncm.ko"
  date -u '+built_utc=%Y-%m-%dT%H:%M:%SZ'
} >"$OUTPUT_DIR/build-metadata.txt"

sha256sum "$OUTPUT_DIR"/mii.ko "$OUTPUT_DIR"/usbnet.ko "$OUTPUT_DIR"/cdc_ncm.ko >"$OUTPUT_DIR/SHA256SUMS"
note "modules copied to $OUTPUT_DIR"
